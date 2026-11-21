-- Exact SpinService with fake store/registry/generator; no real profile access.
return function(Service, Config, Generator, Registry)
	local passed = {}
	local function fixture()
		return {UserId = 1, LeaseUntil = os.time() + 1000, Data = {Balance = 100000, Inventory = {}, InventoryCapacity = 25, NextSpinSequence = 1}}
	end
	local function test(name, callback)
		Generator.Rarity, Registry.Occupied = 1, 0
		callback(); table.insert(passed, name)
	end
	test("all operator and region pairs use the same six rarity weights", function()
		local expected = {6000000,3000000,880000,110000,9900,100}
		for _, operator in ipairs(Config.Operators) do
			for _, offer in ipairs(Config.GetRegionOffers(operator.Id)) do
				assert(offer.ProfileId == "Regional" and #offer.Codes > 0)
				for i,w in ipairs(expected) do assert(Config.Profiles[offer.ProfileId].Weights[i] == w) end
			end
		end
	end)
	test("server selects a legal prefix and charges exact region price", function()
		for _, operator in ipairs(Config.Operators) do
			local s = fixture(); local offer = Config.GetDefaultOffer(operator.Id)
			local result = assert(Service.Start(s, operator.Id, offer.Id, 1))
			assert(result.Status == "Success" and s.Data.Balance == 95000 and s.Writes == 2)
			assert(table.find(offer.Codes, result.Item.Code) and result.Item.OperatorId == operator.Id and result.Item.RegionId == offer.Id)
			assert(result.Item.EconomyVersion == 3 and result.Item.PrestigeMultiplier == 1)
		end
	end)
	test("million city and capital prices do not guarantee rarity", function()
		for _, data in ipairs({{"city_kazan",7500},{"city_moscow",10000},{"city_spb",10000}}) do
			local s=fixture(); local result=assert(Service.Start(s,"beelink",data[1],1))
			assert(s.Data.Balance == 100000-data[2] and result.Item.RarityIndex == 1 and result.Item.OfferPrice == data[2])
		end
	end)
	test("invalid region and old code payload do not charge", function()
		local s=fixture(); local result,code=Service.Start(s,"beelink","invalid",1)
		assert(not result and code=="InvalidRegion" and not s.Writes and s.Data.Balance==100000)
		result,code=Service.Start(s,"903",1,nil)
		assert(not result and code=="InvalidRegion" and not s.Writes)
	end)
	test("insufficient balance and full inventory do not charge", function()
		local s=fixture(); s.Data.Balance=9999
		local result,code=Service.Start(s,"beelink","city_moscow",1)
		assert(not result and code=="NotEnoughMoney" and not s.Writes)
		s=fixture(); s.Data.InventoryCapacity=0
		result,code=Service.Start(s,"beelink","city_moscow",1)
		assert(not result and code=="InventoryFull" and not s.Writes)
	end)
	test("same sequence replays receipt without second payment", function()
		local s=fixture(); assert(Service.Start(s,"beelink","city_moscow",1))
		local balance,writes=s.Data.Balance,s.Writes
		local result=assert(Service.Start(s,"beelink","city_moscow",1))
		assert(result.Status=="Success" and s.Data.Balance==balance and s.Writes==writes)
	end)
	test("occupied candidates refund the original premium price", function()
		Registry.Occupied=100
		local s=fixture(); local result=assert(Service.Start(s,"beelink","city_moscow",1))
		assert(result.Status=="Cancelled" and s.Data.Balance==100000 and s.Data.PendingSpin==nil)
	end)
	test("failed initial write keeps pending journal and freezes session", function()
		local s=fixture(); s.FailSave=true
		local result,code=Service.Start(s,"beelink","city_moscow",1)
		assert(not result and code=="RecoveryRequired" and s.NeedsRecovery and s.Data.PendingSpin.Price==10000 and s.Data.Balance==90000)
	end)
	test("legacy pending spin recovers without new payment", function()
		local s=fixture(); s.Data.Balance=95000; s.Data.NextSpinSequence=2
		s.Data.PendingSpin={OperationId="legacy",Sequence=1,Price=5000,Attempt=1,NotBeforeMillis=0,
			Draft={FullNumber="79035831946",DisplayNumber="+7 (903) 583-19-46",Digits="5831946",Code="903",RarityIndex=1,
				ProfileId="Starter",OperatorId="beelink",OperatorName="БиЛайнк",Region="Москва",SalePrice=2000,IncomePerHour=10000}}
		Registry.Occupied=1
		local result=assert(Service.Recover(s))
		assert(result.Status=="Success" and s.Data.Balance==95000 and s.Data.PendingSpin==nil)
	end)
	return passed
end
