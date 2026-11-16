-- Credit/removal commit precedes registry release. PendingSale survives unknown writes.
local Store = require(script.Parent:WaitForChild("PlayerDataStore"))
local Registry = require(script.Parent:WaitForChild("NumberRegistry"))
local Service = {}
local function finish(session)
	local data, pending = session.Data, session.Data.PendingSale
	if not pending then return {Status = "Ready"} end
	if type(pending) ~= "table" or type(pending.IssuanceId) ~= "string" or type(pending.FullNumber) ~= "string"
		or type(pending.Generation) ~= "number" or type(pending.Amount) ~= "number"
		or data.Inventory[pending.IssuanceId] ~= nil then return nil, "RecoveryRequired" end
	local released = Registry.ReleaseOwned(pending.FullNumber, session.UserId, pending.IssuanceId, pending.Generation)
	if not released then return nil, "RecoveryRequired" end
	local receipt = {Status = "Success", IssuanceId = pending.IssuanceId, Amount = pending.Amount}
	data.LastSale = receipt
	data.PendingSale = nil
	if not Store.Save(session, false) then return nil, "RecoveryRequired" end
	return receipt
end
local function run(session, callback, recovering)
	if session.Closed or session.Closing or session.LeaseUntil <= os.time() + 10 then return nil, "SessionUnavailable" end
	if session.NeedsRecovery then return nil, "RecoveryRequired" end
	if session.ProgressBusy or session.SpinBusy or session.SlotBusy or session.RequestBusy or session.Busy or session.Data.PendingSpin then return nil, "Busy" end
	if session.Data.PendingSale and not recovering then return nil, "RecoveryRequired" end
	session.ProgressBusy = true
	local ok, result, code = pcall(callback)
	session.ProgressBusy = false
	if not ok or code == "RecoveryRequired" then session.NeedsRecovery = true; return nil, "RecoveryRequired" end
	return result, code
end
function Service.Recover(session)
	return run(session, function() return finish(session) end, true)
end
function Service.Sell(session, issuanceId)
	return run(session, function()
		if type(issuanceId) ~= "string" or #issuanceId > 80 then return nil, "InvalidItem" end
		local data = session.Data
		if data.LastSale and data.LastSale.IssuanceId == issuanceId then return table.clone(data.LastSale) end
		local item = data.Inventory[issuanceId]
		if not item then return nil, "ItemNotOwned" end
		if item.Location ~= "Inventory" or item.IncomeSlotIndex ~= nil then return nil, "ItemInstalled" end
		local amount = item.SalePrice
		if type(amount) ~= "number" or amount % 1 ~= 0 or amount < 0 or amount > 1000000000
			or type(item.Generation) ~= "number" or item.Generation % 1 ~= 0 or item.Generation < 1 then return nil, "RecoveryRequired" end
		if data.Balance + amount > 1000000000000 then return nil, "BalanceLimit" end
		data.PendingSale = {IssuanceId = issuanceId, FullNumber = item.FullNumber, Generation = item.Generation, Amount = amount}
		data.Inventory[issuanceId] = nil
		data.Balance += amount
		if session.BalanceValue then session.BalanceValue.Value = data.Balance end
		if not Store.Save(session, false) then return nil, "RecoveryRequired" end
		return finish(session)
	end, false)
end
return Service
