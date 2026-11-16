local Rules = require(game:GetService("ReplicatedStorage"):WaitForChild("UpgradeConfig"))
local Store = require(script.Parent:WaitForChild("PlayerDataStore"))
local Service = {}
function Service.Initialize(session)
	local data = session.Data
	if data.UpgradeTreeVersion ~= nil and data.UpgradeTreeVersion ~= 2 then return nil, "RecoveryRequired" end
	if data.Upgrades and data.UpgradeTreeVersion == nil then
		local old = data.Upgrades
		local storageMap = {[0]=0,2,5,7,9}
		if type(old) ~= "table" or type(old.Storage) ~= "number" or not storageMap[old.Storage]
			or type(old.Luck) ~= "number" or old.Luck % 1 ~= 0 or old.Luck < 0 or old.Luck > 5
			or type(old.Speed) ~= "number" or old.Speed % 1 ~= 0 or old.Speed < 0 or old.Speed > 4 then return nil, "RecoveryRequired" end
		data.Upgrades = {Storage=storageMap[old.Storage], Slots=old.Slots, Luck=old.Luck*2, Speed=old.Speed*2, Auto=old.Auto}
	end
	if data.Upgrades == nil then
		local levels = {Luck = 0, Speed = 0, Auto = 0}
		for _, key in ipairs({"Storage", "Slots"}) do
			local value = key == "Storage" and data.InventoryCapacity or data.IncomeSlotCount
			for i, v in ipairs(Rules.Branches[key].Values) do if value == v then levels[key] = i - 1 end end
			if levels[key] == nil then return nil, "RecoveryRequired" end
		end
		data.Upgrades = levels
	end
	if type(data.Upgrades) ~= "table" then return nil, "RecoveryRequired" end
	if data.Upgrades.Batch == nil then data.Upgrades.Batch = 0 end
	for key, branch in pairs(Rules.Branches) do
		local level = data.Upgrades[key]
		if type(level) ~= "number" or level % 1 ~= 0 or level < 0 or level > #branch.Prices then return nil, "RecoveryRequired" end
	end
	if Rules.Branches.Storage.Values[data.Upgrades.Storage + 1] ~= data.InventoryCapacity
		or Rules.Branches.Slots.Values[data.Upgrades.Slots + 1] ~= data.IncomeSlotCount then return nil, "RecoveryRequired" end
	data.UpgradeTreeVersion = 2
	return {Status = "Ready", Levels = table.clone(data.Upgrades)}
end
function Service.Buy(session, key, expectedLevel)
	if session.Closed or session.Closing or session.LeaseUntil <= os.time() + 10 then return nil, "SessionUnavailable" end
	if session.NeedsRecovery then return nil, "RecoveryRequired" end
	if session.ProgressBusy or session.SpinBusy or session.SlotBusy or session.RequestBusy or session.Busy or session.Data.PendingSpin or session.Data.PendingSale then return nil, "Busy" end
	local branch = type(key) == "string" and Rules.Branches[key]
	if not branch or type(expectedLevel) ~= "number" or expectedLevel % 1 ~= 0 then return nil, "InvalidUpgrade" end
	session.ProgressBusy = true
	local ok, result, reason = pcall(function()
		if not Service.Initialize(session) then return nil, "RecoveryRequired" end
		local data = session.Data
		local level = data.Upgrades[key]
		if level ~= expectedLevel then return nil, "StaleUpgrade" end
		local price = branch.Prices[level + 1]
		if not price then return nil, "MaxUpgrade" end
		if Rules.Requirement(data.Upgrades, key) then return nil, "UpgradeLocked" end
		if data.Balance < price then return nil, "NotEnoughMoney" end
		-- A newcomer without any number must retain one ordinary regional draw.
		if next(data.Inventory) == nil and data.Balance - price < 5000 then return nil, "StarterReserve" end
		data.Balance -= price
		data.Upgrades[key] = level + 1
		if key == "Storage" then data.InventoryCapacity = branch.Values[level + 2] end
		if key == "Slots" then data.IncomeSlotCount = branch.Values[level + 2]; data.SlotRevision += 1 end
		if session.BalanceValue then session.BalanceValue.Value = data.Balance end
		-- Unknown outcome: keep the new snapshot and require recovery, never blindly refund.
		if not Store.Save(session, false) then return nil, "RecoveryRequired" end
		return {Status = "Success", Levels = table.clone(data.Upgrades), Branch = key, Paid = price}
	end)
	session.ProgressBusy = false
	if not ok or reason == "RecoveryRequired" then session.NeedsRecovery = true; return nil, "RecoveryRequired" end
	return result, reason
end
return Service
