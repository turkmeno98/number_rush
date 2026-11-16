-- Exact production services, controlled in-memory storage; never real player data.
return function(Upgrades, Sales, Registry, Rules, IO)
	local passed = {}
	local function test(name, fn) IO.Reset(); fn(); table.insert(passed, name) end
	local function fixture()
		return {UserId = 123, LeaseUntil = os.time() + 1000, Data = {Balance = 1000000, InventoryCapacity = 25, IncomeSlotCount = 3, SlotRevision = 0, IncomeSlots = {}, Inventory = {}}}
	end
	local function item(s)
		local full = "79031234567"
		local r = assert(Registry.Reserve(full, s.UserId, "spin-op"))
		assert(Registry.Confirm(full, s.UserId, "spin-op"))
		local value = {IssuanceId = r.IssuanceId, Generation = r.Generation, FullNumber = full, Location = "Inventory", SalePrice = 5000}
		s.Data.Inventory[value.IssuanceId] = value
		return value
	end
	local function recovered(s)
		return {UserId = s.UserId, LeaseUntil = os.time() + 1000, Data = IO.Copy(s.Durable)}
	end
	test("old profile gains zero levels without resetting balance or inventory", function()
		local s=fixture(); local v=item(s); assert(Upgrades.Initialize(s)); assert(s.Data.Upgrades.Luck==0 and s.Data.Balance==1000000 and s.Data.Inventory[v.IssuanceId])
	end)
	test("storage tiers use exact prices and stop at 200", function()
		local s=fixture(); assert(Upgrades.Initialize(s))
		for level,price in ipairs({10000,35000,75000,150000}) do local before=s.Data.Balance; assert(Upgrades.Buy(s,"Storage",level-1)); assert(before-s.Data.Balance==price) end
		assert(s.Data.InventoryCapacity==200); local result,code=Upgrades.Buy(s,"Storage",4); assert(not result and code=="MaxUpgrade")
	end)
	test("slot tiers grow to five and invalidate old slot revision", function()
		local s=fixture(); assert(Upgrades.Initialize(s)); assert(Upgrades.Buy(s,"Slots",0)); assert(s.Data.IncomeSlotCount==4 and s.Data.Balance==830000 and s.Data.SlotRevision==1)
		assert(Upgrades.Buy(s,"Slots",1)); assert(s.Data.IncomeSlotCount==5 and s.Data.SlotRevision==2 and s.Data.Balance==380000)
	end)
	test("duplicate purchase cannot buy next level", function()
		local s=fixture(); assert(Upgrades.Buy(s,"Luck",0)); local before=s.Data.Balance; local r,c=Upgrades.Buy(s,"Luck",0); assert(not r and c=="StaleUpgrade" and before==s.Data.Balance and s.Writes==1)
	end)
	test("invalid and unaffordable upgrades do not mutate money", function()
		local s=fixture(); s.Data.Balance=0; local r,c=Upgrades.Buy(s,"Speed",0); assert(not r and c=="NotEnoughMoney"); assert(not Upgrades.Buy(s,"Unknown",0)); assert(not Upgrades.Buy(s,"Speed",0/0)); assert(s.Data.Balance==0 and not s.Writes)
	end)
	test("all five branches reach their documented caps", function()
		local s=fixture(); s.Data.Balance=10000000
		for _,key in ipairs(Rules.Order) do for level=0,#Rules.Branches[key].Prices-1 do assert(Upgrades.Buy(s,key,level)) end end
		assert(s.Data.Upgrades.Auto==1 and s.Data.Upgrades.Speed==4 and s.Data.Upgrades.Luck==5)
	end)
	test("newcomer cannot spend their last draw on upgrades", function()
		local s=fixture(); s.Data.Balance=10000; local r,c=Upgrades.Buy(s,"Storage",0)
		assert(not r and c=="StarterReserve" and s.Data.Balance==10000 and not s.Writes)
		s.Data.Balance=15000; assert(Upgrades.Buy(s,"Storage",0)); assert(s.Data.Balance==5000)
	end)
	test("luck adjusts weights and normalizes without a regional guarantee", function()
		local base={6000000,3000000,880000,110000,9900,100}
		local w,total=Rules.Weights(base,5); assert(w[1]==600000000 and w[6]==11500 and total==1060000000)
		local sum=0; for _,v in ipairs(w) do sum+=v/total end; assert(math.abs(sum-1)<1e-12)
		local plain,t=Rules.Weights(base,0); assert(plain[1]/t==0.6 and base[1]==6000000)
		assert(Rules.Duration(6,4)==5 and Rules.Duration(6,0)==6)
	end)
	test("purchase write uncertainty requires recovery and preserves transaction snapshot", function()
		local s=fixture(); IO.ProfileFailAt=1; local r,c=Upgrades.Buy(s,"Auto",0); assert(not r and c=="RecoveryRequired" and s.NeedsRecovery and s.Data.Balance==975000 and s.Data.Upgrades.Auto==1)
		assert(not Upgrades.Buy(s,"Storage",0))
	end)
	test("busy and expired sessions reject purchases and sale", function()
		local s=fixture(); local v=item(s); s.SpinBusy=true; assert(not Upgrades.Buy(s,"Storage",0)); assert(not Sales.Sell(s,v.IssuanceId)); s.SpinBusy=false; s.LeaseUntil=os.time(); assert(not Upgrades.Buy(s,"Storage",0)); assert(not Sales.Sell(s,v.IssuanceId)); assert(s.Data.Balance==1000000)
	end)
	test("sale commits exact payout and releases owned issuance", function()
		local s=fixture(); local v=item(s); local r=assert(Sales.Sell(s,v.IssuanceId)); assert(r.Amount==5000 and s.Data.Balance==1005000 and not s.Data.Inventory[v.IssuanceId] and not s.Data.PendingSale and s.Writes==2); assert(IO.Records[v.FullNumber].State=="Free")
	end)
	test("duplicate sale pays once", function()
		local s=fixture(); local v=item(s); assert(Sales.Sell(s,v.IssuanceId)); assert(Sales.Sell(s,v.IssuanceId)); assert(s.Data.Balance==1005000 and s.Writes==2)
	end)
	test("installed number is protected including last income source", function()
		local s=fixture(); local v=item(s); v.Location="IncomeSlot"; v.IncomeSlotIndex=1
		local r,c=Sales.Sell(s,v.IssuanceId); assert(not r and c=="ItemInstalled" and s.Data.Inventory[v.IssuanceId] and s.Data.Balance==1000000)
	end)
	test("foreign and malformed sales reject without payout", function()
		local s=fixture(); assert(not Sales.Sell(s,"foreign")); assert(not Sales.Sell(s,{})); assert(s.Data.Balance==1000000 and not s.Writes)
	end)
	test("uncertain initial profile commit does not release until recovered", function()
		local s=fixture(); local v=item(s); IO.ProfileFailAt=1; assert(not Sales.Sell(s,v.IssuanceId)); assert(IO.Records[v.FullNumber].State=="Owned" and s.NeedsRecovery)
		IO.ProfileFailAt=nil; local fresh=recovered(s); assert(Sales.Recover(fresh)); assert(fresh.Data.Balance==1005000 and IO.Records[v.FullNumber].State=="Free")
	end)
	test("lost registry release response recovers idempotently", function()
		local s=fixture(); local v=item(s); IO.RegistryFail=true; assert(not Sales.Sell(s,v.IssuanceId)); assert(IO.Records[v.FullNumber].State=="Free")
		IO.RegistryFail=false; local fresh=recovered(s); assert(Sales.Recover(fresh)); assert(fresh.Data.Balance==1005000 and not fresh.Data.PendingSale)
	end)
	test("uncertain final save followed by reissue never releases new owner's number", function()
		local s=fixture(); local v=item(s); IO.ProfileFailAt=2; assert(not Sales.Sell(s,v.IssuanceId))
		local new=assert(Registry.Reserve(v.FullNumber,456,"new-spin")); assert(Registry.Confirm(v.FullNumber,456,"new-spin")); assert(new.Generation==2)
		IO.ProfileFailAt=nil; local fresh=recovered(s); assert(Sales.Recover(fresh)); assert(fresh.Data.Balance==1005000 and IO.Records[v.FullNumber].OwnerId==456 and IO.Records[v.FullNumber].State=="Owned")
	end)
	test("same-generation owner mismatch blocks recovery", function()
		local s=fixture(); local v=item(s); IO.Records[v.FullNumber].OwnerId=456
		assert(not Sales.Sell(s,v.IssuanceId)); assert(s.NeedsRecovery and s.Data.PendingSale and IO.Records[v.FullNumber].OwnerId==456)
	end)
	test("pending sale blocks other purchases", function()
		local s=fixture(); s.Data.PendingSale={}; local r,c=Upgrades.Buy(s,"Storage",0); assert(not r and c=="Busy" and not s.Writes)
	end)
	return passed
end
