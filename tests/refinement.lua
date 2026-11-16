return function(U, S, Registry, Rules, IO, Economy)
	local results={}
	local function test(name, f) IO.Reset(); f(); table.insert(results,name) end
	local function profile() return {UserId=123,LeaseUntil=os.time()+1000,Data={Balance=10000000,Inventory={},IncomeSlots={},SlotRevision=0,InventoryCapacity=25,IncomeSlotCount=3}} end
	test("all expanded tiers and dependencies",function()
		local s=profile(); assert(U.Initialize(s)); local r,c=U.Buy(s,"Auto",0); assert(not r and c=="UpgradeLocked")
		for i=0,8 do assert(U.Buy(s,"Storage",i)) end
		for i=0,9 do assert(U.Buy(s,"Luck",i)) end
		for i=0,7 do assert(U.Buy(s,"Speed",i)) end
		assert(U.Buy(s,"Slots",0)); assert(U.Buy(s,"Slots",1)); assert(U.Buy(s,"Auto",0))
		assert(s.Data.InventoryCapacity==200 and s.Data.IncomeSlotCount==5 and Rules.Duration(6,8)==5)
	end)
	test("old purchased effects migrate without charges",function()
		local s=profile();s.Data.InventoryCapacity=100;s.Data.IncomeSlotCount=4
		s.Data.Upgrades={Storage=2,Slots=1,Luck=3,Speed=2,Auto=1}
		assert(U.Initialize(s));assert(s.Data.Upgrades.Storage==5 and s.Data.Upgrades.Luck==6 and s.Data.Upgrades.Speed==4 and s.Data.Upgrades.Auto==1 and s.Data.Balance==10000000)
		assert(U.Initialize(s));assert(s.Data.Upgrades.Luck==6)
	end)
	test("requirements independently protect each unlock",function()
		local s=profile();assert(U.Initialize(s));local r,c=U.Buy(s,"Slots",0);assert(not r and c=="UpgradeLocked")
		assert(U.Buy(s,"Storage",0));assert(U.Buy(s,"Storage",1));assert(U.Buy(s,"Slots",0))
		r,c=U.Buy(s,"Slots",1);assert(not r and c=="UpgradeLocked")
	end)
	test("duplicate request and newcomer reserve",function()
		local s=profile();s.Data.Balance=7999;assert(U.Buy(s,"Luck",0)==nil);s.Data.Balance=8000;assert(U.Buy(s,"Luck",0));assert(s.Data.Balance==5000)
		local r,c=U.Buy(s,"Luck",0);assert(not r and c=="StaleUpgrade")
	end)
	test("income varies with exact modifiers and migration preserves price",function()
		local a=Economy.Evaluate("5831946","903","Regional");local b=Economy.Evaluate("1289394","986","Regional")
		assert(a.IncomePerHour~=b.IncomePerHour and a.IncomeFormulaVersion==2)
		a.Digits="5831946";a.Code="903";a.ProfileId="Regional";b.Digits="1289394";b.Code="986";b.ProfileId="Regional"
		local expected=a.IncomePerHour
		local data={Inventory={a=a,b=b}};a.IncomePerHour=10000;a.IssuanceId="a";local price=a.SalePrice
		Economy.RefreshIncome(data);assert(a.IncomePerHour~=10000 and a.SalePrice==price and a.IssuanceId=="a")
		assert(a.IncomePerHour==expected)
	end)
	test("normalizing luck preserves total probability",function()
		local weights,total=Rules.Weights({6000000,3000000,880000,110000,9900,100},10)
		assert(weights[1]==1200000000 and weights[6]==23000 and total==2120000000)
	end)
	return results
end
