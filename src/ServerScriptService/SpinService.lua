local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PlayerDataStore = require(script.Parent:WaitForChild("PlayerDataStore"))
local NumberGenerator = require(script.Parent:WaitForChild("NumberGenerator"))
local NumberEconomy = require(script.Parent:WaitForChild("NumberEconomy"))
local NumberRegistry = require(script.Parent:WaitForChild("NumberRegistry"))
local SpinService = {}
local Upgrades = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local MAX_CANDIDATES = 8
local random = Random.new()

local function copyTable(source)
	local result = {}
	for key, value in pairs(source) do
		if type(value) == "table" then result[key] = copyTable(value) else result[key] = value end
	end
	return result
end

local function sessionAvailable(session)
	return not session.Closed and not session.Closing and os.time() < session.LeaseUntil - 10
end

local function syncBalance(session)
	if session.BalanceValue then session.BalanceValue.Value = session.Data.Balance end
end

local function persist(session)
	local deadline = os.clock() + 10
	while session.Busy and os.clock() < deadline do
		if not sessionAvailable(session) then return false, "Сессия закрывается" end
		task.wait(0.1)
	end
	if not sessionAvailable(session) then return false, "Сессия недоступна" end
	if session.Busy then return false, "Предыдущее сохранение не завершилось" end
	return PlayerDataStore.Save(session, false)
end

local function makeDraft(code, rarityIndex, context)
	local offer = context or Config.CodeOffers[code]
	if not offer then return nil, "Предложение недоступно" end
	local digits, generationError = NumberGenerator.GenerateDigits(rarityIndex)
	if not digits then return nil, generationError end
	local draft = NumberEconomy.Evaluate(digits, code, offer.ProfileId)
	draft.Code = code
	draft.Digits = digits
	draft.ProfileId = offer.ProfileId
	draft.OperatorId = offer.OperatorId
	draft.OperatorName = offer.OperatorName
	draft.Region = offer.Region
	if context then
		draft.RegionId = context.RegionId
		draft.OfferPrice = context.OfferPrice
		draft.EconomyVersion = 3
	end
	return draft
end

local function refundPending(session, reason)
	if not sessionAvailable(session) then return nil, "RecoveryRequired", "Сессия закрывается" end
	local data = session.Data
	local pending = data.PendingSpin
	data.Balance += pending.Price
	local receipt = {Status = "Cancelled", Sequence = pending.Sequence, Balance = data.Balance, Reason = reason}
	data.PendingSpin = nil
	data.LastSpin = copyTable(receipt)
	syncBalance(session)
	local saved, saveError = persist(session)
	if not saved then return nil, "RecoveryRequired", saveError end
	return receipt
end

local function finishPending(session)
	local data = session.Data
	local pending = data.PendingSpin
	if not pending then return {Status = "Ready", Balance = data.Balance} end
	if type(pending) ~= "table" or type(pending.Draft) ~= "table"
		or type(pending.OperationId) ~= "string" or type(pending.Sequence) ~= "number"
		or type(pending.Price) ~= "number" or type(pending.Attempt) ~= "number"
		or type(pending.NotBeforeMillis) ~= "number"
	then
		return nil, "RecoveryRequired", "Некорректная запись выдачи"
	end
	while DateTime.now().UnixTimestampMillis < pending.NotBeforeMillis do
		if not sessionAvailable(session) then return nil, "RecoveryRequired", "Сессия закрывается" end
		task.wait(0.1)
	end
	while sessionAvailable(session) do
		local draft = pending.Draft
		local reservation, reserveError, reserveDetails = NumberRegistry.Reserve(draft.FullNumber, session.UserId, pending.OperationId)
		if not reservation then
			if reserveError ~= "Occupied" then return nil, "RecoveryRequired", reserveDetails or reserveError end
			if pending.Attempt >= MAX_CANDIDATES then
				return refundPending(session, "Не найден свободный номер выбранной категории")
			end
			local context = draft.EconomyVersion == 3 and {
				ProfileId = "Regional", OperatorId = draft.OperatorId, OperatorName = draft.OperatorName,
				Region = draft.Region, RegionId = draft.RegionId, OfferPrice = pending.Price,
			} or nil
			local nextDraft, draftError = makeDraft(draft.Code, draft.RarityIndex, context)
			if not nextDraft then return refundPending(session, draftError) end
			if not sessionAvailable(session) then return nil, "RecoveryRequired", "Сессия закрывается" end
			pending.Attempt += 1
			pending.Draft = nextDraft
			local saved, saveError = persist(session)
			if not saved then return nil, "RecoveryRequired", saveError end
			continue
		end
		local owned, confirmError, confirmDetails = NumberRegistry.Confirm(draft.FullNumber, session.UserId, pending.OperationId)
		if not owned then return nil, "RecoveryRequired", confirmDetails or confirmError end
		if not sessionAvailable(session) then return nil, "RecoveryRequired", "Сессия закрывается" end
		local item = copyTable(draft)
		item.IssuanceId = owned.IssuanceId
		item.Generation = owned.Generation
		item.OperationId = pending.OperationId
		item.OriginalOwnerId = session.UserId
		item.CanBoostSale = true
		item.Location = "Inventory"
		item.AcquiredAt = os.time()
		local existing = data.Inventory[item.IssuanceId]
		if existing and existing.OperationId ~= pending.OperationId then return nil, "RecoveryRequired", "Конфликт записи предмета" end
		data.Inventory[item.IssuanceId] = existing or item
		local receipt = {Status = "Success", Sequence = pending.Sequence, Balance = data.Balance, Item = copyTable(data.Inventory[item.IssuanceId])}
		data.LastSpin = copyTable(receipt)
		data.PendingSpin = nil
		local saved, saveError = persist(session)
		if not saved then return nil, "RecoveryRequired", saveError end
		syncBalance(session)
		return receipt
	end
	return nil, "RecoveryRequired", "Сессия недоступна"
end

local function runExclusive(session, callback)
	if session.SpinBusy then return nil, "Busy" end
	if session.NeedsRecovery then return nil, "RecoveryRequired" end
	if not sessionAvailable(session) then return nil, "SessionUnavailable" end
	session.SpinBusy = true
	local success, result, errorCode, details = pcall(callback)
	session.SpinBusy = false
	if not success then session.NeedsRecovery = true; return nil, "RecoveryRequired", tostring(result) end
	if errorCode == "RecoveryRequired" then session.NeedsRecovery = true end
	return result, errorCode, details
end

function SpinService.Recover(session)
	return runExclusive(session, function() return finishPending(session) end)
end

function SpinService.Start(session, operatorId, regionId, sequence)
	if session.ProgressBusy or session.Data.PendingSale then return nil, "Busy" end
	return runExclusive(session, function()
		local data = session.Data
		if type(operatorId) ~= "string" or type(regionId) ~= "string" then return nil, "InvalidRegion" end
		local offer = Config.ResolveRegion(operatorId, regionId)
		if not offer then return nil, "InvalidRegion" end
		if type(sequence) ~= "number" or sequence % 1 ~= 0 or sequence < 1 or sequence > 1000000000 then return nil, "InvalidSequence" end
		if data.LastSpin and data.LastSpin.Sequence == sequence then return copyTable(data.LastSpin) end
		if data.PendingSpin then
			if data.PendingSpin.Sequence == sequence then return finishPending(session) end
			return nil, "Busy"
		end
		local nextSequence = data.NextSpinSequence or 1
		if sequence ~= nextSequence then return nil, "StaleRequest" end
		if data.Balance < offer.Price then return nil, "NotEnoughMoney" end
		local count = 0
		for _ in pairs(data.Inventory) do count += 1 end
		if count >= data.InventoryCapacity then return nil, "InventoryFull" end
		local startedAt = DateTime.now().UnixTimestampMillis
		local weights = Upgrades.Weights(Config.Profiles.Regional.Weights, Upgrades.Level(data, "Luck"))
		local rarityIndex = NumberGenerator.RollRarity("Regional", weights)
		local code = offer.Codes[random:NextInteger(1, #offer.Codes)]
		local draft, draftError = makeDraft(code, rarityIndex, {ProfileId = "Regional", OperatorId = offer.OperatorId,
			OperatorName = offer.OperatorName, Region = offer.Region, RegionId = offer.Id, OfferPrice = offer.Price})
		if not draft then return nil, "GenerationFailed", draftError end
		if not sessionAvailable(session) then return nil, "SessionUnavailable" end
		local pending = {
			OperationId = HttpService:GenerateGUID(false), Sequence = sequence,
			Price = offer.Price, Attempt = 1, Draft = draft,
			NotBeforeMillis = startedAt + math.ceil(Upgrades.Duration(Config.SpinDuration, Upgrades.Level(data, "Speed")) * 1000),
		}
		data.PendingSpin = pending
		data.NextSpinSequence = sequence + 1
		data.Balance -= offer.Price
		syncBalance(session)
		local saved, saveError = persist(session)
		if not saved then return nil, "RecoveryRequired", saveError end
		return finishPending(session)
	end)
end

return SpinService
