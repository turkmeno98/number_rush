-- No offline payment: the monotonic clock exists only for this server session.
local OnlineIncomeService = {}
local MILLIS_PER_HOUR = 3600000
local MAX_BALANCE = 1000000000000

local function integer(value, minimum, maximum)
	return type(value) == "number" and value % 1 == 0 and value >= minimum and value <= maximum
end

local function rate(data)
	local total, seen = 0, {}
	for index = 1, data.IncomeSlotCount do
		local slot = data.IncomeSlots[tostring(index)]
		if slot and slot.IssuanceId then
			local id = slot.IssuanceId
			local item = data.Inventory[id]
			if seen[id] or type(item) ~= "table" or item.IssuanceId ~= id
				or item.Location ~= "IncomeSlot" or item.IncomeSlotIndex ~= index
				or not integer(item.IncomePerHour, 0, 1000000000) then
				return nil, "InvalidIncomeItem"
			end
			seen[id] = true
			total = total + item.IncomePerHour
		end
	end
	return total
end

function OnlineIncomeService.Accrue(session)
	if not session.IncomeClock or session.Closed or session.NeedsRecovery then return true end
	if os.time() >= session.LeaseUntil - 10 then return true end
	local data = session.Data
	if not integer(data.IncomeRemainder, 0, MILLIS_PER_HOUR - 1)
		or not integer(data.Balance, 0, MAX_BALANCE) then return false, "InvalidIncomeBalance" end
	local now = session.IncomeStoppedAt or math.floor(os.clock() * 1000)
	local elapsed = now - session.IncomeClock
	if elapsed <= 0 then return true end
	-- The lease bounds normal elapsed time; reject corrupt clock state instead of overpaying.
	if elapsed > 3600000 then return false, "InvalidIncomeClock" end
	local numerator = data.IncomeRemainder + session.IncomeRate * elapsed
	if numerator > 9007199254740991 then return false, "IncomePrecisionLimit" end
	local earned = math.floor(numerator / MILLIS_PER_HOUR)
	data.IncomeRemainder = numerator % MILLIS_PER_HOUR
	data.Balance = math.min(MAX_BALANCE, data.Balance + earned)
	if data.Balance == MAX_BALANCE then data.IncomeRemainder = 0 end
	session.IncomeClock = now
	if session.BalanceValue then session.BalanceValue.Value = data.Balance end
	return true
end

function OnlineIncomeService.Initialize(session)
	local remainder = session.Data.IncomeRemainder
	if remainder ~= nil and not integer(remainder, 0, MILLIS_PER_HOUR - 1) then
		return false, "InvalidIncomeRemainder"
	end
	local currentRate, reason = rate(session.Data)
	if not currentRate then return false, reason end
	session.Data.IncomeRemainder = remainder or 0
	session.IncomeClock = math.floor(os.clock() * 1000)
	session.IncomeRate = currentRate
	session.BeforeSave = function() return OnlineIncomeService.Accrue(session) end
	session.UpdateIncomeRate = function()
		local ok, errorCode = OnlineIncomeService.Accrue(session)
		if not ok then return false, errorCode end
		local updatedRate, rateError = rate(session.Data)
		if not updatedRate then return false, rateError end
		session.IncomeRate = updatedRate
		return true
	end
	return true
end

function OnlineIncomeService.Stop(session)
	-- Do not pay for waiting on saves after PlayerRemoving.
	session.IncomeStoppedAt = math.floor(os.clock() * 1000)
end

return OnlineIncomeService
