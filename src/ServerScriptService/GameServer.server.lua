local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PlayerDataStore = require(script.Parent:WaitForChild("PlayerDataStore"))
local SpinService = require(script.Parent:WaitForChild("SpinService"))
local IncomeSlotService = require(script.Parent:WaitForChild("IncomeSlotService"))
local OnlineIncomeService = require(script.Parent:WaitForChild("OnlineIncomeService"))
local remotes = ReplicatedStorage:WaitForChild("NumberRushRemotes")
local spinRequest = remotes:WaitForChild("SpinRequest")
local spinResult = remotes:WaitForChild("SpinResult")
local slotRequest = remotes:WaitForChild("SlotRequest")
local slotResult = remotes:WaitForChild("SlotResult")
local UpgradeRules = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local UpgradeService = require(script.Parent:WaitForChild("UpgradeService"))
local SaleService = require(script.Parent:WaitForChild("SaleService"))
local NumberEconomy = require(script.Parent:WaitForChild("NumberEconomy"))
local function remote(name)
	local value = remotes:FindFirstChild(name)
	if not value then value = Instance.new("RemoteEvent"); value.Name = name; value.Parent = remotes end
	return value
end
local progressRequest, progressResult = remote("ProgressRequest"), remote("ProgressResult")
local function publishProgress(player, session)
	player:SetAttribute("InventoryCapacity", session.Data.InventoryCapacity)
	player:SetAttribute("IncomeSlotCount", session.Data.IncomeSlotCount)
	for key, level in pairs(session.Data.Upgrades) do player:SetAttribute("Upgrade" .. key, level) end
end
local sessions, loading = {}, {}
local shuttingDown = false

local function send(player, packet)
	if player.Parent == Players then spinResult:FireClient(player, packet) end
end

local function publishInventory(player, session)
	local folder = player:FindFirstChild("NumberInventory")
	if not folder then folder = Instance.new("Folder"); folder.Name = "NumberInventory"; folder.Parent = player end
	folder:ClearAllChildren()
	local count = 0
	for issuanceId, item in pairs(session.Data.Inventory) do
		local entry = Instance.new("Folder")
		entry.Name = tostring(issuanceId)
		for key, value in pairs(item) do
			local valueType = type(value)
			if valueType == "string" or valueType == "number" or valueType == "boolean" then entry:SetAttribute(key, value) end
		end
		entry.Parent = folder
		count += 1
	end
	player:SetAttribute("InventoryCount", count)
	player:SetAttribute("NextSpinSequence", session.Data.NextSpinSequence or 1)
end

local function publishSlots(player, state)
	local folder = player:FindFirstChild("IncomeSlots")
	if not folder then folder = Instance.new("Folder"); folder.Name = "IncomeSlots"; folder.Parent = player end
	folder:ClearAllChildren()
	folder:SetAttribute("Revision", state.Revision)
	folder:SetAttribute("ServerTime", state.ServerTime)
	for _, row in ipairs(state.Slots) do
		local entry = Instance.new("Folder")
		entry.Name = tostring(row.SlotIndex)
		for key, value in pairs(row) do
			local kind = type(value)
			if kind == "string" or kind == "number" or kind == "boolean" then entry:SetAttribute(key, value) end
		end
		entry.Parent = folder
	end
	player:SetAttribute("SlotRevision", state.Revision)
	player:SetAttribute("ActiveIncomeSlotCount", state.ActiveCount)
	player:SetAttribute("TotalBaseIncomePerHour", state.TotalBaseIncomePerHour)
	player:SetAttribute("IncomeEnabled", state.IncomeEnabled == true)
end

local function closeProfile(player)
	local session = sessions[player]
	if not session or session.Closing then return end
	OnlineIncomeService.Stop(session)
	session.Closing = true
	player:SetAttribute("DataReady", false)
	if session.BalanceConnection then session.BalanceConnection:Disconnect() end
	local deadline = os.clock() + 20
	while (session.Busy or session.SpinBusy or session.RequestBusy or session.SlotBusy or session.ProgressBusy) and os.clock() < deadline do task.wait(0.1) end
	local saved, saveError = false, "Не удалось завершить сохранение"
	for attempt = 1, 3 do
		if os.clock() >= deadline then break end
		if not session.Busy and not session.SpinBusy and not session.RequestBusy and not session.SlotBusy and not session.ProgressBusy then
			saved, saveError = PlayerDataStore.Save(session, true)
			if saved then break end
		end
		task.wait(1)
	end
	if saved then
		print("NUMBER RUSH: профиль сохранён — " .. player.Name)
	else
		warn("NUMBER RUSH: ошибка сохранения — " .. player.Name .. ": " .. tostring(saveError))
	end
	sessions[player] = nil
end

local function stopSession(player, message)
	player:SetAttribute("DataReady", false)
	task.spawn(closeProfile, player)
	if player.Parent == Players then player:Kick(message) end
end

local function setupPlayer(player)
	if sessions[player] or loading[player] or shuttingDown then return end
	loading[player] = true
	player:SetAttribute("DataReady", false)
	local session, loadError = nil, nil
	for attempt = 1, 3 do
		if player.Parent ~= Players or shuttingDown then break end
		session, loadError = PlayerDataStore.Load(player.UserId)
		if session then break end
		if attempt < 3 then task.wait(2) end
	end
	loading[player] = nil
	if not session then
		if player.Parent == Players and not shuttingDown then
			warn("NUMBER RUSH: ошибка загрузки: " .. tostring(loadError))
			player:Kick("Профиль недоступен. Подключитесь немного позже.")
		end
		return
	end
	sessions[player] = session
	session.NextSaveAt = os.clock() + 30
	if player.Parent ~= Players or shuttingDown then closeProfile(player); return end
	if session.Data.NextSpinSequence == nil then session.Data.NextSpinSequence = 1 end
	local recovered, recoveryError, recoveryDetails = SpinService.Recover(session)
	if not recovered then
		warn("NUMBER RUSH: восстановление выдачи: " .. tostring(recoveryDetails or recoveryError))
		stopSession(player, "Не удалось восстановить профиль. Подключитесь немного позже.")
		return
	end
	if player.Parent ~= Players or shuttingDown then closeProfile(player); return end
	local saleRecovered = SaleService.Recover(session)
	local upgradesReady = saleRecovered and UpgradeService.Initialize(session)
	if not saleRecovered or not upgradesReady then
		stopSession(player, "Не удалось восстановить операции профиля. Переподключитесь позже."); return
	end
	local incomeUpdated = pcall(NumberEconomy.RefreshIncome, session.Data)
	if not incomeUpdated then
		stopSession(player, "Не удалось обновить расчёт дохода. Переподключитесь позже."); return
	end
	local slots, slotError, slotDetails = IncomeSlotService.Initialize(session)
	if not slots then
		warn("NUMBER RUSH: проверка слотов: " .. tostring(slotDetails or slotError))
		stopSession(player, "Не удалось проверить доходные слоты. Подключитесь немного позже.")
		return
	end
	if not PlayerDataStore.Save(session, false) then
		stopSession(player, "Не удалось сохранить расчёт дохода. Переподключитесь позже."); return
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local rubles = Instance.new("IntValue")
	rubles.Name = "Рубли"
	rubles.Value = session.Data.Balance
	rubles.Parent = leaderstats
	session.BalanceValue = rubles
	player:SetAttribute("InventoryCapacity", session.Data.InventoryCapacity)
	player:SetAttribute("IncomeSlotCount", session.Data.IncomeSlotCount)
	session.BalanceConnection = rubles:GetPropertyChangedSignal("Value"):Connect(function()
		if session.Closing or session.Closed then return end
		local value = rubles.Value
		if value < 0 or value > 1000000000000 then
			rubles.Value = session.Data.Balance
			warn("NUMBER RUSH: отклонён некорректный баланс")
			return
		end
		session.Data.Balance = value
	end)
	local incomeReady, incomeError = OnlineIncomeService.Initialize(session)
	if not incomeReady then
		warn("NUMBER RUSH: проверка дохода: " .. tostring(incomeError))
		stopSession(player, "Не удалось проверить доход. Подключитесь немного позже.")
		return
	end
	slots.State.IncomeEnabled = true
	publishInventory(player, session)
	publishProgress(player, session)
	publishSlots(player, slots.State)
	leaderstats.Parent = player
	player:SetAttribute("DataReady", true)
	print("NUMBER RUSH: профиль загружен. Баланс: " .. tostring(session.Data.Balance))
	print("NUMBER RUSH: доходных слотов доступно: " .. tostring(slots.State.SlotCount))
end

local messages = {
	InvalidBatch = "Выберите от одного до трёх номеров. Пропуск ×4 ещё не подключён.",
	BatchLocked = "Сначала откройте эту ступень параллельной выдачи в прокачке.",
	InvalidRegion = "Выберите доступного оператора и регион.",
	InvalidCode = "Выберите доступный код.",
	InvalidSequence = "Обновите выбор и повторите попытку.",
	StaleRequest = "Состояние терминала обновилось. Повторите попытку.",
	Busy = "Прокрутка уже выполняется.", SessionUnavailable = "Профиль временно недоступен.",
	NotEnoughMoney = "Недостаточно рублей.", InventoryFull = "В коллекции нет свободных мест.",
	GenerationFailed = "Не удалось подготовить номер. Повторите попытку.",
	RecoveryRequired = "Для проверки выдачи нужно переподключиться.",
}

local function sendError(player, session, sequence, code)
	send(player, {
		Status = "Error", ErrorCode = code, Sequence = sequence,
		Message = messages[code] or "Не удалось выполнить прокрутку.",
		NextSequence = session and (session.Data.NextSpinSequence or 1) or nil,
		Ready = player:GetAttribute("DataReady") == true,
	})
end

spinRequest.OnServerEvent:Connect(function(player, operatorId, regionId, sequence, batchCount)
	local session = sessions[player]
	if not session or player:GetAttribute("DataReady") ~= true then sendError(player, session, nil, "SessionUnavailable"); return end
	local now = os.clock()
	if session.LastRequestAt and now - session.LastRequestAt < 0.25 then return end
	session.LastRequestAt = now
	if session.RequestBusy or session.SpinBusy or session.SlotBusy or session.ProgressBusy then sendError(player, session, nil, "Busy"); return end
	if type(operatorId) ~= "string" or type(regionId) ~= "string" then sendError(player, session, nil, "InvalidRegion"); return end
	local offer = Config.ResolveRegion(operatorId, regionId)
	if not offer then sendError(player, session, nil, "InvalidRegion"); return end
	if type(sequence) ~= "number" or sequence % 1 ~= 0 or sequence < 1 or sequence > 1000000000 then sendError(player, session, nil, "InvalidSequence"); return end
	local lastSpin = session.Data.LastSpin
	local repeated = lastSpin and lastSpin.Sequence == sequence
	batchCount = batchCount or 1
	if type(batchCount) ~= "number" or batchCount % 1 ~= 0 or batchCount < 1 or batchCount > 3 then sendError(player, session, sequence, "InvalidBatch"); return end
	if not repeated then
		if batchCount > 1 + UpgradeRules.Level(session.Data, "Batch") then sendError(player, session, sequence, "BatchLocked"); return end
		if sequence ~= (session.Data.NextSpinSequence or 1) then sendError(player, session, sequence, "StaleRequest"); return end
		if session.Data.Balance < offer.Price * batchCount then sendError(player, session, sequence, "NotEnoughMoney"); return end
		local count = 0
		for _ in pairs(session.Data.Inventory) do count += 1 end
		if count + batchCount > session.Data.InventoryCapacity then sendError(player, session, sequence, "InventoryFull"); return end
	end
	session.RequestBusy = true
	if not repeated then send(player, {Status = "Started", Sequence = sequence, OperatorId = operatorId, RegionId = regionId, Duration = UpgradeRules.Duration(Config.SpinDuration, UpgradeRules.Level(session.Data, "Speed"))}) end
	local receipt, errorCode, details = SpinService.Start(session, operatorId, regionId, sequence, batchCount)
	session.RequestBusy = false
	if not receipt then
		warn("NUMBER RUSH: прокрутка: " .. tostring(errorCode) .. " " .. tostring(details or ""))
		if errorCode == "RecoveryRequired" then
			player:SetAttribute("DataReady", false)
			sendError(player, session, sequence, errorCode)
			stopSession(player, "Профиль временно недоступен. Переподключитесь для проверки выдачи.")
		else
			sendError(player, session, sequence, errorCode)
		end
		return
	end
	if session.Closing or session.Closed or player.Parent ~= Players then return end
	publishInventory(player, session)
	receipt.Balance = session.Data.Balance
	receipt.NextSequence = session.Data.NextSpinSequence or 1
	receipt.InventoryCount = player:GetAttribute("InventoryCount")
	send(player, receipt)
end)

local slotMessages = {
	Busy = "Дождитесь завершения текущего действия.",
	SessionUnavailable = "Профиль временно недоступен.",
	InvalidAction = "Неизвестное действие со слотом.",
	InvalidSlot = "Выберите доступный доходный слот.",
	InvalidRevision = "Обновите состояние слотов.",
	StaleSlots = "Состояние слотов изменилось. Проверьте выбор и повторите действие.",
	InvalidItem = "Выберите номер из своей коллекции.",
	ItemNotOwned = "Этого номера нет в вашей коллекции.",
	AlreadyAssigned = "Этот номер уже установлен в другом слоте.",
	ItemUnavailable = "Номер занят другим действием.",
	LastIncomeSource = "Сначала установите другой номер: последний занятый слот нельзя оставить пустым.",
	RevisionLimit = "Не удалось обновить слоты. Обратитесь к разработчику.",
	RecoveryRequired = "Переподключитесь для проверки сохранённого назначения.",
}

local function sendSlotError(player, session, code, details)
	local message = slotMessages[code] or "Не удалось изменить доходный слот."
	local state = nil
	if session and code == "StaleSlots" then
		local response = IncomeSlotService.GetState(session)
		if response then state = response.State end
	end
	if player.Parent == Players then
		slotResult:FireClient(player, {Status = "Error", ErrorCode = code, Message = message,
			State = state, Ready = player:GetAttribute("DataReady") == true})
	end
end

slotRequest.OnServerEvent:Connect(function(player, action, index, issuanceId, revision)
	local session = sessions[player]
	if not session or player:GetAttribute("DataReady") ~= true then
		sendSlotError(player, session, "SessionUnavailable"); return
	end
	local now = os.clock()
	if session.LastSlotRequestAt and now - session.LastSlotRequestAt < 0.2 then
		if not session.LastSlotThrottleReplyAt or now - session.LastSlotThrottleReplyAt >= 1 then
			session.LastSlotThrottleReplyAt = now
			sendSlotError(player, session, "Busy")
		end
		return
	end
	session.LastSlotRequestAt = now
	if action ~= "GetState" and action ~= "Install" and action ~= "Remove" and action ~= "EquipBest" then
		sendSlotError(player, session, "InvalidAction"); return
	end
	local result, code, details
	if action == "GetState" then
		result, code, details = IncomeSlotService.GetState(session)
	elseif action == "Install" then
		result, code, details = IncomeSlotService.Install(session, index, issuanceId, revision)
	elseif action == "EquipBest" then
		result, code, details = IncomeSlotService.EquipBest(session, revision)
	else
		result, code, details = IncomeSlotService.Remove(session, index, revision)
	end
	if not result then
		if code == "RecoveryRequired" then
			player:SetAttribute("DataReady", false)
			warn("NUMBER RUSH: сохранение слота: " .. tostring(details))
			sendSlotError(player, session, code)
			stopSession(player, "Назначение слота требует проверки. Подключитесь немного позже.")
		else
			sendSlotError(player, session, code, details)
		end
		return
	end
	if session.Closing or session.Closed or player.Parent ~= Players then return end
	if result.Status == "Success" then publishInventory(player, session) end
	publishSlots(player, result.State)
	slotResult:FireClient(player, result)
end)

local progressMessages = {
	UpgradeLocked = "Сначала откройте связанные улучшения, указанные в дереве.",
	StarterReserve = "Сначала получите номер: нужно оставить 5 000 ₽ на первую выдачу.",
	NotEnoughMoney = "Недостаточно рублей.", StaleUpgrade = "Уровень уже изменился. Проверьте следующую ступень.",
	MaxUpgrade = "Достигнут максимальный уровень.", InvalidUpgrade = "Выберите доступное улучшение.",
	Busy = "Дождитесь завершения текущего действия.", ItemNotOwned = "Номера больше нет в коллекции.",
	ItemInstalled = "Сначала снимите номер с доходного слота или замените его.",
	BalanceLimit = "Достигнут предел баланса.", SessionUnavailable = "Профиль ещё не готов.",
}
progressRequest.OnServerEvent:Connect(function(player, action, key, expectedLevel)
	local session = sessions[player]
	if not session or player:GetAttribute("DataReady") ~= true then return end
	if session.LastProgressRequestAt and os.clock() - session.LastProgressRequestAt < 0.3 then
		progressResult:FireClient(player, {Status = "Error", Message = progressMessages.Busy}); return
	end
	session.LastProgressRequestAt = os.clock()
	local result, code
	if action == "Buy" then result, code = UpgradeService.Buy(session, key, expectedLevel)
	elseif action == "Sell" then result, code = SaleService.Sell(session, key)
	else code = "InvalidAction" end
	if not result then
		progressResult:FireClient(player, {Status = "Error", ErrorCode = code, Message = progressMessages[code] or "Операция не выполнена. Переподключитесь для проверки профиля."})
		if code == "RecoveryRequired" then stopSession(player, "Проверяем сохранение операции. Переподключитесь позже.") end
		return
	end
	if session.Closing or session.Closed or player.Parent ~= Players then return end
	publishProgress(player, session); publishInventory(player, session)
	local slots = IncomeSlotService.GetState(session)
	if slots then publishSlots(player, slots.State); slotResult:FireClient(player, slots) end
	result.Action = action
	progressResult:FireClient(player, result)
end)

Players.PlayerRemoving:Connect(closeProfile)
Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do task.spawn(setupPlayer, player) end

task.spawn(function()
	while not shuttingDown do
		task.wait(1)
		for player, session in pairs(sessions) do
			if session.Closing or session.Closed or session.NeedsRecovery or session.Busy
				or session.SpinBusy or session.RequestBusy or session.SlotBusy or session.ProgressBusy then continue end
			local ok, reason = OnlineIncomeService.Accrue(session)
			if not ok then
				session.NeedsRecovery = true
				warn("NUMBER RUSH: начисление дохода: " .. tostring(reason))
				stopSession(player, "Доход требует проверки. Подключитесь немного позже.")
			end
		end
	end
end)

task.spawn(function()
	while not shuttingDown do
		task.wait(5)
		for player, session in pairs(sessions) do
			if session.Closing or session.Closed then continue end
			if os.time() >= session.LeaseUntil - 15 then
				stopSession(player, "Связь с хранилищем потеряна. Подключитесь немного позже.")
				continue
			end
			if session.SpinBusy or session.RequestBusy or session.SlotBusy or session.ProgressBusy then continue end
			if os.clock() >= session.NextSaveAt and not session.Busy then
				session.NextSaveAt = os.clock() + 30
				task.spawn(function()
					if session.Closing or session.Closed or session.SpinBusy or session.RequestBusy or session.SlotBusy or session.ProgressBusy then return end
					local saved, saveError = PlayerDataStore.Save(session, false)
					if not saved then warn("NUMBER RUSH: ошибка автосохранения: " .. tostring(saveError)) end
				end)
			end
		end
	end
end)

game:BindToClose(function()
	shuttingDown = true
	for player in pairs(sessions) do task.spawn(closeProfile, player) end
	local deadline = os.clock() + 25
	while os.clock() < deadline do
		if next(sessions) == nil and next(loading) == nil then break end
		task.wait(0.1)
	end
end)
