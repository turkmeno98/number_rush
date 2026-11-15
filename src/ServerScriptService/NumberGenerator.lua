local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local NumberRules = require(script.Parent:WaitForChild("NumberRules"))
local NumberGenerator = {}
local random = Random.new()
local legendaryNumbers = nil

local function getLegendaryNumbers()
	if legendaryNumbers then return legendaryNumbers end
	local list, seen = {}, {}
	local function add(number)
		if not seen[number] and NumberRules.GetRarity(number) == 5 then
			seen[number] = true
			table.insert(list, number)
		end
	end
	for digit = 0, 9 do
		local repeated = string.rep(tostring(digit), 6)
		for other = 0, 9 do
			add(repeated .. tostring(other))
			add(tostring(other) .. repeated)
		end
	end
	for first = 0, 9 do
		for second = 0, 9 do
			if first ~= second then
				local a, b = tostring(first), tostring(second)
				add(a .. b .. a .. b .. a .. b .. a)
			end
		end
	end
	for start = 0, 3 do
		local ascending, descending = "", ""
		for offset = 0, 6 do
			ascending ..= tostring(start + offset)
			descending ..= tostring(start + 6 - offset)
		end
		add(ascending)
		add(descending)
	end
	assert(#list == 278, "Ошибка: ожидалось 278 легендарных комбинаций")
	legendaryNumbers = list
	return list
end

function NumberGenerator.RollRarity(profileId)
	local profile = Config.Profiles[profileId]
	assert(profile, "Неизвестный профиль прокрутки")
	local totalWeight = 0
	for _, weight in profile.Weights do
		assert(type(weight) == "number" and weight >= 0 and weight % 1 == 0, "Вес категории должен быть целым неотрицательным числом")
		totalWeight += weight
	end
	assert(totalWeight == 10000000, "Сумма весов профиля должна быть 10 миллионов")
	local roll = random:NextInteger(1, totalWeight)
	local accumulated = 0
	for rarityIndex, weight in profile.Weights do
		accumulated += weight
		if roll <= accumulated then return rarityIndex end
	end
	error("Не удалось выбрать категорию")
end

function NumberGenerator.GenerateDigits(rarityIndex)
	assert(type(rarityIndex) == "number" and rarityIndex % 1 == 0 and rarityIndex >= 1 and rarityIndex <= #Config.Rarities, "Некорректный индекс категории")
	if rarityIndex == 6 then return string.rep(tostring(random:NextInteger(0, 9)), 7) end
	if rarityIndex == 5 then
		local list = getLegendaryNumbers()
		return list[random:NextInteger(1, #list)]
	end
	for attempt = 1, 10000 do
		local number = string.format("%07d", random:NextInteger(0, 9999999))
		if NumberRules.GetRarity(number) == rarityIndex then return number end
		if attempt % 250 == 0 then task.wait() end
	end
	return nil, "Не удалось подобрать комбинацию"
end

function NumberGenerator.Generate(profileId)
	local rarityIndex = NumberGenerator.RollRarity(profileId)
	local digits, generationError = NumberGenerator.GenerateDigits(rarityIndex)
	if not digits then return nil, generationError end
	return {Digits = digits, RarityIndex = rarityIndex, RarityName = Config.Rarities[rarityIndex].Name, ProfileId = profileId}
end

return NumberGenerator
