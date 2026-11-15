local NumberRules = {}

function NumberRules.GetRarity(number)
	assert(type(number) == "string" and number:match("^%d%d%d%d%d%d%d$"), "Номер должен быть строкой из семи цифр")
	local digits = {}
	for i = 1, 7 do
		digits[i] = tonumber(number:sub(i, i))
	end
	local run, longestRun = 1, 1
	local ascending, descending, longestSequence = 1, 1, 1
	for i = 2, 7 do
		if digits[i] == digits[i - 1] then run += 1 else run = 1 end
		longestRun = math.max(longestRun, run)
		local difference = digits[i] - digits[i - 1]
		if difference == 1 then ascending += 1 else ascending = 1 end
		if difference == -1 then descending += 1 else descending = 1 end
		longestSequence = math.max(longestSequence, ascending, descending)
	end
	if longestRun == 7 then return 6 end
	local alternating = digits[1] ~= digits[2] and number:sub(1, 5) == number:sub(3, 7)
	if longestRun >= 6 or longestSequence == 7 or alternating then return 5 end
	local fullMirror = number == number:reverse()
	local repeatedBlock = number:sub(2, 4) == number:sub(5, 7)
		and not (digits[2] == digits[3] and digits[3] == digits[4])
	if fullMirror or longestRun >= 5 or repeatedBlock then return 4 end
	local threePairs = digits[2] == digits[3] and digits[4] == digits[5]
		and digits[6] == digits[7] and digits[2] ~= digits[4]
		and digits[2] ~= digits[6] and digits[4] ~= digits[6]
	local alternatingEnding = digits[4] == digits[6] and digits[5] == digits[7] and digits[4] ~= digits[5]
	if longestRun >= 4 or longestSequence >= 5 or threePairs or alternatingEnding then return 3 end
	local ending = number:sub(4, 7)
	if longestRun >= 2 or longestSequence >= 3 or ending == ending:reverse() then return 2 end
	return 1
end

return NumberRules
