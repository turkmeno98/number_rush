-- Assignment service; online income is settled by a server-session hook.
local PlayerDataStore = require(script.Parent:WaitForChild("PlayerDataStore"))
local IncomeSlotService = {}
IncomeSlotService.CooldownSeconds = 0 -- User removed the replacement delay.
IncomeSlotService.MaxSlots = 5

local function integer(value, minimum, maximum)
	return type(value) == "number" and value % 1 == 0
		and value >= minimum and value <= maximum
end

local function available(session)
	return type(session) == "table" and not session.Closed and not session.Closing
		and type(session.LeaseUntil) == "number" and session.LeaseUntil > os.time() + 10
end

-- The profile and its slot book are authoritative, never client attributes.
local function validateBook(data)
	if type(data) ~= "table" or type(data.Inventory) ~= "table"
		or type(data.IncomeSlots) ~= "table"
		or not integer(data.IncomeSlotCount, 1, IncomeSlotService.MaxSlots)
	then return false, "InvalidSlotBook" end
	if data.SlotRevision ~= nil and not integer(data.SlotRevision, 0, 1000000000000) then
		return false, "InvalidSlotRevision"
	end
	local assigned = {}
	for key, slot in pairs(data.IncomeSlots) do
		local index = tonumber(key)
		if type(key) ~= "string" or not integer(index, 1, data.IncomeSlotCount)
			or tostring(index) ~= key or type(slot) ~= "table"
		then return false, "InvalidSlotRecord" end
		if slot.ChangedAt ~= nil and not integer(slot.ChangedAt, 0, 1000000000000) then
			return false, "InvalidSlotTimestamp"
		end
		if slot.IssuanceId ~= nil then
			local id = slot.IssuanceId
			local item = data.Inventory[id]
			if type(id) ~= "string" or assigned[id] or type(item) ~= "table"
				or item.IssuanceId ~= id or item.Location ~= "IncomeSlot"
				or item.IncomeSlotIndex ~= index or slot.ChangedAt == nil
			then return false, "InconsistentSlotOwnership" end
			assigned[id] = index
		end
	end
	for id, item in pairs(data.Inventory) do
		if type(id) ~= "string" or type(item) ~= "table" or item.IssuanceId ~= id
			or type(item.DisplayNumber) ~= "string" or type(item.Location) ~= "string"
			or not integer(item.IncomePerHour, 0, 1000000000)
		then return false, "InvalidInventoryItem" end
		if item.Location == "IncomeSlot" then
			if assigned[id] ~= item.IncomeSlotIndex or not assigned[id] then
				return false, "OrphanIncomeSlotItem"
			end
		elseif item.IncomeSlotIndex ~= nil then
			return false, "UnexpectedSlotIndex"
		end
	end
	if data.SlotRevision == nil then data.SlotRevision = 0 end
	return true
end

local function snapshot(data, incomeEnabled)
	local now = os.time()
	local state = {Revision = data.SlotRevision, SlotCount = data.IncomeSlotCount,
		ActiveCount = 0, TotalBaseIncomePerHour = 0, IncomeEnabled = incomeEnabled == true, ServerTime = now, Slots = {}}
	for index = 1, data.IncomeSlotCount do
		local slot = data.IncomeSlots[tostring(index)]
		local changedAt = slot and slot.ChangedAt
		local nextChangeAt = 0
		local row = {SlotIndex = index, LastChangedAt = changedAt or 0,
			NextChangeAt = nextChangeAt, CooldownRemaining = math.max(0, nextChangeAt - now)}
		if slot and slot.IssuanceId then
			local item = data.Inventory[slot.IssuanceId]
			row.IssuanceId = slot.IssuanceId
			row.DisplayNumber = item.DisplayNumber
			row.RarityName = item.RarityName
			row.IncomePerHour = item.IncomePerHour
			state.ActiveCount = state.ActiveCount + 1
			state.TotalBaseIncomePerHour = state.TotalBaseIncomePerHour + item.IncomePerHour
		end
		table.insert(state.Slots, row)
	end
	return state
end

local function run(session, callback)
	if not available(session) then return nil, "SessionUnavailable" end
	if session.NeedsRecovery then return nil, "RecoveryRequired" end
	if type(session.Data) ~= "table" then return nil, "RecoveryRequired", "MissingProfileData" end
	if session.SlotBusy or session.SpinBusy or session.RequestBusy or session.Busy or session.ProgressBusy
		or session.Data.PendingSpin or session.Data.PendingSale then return nil, "Busy" end
	session.SlotBusy = true
	local ok, result, code, details = pcall(function()
		local valid, reason = validateBook(session.Data)
		if not valid then return nil, "RecoveryRequired", reason end
		return callback()
	end)
	session.SlotBusy = false
	if not ok then session.NeedsRecovery = true; return nil, "RecoveryRequired", tostring(result) end
	if code == "RecoveryRequired" then session.NeedsRecovery = true end
	return result, code, details
end

local function checkRequest(data, index, revision)
	if not integer(index, 1, data.IncomeSlotCount) then return false, "InvalidSlot" end
	if not integer(revision, 0, 1000000000000) then return false, "InvalidRevision" end
	if revision ~= data.SlotRevision then return false, "StaleSlots" end
	if data.SlotRevision >= 1000000000000 then return false, "RevisionLimit" end
	return true
end

local function saveMutation(session)
	if not available(session) then return nil, "RecoveryRequired", "SessionClosing" end
	if session.UpdateIncomeRate then
		local ok, reason = session.UpdateIncomeRate()
		if not ok then return nil, "RecoveryRequired", reason end
	end
	local saved, reason = PlayerDataStore.Save(session, false)
	-- On an unknown write outcome retain the consistent new state; never roll back blindly.
	if not saved then return nil, "RecoveryRequired", tostring(reason) end
	if not available(session) then return nil, "RecoveryRequired", "SessionClosing" end
	return {Status = "Success", State = snapshot(session.Data, session.IncomeClock ~= nil)}
end

function IncomeSlotService.Initialize(session)
	return run(session, function() return {Status = "Ready", State = snapshot(session.Data, session.IncomeClock ~= nil)} end)
end

IncomeSlotService.GetState = IncomeSlotService.Initialize

function IncomeSlotService.Install(session, index, issuanceId, revision)
	return run(session, function()
		local data = session.Data
		local valid, code = checkRequest(data, index, revision)
		if not valid then return nil, code end
		if type(issuanceId) ~= "string" or #issuanceId == 0 or #issuanceId > 64 then return nil, "InvalidItem" end
		local item = data.Inventory[issuanceId]
		if not item then return nil, "ItemNotOwned" end
		local key = tostring(index)
		local slot = data.IncomeSlots[key]
		if slot and slot.IssuanceId == issuanceId then
			return {Status = "Unchanged", State = snapshot(data, session.IncomeClock ~= nil)}
		end
		if item.Location == "IncomeSlot" then return nil, "AlreadyAssigned" end
		if item.Location ~= "Inventory" then return nil, "ItemUnavailable" end
		local now = os.time()
		if slot and slot.IssuanceId then
			local previous = data.Inventory[slot.IssuanceId]
			previous.Location = "Inventory"
			previous.IncomeSlotIndex = nil
		end
		data.IncomeSlots[key] = {IssuanceId = issuanceId, ChangedAt = now}
		item.Location = "IncomeSlot"
		item.IncomeSlotIndex = index
		data.SlotRevision = data.SlotRevision + 1
		return saveMutation(session)
	end)
end

function IncomeSlotService.Remove(session, index, revision)
	return run(session, function()
		local data = session.Data
		local valid, code = checkRequest(data, index, revision)
		if not valid then return nil, code end
		local slot = data.IncomeSlots[tostring(index)]
		if not slot or not slot.IssuanceId then return {Status = "Unchanged", State = snapshot(data, session.IncomeClock ~= nil)} end
		local activeCount = 0
		for _, record in pairs(data.IncomeSlots) do
			if record.IssuanceId then activeCount = activeCount + 1 end
		end
		if activeCount <= 1 then return nil, "LastIncomeSource" end
		local item = data.Inventory[slot.IssuanceId]
		item.Location = "Inventory"
		item.IncomeSlotIndex = nil
		slot.IssuanceId = nil
		-- ChangedAt is historical metadata, not a replacement restriction.
		data.SlotRevision = data.SlotRevision + 1
		return saveMutation(session)
	end)
end

function IncomeSlotService.EquipBest(session, revision)
	return run(session, function()
		local data = session.Data
		local valid, code = checkRequest(data, 1, revision)
		if not valid then return nil, code end
		local candidates = {}
		for id, item in pairs(data.Inventory) do
			if item.Location == "Inventory" or item.Location == "IncomeSlot" then
				if not integer(item.SalePrice, 0, 1000000000000) then return nil, "RecoveryRequired", "InvalidItemPrice" end
				table.insert(candidates, {Id = id, Item = item})
			end
		end
		table.sort(candidates, function(a, b)
			if a.Item.IncomePerHour ~= b.Item.IncomePerHour then return a.Item.IncomePerHour > b.Item.IncomePerHour end
			if a.Item.SalePrice ~= b.Item.SalePrice then return a.Item.SalePrice > b.Item.SalePrice end
			return a.Id < b.Id
		end)
		local chosen, selected = {}, {}
		for i = 1, math.min(data.IncomeSlotCount, #candidates) do chosen[i] = candidates[i].Id; selected[chosen[i]] = true end
		-- Keep selected numbers in their existing slots: equal requests are idempotent.
		local target, placed = {}, {}
		for i = 1, data.IncomeSlotCount do
			local old = data.IncomeSlots[tostring(i)]
			if old and selected[old.IssuanceId] then target[i] = old.IssuanceId; placed[old.IssuanceId] = true end
		end
		for _, id in ipairs(chosen) do
			if not placed[id] then
				for i = 1, data.IncomeSlotCount do if not target[i] then target[i] = id; placed[id] = true; break end end
			end
		end
		local changed = false
		for i = 1, data.IncomeSlotCount do
			local old = data.IncomeSlots[tostring(i)]
			if (old and old.IssuanceId or nil) ~= target[i] then changed = true; break end
		end
		if not changed then return {Status = "Unchanged", State = snapshot(data, session.IncomeClock ~= nil)} end
		local now = os.time()
		for _, item in pairs(data.Inventory) do
			if item.Location == "IncomeSlot" then item.Location = "Inventory"; item.IncomeSlotIndex = nil end
		end
		for i = 1, data.IncomeSlotCount do
			local id = target[i]
			data.IncomeSlots[tostring(i)] = {IssuanceId = id, ChangedAt = now}
			if id then data.Inventory[id].Location = "IncomeSlot"; data.Inventory[id].IncomeSlotIndex = i end
		end
		data.SlotRevision = data.SlotRevision + 1
		-- One profile snapshot contains the complete assignment; no intermediate empty state is saved.
		return saveMutation(session)
	end)
end

return IncomeSlotService
