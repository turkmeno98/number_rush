local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local NumberRules = require(script.Parent:WaitForChild("NumberRules"))
local NumberEconomy = {}

function NumberEconomy.Evaluate(digits, code, profileId)
	assert(type(code) == "string" and code:match("^9%d%d$"), "Код должен быть строкой из трёх цифр, начиная с 9")
	local profile = Config.Profiles[profileId]
	assert(profile, "Неизвестный профиль прокрутки")
	local rarityIndex = NumberRules.GetRarity(digits)
	local rarity = Config.Rarities[rarityIndex]
	local digitTotal = 0
	for i = 1, 7 do digitTotal += Config.DigitValues[digits:sub(i, i)] end
	local hasCodeMatch = digits:sub(1, 3) == code or digits:sub(5, 7) == code
	local matchPoints = 100
	if hasCodeMatch then matchPoints += Config.CodeMatchPercent end
	local prestigePoints = math.floor(profile.Prestige * 100 + 0.5)
	local numerator = rarity.BasePrice * digitTotal * prestigePoints * matchPoints
	local denominator = 7 * 100 * 100 * 100
	local salePrice = math.floor((numerator + denominator / 2) / denominator)
	return {
		FullNumber = "7" .. code .. digits,
		DisplayNumber = string.format("+7 (%s) %s-%s-%s", code, digits:sub(1, 3), digits:sub(4, 5), digits:sub(6, 7)),
		RarityIndex = rarityIndex, RarityName = rarity.Name,
		BasePrice = rarity.BasePrice, SalePrice = salePrice, IncomePerHour = rarity.IncomePerHour,
		DigitMultiplier = digitTotal / 700, PrestigeMultiplier = prestigePoints / 100,
		CodeMatchMultiplier = matchPoints / 100, HasCodeMatch = hasCodeMatch,
	}
end

return NumberEconomy
