-- Execute the actual IncomeSlotService source with a controlled profile-store boundary.
local now, writes, mode, persisted
local function clone(t)
	if type(t) ~= "table" then return t end
	local result = {}
	for k,v in pairs(t) do result[k] = clone(v) end
	return result
end
local function equal(a,b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
local store = {}
function store.Save(session, release)
	assert(release == false, "slot change must not release the profile")
	assert(session.SlotBusy, "mutation must hold the slot guard")
	writes = writes + 1
	if mode == "fail" then return false, "network unavailable" end
	persisted = clone(session.Data)
	if mode == "unknown" then return false, "write committed, response lost" end
	if mode == "close" then session.Closed = true end
	return true
end
script = {Parent = {WaitForChild = function(_,name) return name end}}
local originalRequire = require
require = function(name)
	if name == "PlayerDataStore" then return store end
	return originalRequire(name)
end
os.time = function() return now end
local Service = assert(loadfile(SLOT_SERVICE_PATH))()

local function fixture()
	now, writes, mode, persisted = 1700000000, 0, nil, nil
	local data = {Balance = 85000, Inventory = {}, IncomeSlots = {}, IncomeSlotCount = 3, SlotRevision = 0}
	for _, id in ipairs({"a","b","c"}) do
		data.Inventory[id] = {IssuanceId = id, DisplayNumber = id, Location = "Inventory", IncomePerHour = 10000, SalePrice = 1000, RarityName = "Обычный"}
	end
	return {UserId = 1, LeaseUntil = now + 100000, Data = data, Closed = false, Busy = false}
end
local function errorWithoutMutation(session, expected, callback)
	local before, beforeWrites = clone(session.Data), writes
	local result, code = callback()
	assert(result == nil and code == expected, tostring(code) .. " != " .. expected)
	assert(equal(session.Data,before), "rejected request mutated the profile")
	assert(writes == beforeWrites, "rejected request wrote data")
end
local count = 0
local function test(name, callback)
	local ok, err = pcall(callback)
	if not ok then error(name .. ": " .. tostring(err), 0) end
	count = count + 1
	print("PASS " .. name)
end

test("initializes legacy empty slots without resetting balance or inventory", function()
	local s = fixture(); s.Data.SlotRevision = nil
	local r = assert(Service.Initialize(s))
	assert(r.State.Revision == 0 and #r.State.Slots == 3 and r.State.ActiveCount == 0)
	assert(s.Data.Balance == 85000 and s.Data.Inventory.a and writes == 0)
end)
test("installs and persists both slot and item location, no money change", function()
	local s = fixture(); local r = assert(Service.Install(s,1,"a",0))
	assert(r.Status == "Success" and r.State.ActiveCount == 1 and r.State.TotalBaseIncomePerHour == 10000)
	assert(s.Data.IncomeSlots["1"].IssuanceId == "a" and s.Data.Inventory.a.IncomeSlotIndex == 1)
	assert(s.Data.Inventory.a.Location == "IncomeSlot" and s.Data.Balance == 85000 and writes == 1)
	assert(equal(persisted,s.Data) and not s.SlotBusy)
end)
test("same assignment does not restart cooldown or save twice", function()
	local s=fixture(); assert(Service.Install(s,1,"a",0)); local first=s.Data.IncomeSlots["1"].ChangedAt
	now=now+5
	local r=assert(Service.Install(s,1,"a",1))
	assert(r.Status=="Unchanged" and writes==1 and s.Data.IncomeSlots["1"].ChangedAt==first)
end)
test("stale duplicate cannot change slots", function()
	local s=fixture(); assert(Service.Install(s,1,"a",0))
	errorWithoutMutation(s,"StaleSlots",function() return Service.Install(s,1,"a",0) end)
end)
test("one item cannot occupy two slots", function()
	local s=fixture(); assert(Service.Install(s,1,"a",0))
	errorWithoutMutation(s,"AlreadyAssigned",function() return Service.Install(s,2,"a",1) end)
end)
test("unowned item is rejected", function()
	local s=fixture(); errorWithoutMutation(s,"ItemNotOwned",function() return Service.Install(s,1,"foreign",0) end)
end)
test("locked fourth slot and fractional slot rejected", function()
	local s=fixture()
	for _,i in ipairs({0,4,1.5}) do errorWithoutMutation(s,"InvalidSlot",function() return Service.Install(s,i,"a",0) end) end
end)
test("item in another activity is unavailable", function()
	local s=fixture(); s.Data.Inventory.a.Location="Market"
	errorWithoutMutation(s,"ItemUnavailable",function() return Service.Install(s,1,"a",0) end)
end)
test("replacement immediately after install is allowed", function()
	local s=fixture(); assert(Service.Install(s,1,"a",0)); now=now+1
	assert(Service.Install(s,1,"b",1))
	assert(s.Data.IncomeSlots["1"].IssuanceId == "b")
end)
test("replacement releases old item without waiting", function()
	local s=fixture(); assert(Service.Install(s,1,"a",0))
	assert(Service.Install(s,1,"b",1))
	assert(s.Data.Inventory.a.Location=="Inventory" and s.Data.Inventory.a.IncomeSlotIndex==nil)
	assert(s.Data.Inventory.b.Location=="IncomeSlot" and s.Data.IncomeSlots["1"].IssuanceId=="b")
	assert(s.Data.Balance==85000 and writes==2)
end)
test("last source cannot be removed", function()
	local s=fixture(); assert(Service.Install(s,1,"a",0))
	errorWithoutMutation(s,"LastIncomeSource",function() return Service.Remove(s,1,1) end)
end)
test("removed slot can be filled immediately", function()
	local s=fixture(); assert(Service.Install(s,1,"a",0)); assert(Service.Install(s,2,"b",1))
	local changed=s.Data.IncomeSlots["1"].ChangedAt
	assert(Service.Remove(s,1,2))
	assert(s.Data.IncomeSlots["1"].ChangedAt==changed and s.Data.Inventory.a.Location=="Inventory")
	assert(Service.Install(s,1,"c",3))
end)
test("removing empty slot is unchanged", function()
	local s=fixture(); local r=assert(Service.Remove(s,2,0))
	assert(r.Status=="Unchanged" and writes==0 and s.Data.SlotRevision==0)
end)
test("spin and in-flight saves exclude slot writes", function()
	for _,flag in ipairs({"SpinBusy","RequestBusy","Busy","SlotBusy"}) do
		local s=fixture();s[flag]=true
		errorWithoutMutation(s,"Busy",function() return Service.Install(s,1,"a",0) end)
	end
end)
test("pending spin blocks slot mutation", function()
	local s=fixture();s.Data.PendingSpin={OperationId="pending"}
	errorWithoutMutation(s,"Busy",function() return Service.Install(s,1,"a",0) end)
end)
test("closed and expiring sessions cannot use save no-op", function()
	local s=fixture();s.Closed=true
	errorWithoutMutation(s,"SessionUnavailable",function() return Service.Install(s,1,"a",0) end)
	s=fixture();s.LeaseUntil=now+10
	errorWithoutMutation(s,"SessionUnavailable",function() return Service.Install(s,1,"a",0) end)
end)
test("failed save freezes session without unsafe rollback", function()
	local s=fixture();mode="fail"
	local r,code=Service.Install(s,1,"a",0)
	assert(not r and code=="RecoveryRequired" and s.NeedsRecovery and not s.SlotBusy)
	assert(s.Data.IncomeSlots["1"].IssuanceId=="a" and s.Data.Inventory.a.Location=="IncomeSlot")
	assert(s.Data.Balance==85000)
end)
test("lost response after committed save does not undo assignment", function()
	local s=fixture();mode="unknown"
	local r,code=Service.Install(s,1,"a",0)
	assert(not r and code=="RecoveryRequired" and s.NeedsRecovery and equal(persisted,s.Data))
	assert(s.Data.Balance==85000)
end)
test("session closing during save is not reported as success", function()
	local s=fixture();mode="close"
	local r,code=Service.Install(s,1,"a",0)
	assert(not r and code=="RecoveryRequired" and s.NeedsRecovery)
end)
test("invalid duplicate slot book rejected without data reset", function()
	local s=fixture();assert(Service.Install(s,1,"a",0))
	s.Data.IncomeSlots["2"]={IssuanceId="a",ChangedAt=now}
	local before=clone(s.Data)
	local r,code=Service.Initialize(s)
	assert(not r and code=="RecoveryRequired" and equal(before,s.Data))
end)
test("orphaned income location is rejected", function()
	local s=fixture();s.Data.Inventory.a.Location="IncomeSlot";s.Data.Inventory.a.IncomeSlotIndex=1
	local r,code=Service.Initialize(s)
	assert(not r and code=="RecoveryRequired" and s.Data.Inventory.a.Location=="IncomeSlot")
end)
test("snapshot is potential income only", function()
	local s=fixture();assert(Service.Install(s,1,"a",0))
	local state=assert(Service.GetState(s)).State
	assert(state.IncomeEnabled==false and state.TotalBaseIncomePerHour==10000 and s.Data.Balance==85000)
end)
print(string.format("IncomeSlotService: %d tests passed (Lua 5.4 with mocked storage; not Roblox integration).",count))
