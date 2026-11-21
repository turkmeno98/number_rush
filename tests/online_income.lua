-- Run against the exact OnlineIncomeService module; no DataStore or real player.
return function(Service)
	local passed = {}
	local function fixture(amount)
		local item = {IssuanceId = "a", Location = "IncomeSlot", IncomeSlotIndex = 1, IncomePerHour = amount or 11000}
		local s = {LeaseUntil = os.time() + 10000, Data = {Balance = 0, Inventory = {a = item}, IncomeSlots = {["1"] = {IssuanceId = "a"}}, IncomeSlotCount = 3}}
		assert(Service.Initialize(s))
		s.IncomeClock = 1000
		s.IncomeStoppedAt = 1000
		return s
	end
	local function advance(s, milliseconds)
		s.IncomeStoppedAt = s.IncomeClock + milliseconds
		assert(Service.Accrue(s))
	end
	local function test(name, callback)
		callback()
		table.insert(passed, name)
	end
	test("one hour pays exact hourly rate", function()
		local s = fixture(); advance(s, 3600000)
		assert(s.Data.Balance == 11000 and s.Data.IncomeRemainder == 0)
	end)
	test("small ticks keep fractions instead of rounding each payment", function()
		local s = fixture()
		for _ = 1, 1000 do advance(s, 1000) end
		assert(s.Data.Balance == math.floor(11000 * 1000000 / 3600000))
		assert(s.Data.IncomeRemainder == (11000 * 1000000) % 3600000)
	end)
	test("repeated timestamp cannot pay twice", function()
		local s = fixture(); advance(s, 10000)
		local balance = s.Data.Balance; local remainder = s.Data.IncomeRemainder
		assert(Service.Accrue(s)); assert(s.Data.Balance == balance and s.Data.IncomeRemainder == remainder)
	end)
	test("new slot rate does not apply retroactively", function()
		local s = fixture(10000)
		s.IncomeStoppedAt = s.IncomeClock + 1800000
		s.Data.Inventory.a.IncomePerHour = 22000
		assert(s.UpdateIncomeRate()); advance(s, 1800000)
		assert(s.Data.Balance == 16000)
	end)
	test("empty slots do not earn", function()
		local s = fixture(); s.Data.IncomeSlots = {}
		assert(s.UpdateIncomeRate()); advance(s, 3600000)
		assert(s.Data.Balance == 0)
	end)
	test("saved remainder survives new session without offline payment", function()
		local s = fixture(); advance(s, 1000)
		local balance, remainder = s.Data.Balance, s.Data.IncomeRemainder
		local nextSession = {Data = s.Data, LeaseUntil = os.time() + 10000}
		assert(Service.Initialize(nextSession))
		assert(nextSession.Data.Balance == balance and nextSession.Data.IncomeRemainder == remainder)
	end)
	test("unknown operation and expired lease suppress income", function()
		local s = fixture(); s.NeedsRecovery = true; advance(s, 1000)
		assert(s.Data.Balance == 0)
		s.NeedsRecovery = false; s.LeaseUntil = os.time(); advance(s, 1000)
		assert(s.Data.Balance == 0)
	end)
	test("balance cap does not retain overflow", function()
		local s = fixture(); s.Data.Balance = 1000000000000 - 1; advance(s, 10000)
		assert(s.Data.Balance == 1000000000000 and s.Data.IncomeRemainder == 0)
	end)
	test("corrupt fraction is rejected", function()
		local s = fixture(); s.Data.IncomeRemainder = -1
		assert(not Service.Initialize(s))
	end)
	test("duplicate slot ownership is rejected", function()
		local s = fixture(); s.Data.IncomeSlots["2"] = {IssuanceId = "a"}
		assert(not Service.Initialize(s))
	end)
	test("save hook settles once and stopped clock never extends", function()
		local s = fixture(); s.IncomeStoppedAt = s.IncomeClock + 10000
		assert(s.BeforeSave()); local balance = s.Data.Balance
		assert(s.BeforeSave()); assert(s.Data.Balance == balance)
	end)
	return passed
end
