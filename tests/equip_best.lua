-- Use the exact slot-service source with a fake PlayerDataStore, never a real player.
return function(Service)
	local passed = {}
	local function fixture()
		local s = {LeaseUntil = os.time() + 1000, Data = {Balance = 85000, IncomeSlotCount = 3, SlotRevision = 0, IncomeSlots = {}, Inventory = {}}}
		for i, id in ipairs({"a", "b", "c", "d", "e"}) do
			s.Data.Inventory[id] = {IssuanceId = id, DisplayNumber = id, RarityName = "Test", Location = "Inventory", IncomePerHour = i * 1000, SalePrice = i * 100}
		end
		return s
	end
	local function selected(s)
		local ids = {}
		for _, slot in pairs(s.Data.IncomeSlots) do if slot.IssuanceId then table.insert(ids, slot.IssuanceId) end end
		table.sort(ids); return table.concat(ids)
	end
	local function test(name, fn) fn(); table.insert(passed, name) end
	test("fills available slots by income in one save", function()
		local s=fixture(); local r=assert(Service.EquipBest(s,0))
		assert(selected(s)=="cde" and s.Writes==1 and s.Data.SlotRevision==1 and r.State.TotalBaseIncomePerHour==12000 and s.Data.Balance==85000)
	end)
	test("cost breaks income ties", function()
		local s=fixture(); for _,item in pairs(s.Data.Inventory) do item.IncomePerHour=1000 end
		assert(Service.EquipBest(s,0)); assert(selected(s)=="cde")
	end)
	test("identifier breaks exact ties deterministically", function()
		local s=fixture(); for _,item in pairs(s.Data.Inventory) do item.IncomePerHour=1000; item.SalePrice=100 end
		assert(Service.EquipBest(s,0)); assert(selected(s)=="abc")
	end)
	test("replaces old set and returns old items to inventory", function()
		local s=fixture(); assert(Service.Install(s,1,"a",0)); assert(Service.EquipBest(s,1))
		assert(selected(s)=="cde" and s.Data.Inventory.a.Location=="Inventory" and s.Data.Inventory.a.IncomeSlotIndex==nil)
	end)
	test("same best set is unchanged without write or revision", function()
		local s=fixture(); assert(Service.EquipBest(s,0)); local writes=s.Writes
		local r=assert(Service.EquipBest(s,1)); assert(r.Status=="Unchanged" and s.Writes==writes and s.Data.SlotRevision==1)
	end)
	test("retains selected items in existing slots", function()
		local s=fixture(); assert(Service.Install(s,3,"e",0)); assert(Service.EquipBest(s,1))
		assert(s.Data.IncomeSlots["3"].IssuanceId=="e")
	end)
	test("stale revision rejected without write", function()
		local s=fixture(); s.Data.SlotRevision=3
		local r,code=Service.EquipBest(s,0); assert(not r and code=="StaleSlots" and not s.Writes)
	end)
	test("items busy elsewhere are excluded", function()
		local s=fixture(); s.Data.Inventory.e.Location="Market"
		assert(Service.EquipBest(s,0)); assert(selected(s)=="bcd" and s.Data.Inventory.e.Location=="Market")
	end)
	test("empty collection is unchanged", function()
		local s=fixture(); s.Data.Inventory={}; local r=assert(Service.EquipBest(s,0))
		assert(r.Status=="Unchanged" and not s.Writes)
	end)
	test("one item fills one slot without duplication", function()
		local s=fixture(); s.Data.Inventory={a=s.Data.Inventory.a}; assert(Service.EquipBest(s,0)); assert(selected(s)=="a")
	end)
	test("replacement has no hour delay", function()
		local s=fixture(); assert(Service.Install(s,1,"a",0)); local r=assert(Service.Install(s,1,"b",1))
		assert(r.State.Slots[1].CooldownRemaining==0 and r.State.Slots[1].NextChangeAt==0)
	end)
	test("last income source remains protected", function()
		local s=fixture(); assert(Service.Install(s,1,"a",0)); local r,code=Service.Remove(s,1,1)
		assert(not r and code=="LastIncomeSource")
	end)
	test("save failure freezes consistent assignment", function()
		local s=fixture(); s.SaveMode="fail"; local r,code=Service.EquipBest(s,0)
		assert(not r and code=="RecoveryRequired" and s.NeedsRecovery and selected(s)=="cde")
	end)
	test("income hook runs once before atomic save", function()
		local s=fixture(); local called=0; s.UpdateIncomeRate=function() called=called+1; return true end
		assert(Service.EquipBest(s,0)); assert(called==1 and s.Writes==1)
	end)
	test("busy and recovering sessions cannot optimize", function()
		local s=fixture(); s.SpinBusy=true; local r,code=Service.EquipBest(s,0); assert(not r and code=="Busy")
		s.SpinBusy=false; s.NeedsRecovery=true; r,code=Service.EquipBest(s,0); assert(not r and code=="RecoveryRequired" and not s.Writes)
	end)
	return passed
end
