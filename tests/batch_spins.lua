return function(Service,Config,Generator,Registry,IO)
	local passed={}
	local function test(name,fn) IO.Records={};IO.OccupySecond=false;IO.LoseSecond=false;Registry.Occupied=0;fn();table.insert(passed,name) end
	local function fixture()
		return {UserId=1,LeaseUntil=os.time()+1000,Data={Balance=100000,Inventory={},InventoryCapacity=25,NextSpinSequence=1,Upgrades={Batch=2}}}
	end
	local function count(s) local n=0;for _ in pairs(s.Data.Inventory) do n+=1 end;return n end
	local function recover(s) return {UserId=1,LeaseUntil=os.time()+1000,Data=IO.Copy(s.Durable)} end
	test("three independent numbers charge the complete package once",function()
		local s=fixture();local r=assert(Service.Start(s,"beelink",Config.GetDefaultOffer("beelink").Id,1,3))
		assert(#r.Items==3 and count(s)==3 and s.Data.Balance==85000 and s.Data.NextSpinSequence==2 and s.Writes==4)
		local seen={};for _,v in ipairs(r.Items) do assert(not seen[v.IssuanceId] and v.OfferPrice==5000);seen[v.IssuanceId]=true end
	end)
	test("duplicate package request replays without payment or extra numbers",function()
		local s=fixture();local region=Config.GetDefaultOffer("beelink").Id;assert(Service.Start(s,"beelink",region,1,3));local writes=s.Writes
		local r=assert(Service.Start(s,"beelink",region,1,3));assert(#r.Items==3 and count(s)==3 and s.Data.Balance==85000 and s.Writes==writes)
	end)
	test("all money and all places are checked before payment",function()
		local s=fixture();s.Data.Balance=14999;local r,c=Service.Start(s,"beelink",Config.GetDefaultOffer("beelink").Id,1,3);assert(not r and c=="NotEnoughMoney" and not s.Writes)
		s=fixture();s.Data.InventoryCapacity=2;r,c=Service.Start(s,"beelink",Config.GetDefaultOffer("beelink").Id,1,3);assert(not r and c=="InventoryFull" and s.Data.Balance==100000)
	end)
	test("locked upgrades and unconfigured four-number pass reject before charge",function()
		local s=fixture();s.Data.Upgrades.Batch=0;local region=Config.GetDefaultOffer("beelink").Id
		local r,c=Service.Start(s,"beelink",region,1,2);assert(not r and c=="BatchLocked")
		r,c=Service.Start(s,"beelink",region,1,4);assert(not r and c=="InvalidBatch" and not s.Writes)
	end)
	test("occupied second number refunds only unissued portion",function()
		local s=fixture();IO.OccupySecond=true;local r=assert(Service.Start(s,"beelink",Config.GetDefaultOffer("beelink").Id,1,3))
		assert(#r.Items==1 and r.Refunded==10000 and count(s)==1 and s.Data.Balance==95000 and not s.Data.PendingSpin)
	end)
	test("unknown partial profile write recovers without duplicate or recharge",function()
		for _,mode in ipairs({"before","after"}) do
			IO.Records={};local s=fixture();s.FailAt=2;s.FailMode=mode
			local r,c=Service.Start(s,"beelink",Config.GetDefaultOffer("beelink").Id,1,3);assert(not r and c=="RecoveryRequired")
			local fresh=recover(s);assert(Service.Recover(fresh));assert(count(fresh)==3 and fresh.Data.Balance==85000 and not fresh.Data.PendingSpin)
		end
	end)
	test("unknown final profile write recovers all three",function()
		for _,mode in ipairs({"before","after"}) do
			IO.Records={};local s=fixture();s.FailAt=4;s.FailMode=mode
			local r,c=Service.Start(s,"beelink",Config.GetDefaultOffer("beelink").Id,1,3);assert(not r and c=="RecoveryRequired")
			local fresh=recover(s);assert(Service.Recover(fresh));assert(count(fresh)==3 and fresh.Data.Balance==85000 and not fresh.Data.PendingSpin)
		end
	end)
	test("lost registry reserve reply resumes the same second issuance",function()
		local s=fixture();IO.LoseSecond=true;local r,c=Service.Start(s,"beelink",Config.GetDefaultOffer("beelink").Id,1,3);assert(not r and c=="RecoveryRequired")
		local fresh=recover(s);assert(Service.Recover(fresh));assert(count(fresh)==3 and fresh.Data.Balance==85000)
	end)
	return passed
end
