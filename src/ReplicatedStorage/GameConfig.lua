local Config = {}

Config.StartingBalance = 100000
Config.StartingInventoryCapacity = 25
Config.StartingIncomeSlots = 3
Config.SpinDuration = 6

Config.Rarities = {
	{Name = "Обычный", BasePrice = 1500, IncomePerHour = 10000},
	{Name = "Необычный", BasePrice = 1800, IncomePerHour = 11000},
	{Name = "Редкий", BasePrice = 3000, IncomePerHour = 12500},
	{Name = "Эпический", BasePrice = 6000, IncomePerHour = 15000},
	{Name = "Легендарный", BasePrice = 15000, IncomePerHour = 18000},
	{Name = "Исключительный", BasePrice = 40000, IncomePerHour = 22000},
}

Config.Profiles = {
	Starter = {
		Name = "Стартовый", Price = 5000, Prestige = 1.00,
		Weights = {5500000, 4300000, 185000, 14900, 99, 1},
	},
	Improved = {
		Name = "Улучшенный", Price = 15000, Prestige = 1.03,
		Weights = {0, 9400000, 580000, 19900, 99, 1},
	},
	Collector = {
		Name = "Коллекционный", Price = 50000, Prestige = 1.06,
		Weights = {0, 0, 9700000, 297000, 2970, 30},
	},
}

-- Сотые доли коэффициента: 200 = x2.00.
Config.DigitValues = {
	["0"] = 200, ["7"] = 190, ["8"] = 180, ["1"] = 165,
	["9"] = 150, ["5"] = 140, ["3"] = 130, ["2"] = 120,
	["6"] = 110, ["4"] = 100,
}
Config.CodeMatchPercent = 5

-- Игровая привязка регионов, не реальная таблица диапазонов связи.
Config.Operators = {
	{Id = "beelink", Name = "БиЛайнк", Codes = {
		{Code = "903", Region = "Москва", ProfileId = "Starter"},
		{Code = "905", Region = "Санкт-Петербург", ProfileId = "Improved"},
		{Code = "909", Region = "Казань", ProfileId = "Collector"},
	}},
	{Id = "mobitel", Name = "Мобител", Codes = {
		{Code = "910", Region = "Москва", ProfileId = "Starter"},
		{Code = "915", Region = "Санкт-Петербург", ProfileId = "Improved"},
		{Code = "919", Region = "Казань", ProfileId = "Collector"},
	}},
	{Id = "megalink", Name = "МегаЛинк", Codes = {
		{Code = "920", Region = "Москва", ProfileId = "Starter"},
		{Code = "925", Region = "Санкт-Петербург", ProfileId = "Improved"},
		{Code = "929", Region = "Казань", ProfileId = "Collector"},
	}},
	{Id = "telenova", Name = "ТелеНова", Codes = {
		{Code = "900", Region = "Москва", ProfileId = "Starter"},
		{Code = "904", Region = "Санкт-Петербург", ProfileId = "Improved"},
		{Code = "951", Region = "Казань", ProfileId = "Collector"},
	}},
}

Config.CodeOffers = {}
for _, operator in Config.Operators do
	for _, offer in operator.Codes do
		assert(type(offer.Code) == "string" and offer.Code:match("^9%d%d$"), "Некорректный код в GameConfig")
		assert(Config.CodeOffers[offer.Code] == nil, "Повторяющийся код: " .. offer.Code)
		assert(Config.Profiles[offer.ProfileId] ~= nil, "Неизвестный профиль у кода " .. offer.Code)
		Config.CodeOffers[offer.Code] = {
			Code = offer.Code, Region = offer.Region,
			OperatorId = operator.Id, OperatorName = operator.Name,
			ProfileId = offer.ProfileId,
		}
	end
end

-- Legacy profiles/offers above are retained only for existing items and PendingSpin recovery.
Config.EconomyVersion = 3
Config.Profiles.Regional = {Name = "Региональная выдача", Price = 5000, Prestige = 1.00,
	Weights = {6000000, 3000000, 880000, 110000, 9900, 100}}
Config.Operators = {
	{Id = "beelink", Name = "БиЛайнк", ThemeColor = Color3.fromRGB(245, 193, 34), TextColor = Color3.fromRGB(33, 32, 27)},
	{Id = "mobitel", Name = "Мобител", ThemeColor = Color3.fromRGB(213, 45, 61), TextColor = Color3.new(1, 1, 1)},
	{Id = "megalink", Name = "МегаЛинк", ThemeColor = Color3.fromRGB(22, 144, 98), TextColor = Color3.new(1, 1, 1)},
	{Id = "telenova", Name = "ТелеНова", ThemeColor = Color3.fromRGB(35, 40, 52), TextColor = Color3.new(1, 1, 1)},
}
Config.OperatorById, Config.RegionsById = {}, {}
for _, operator in ipairs(Config.Operators) do Config.OperatorById[operator.Id] = operator end
local Catalog = require(script.Parent:WaitForChild("RegionCatalog"))
Config.CatalogDate = Catalog.SnapshotDate
for _, region in ipairs(Catalog.Regions) do Config.RegionsById[region.Id] = region end

function Config.ResolveRegion(operatorId, regionId)
	local operator, region = Config.OperatorById[operatorId], Config.RegionsById[regionId]
	if not operator or not region or not region.Codes[operatorId] or #region.Codes[operatorId] == 0 then return nil end
	return {Id = region.Id, Region = region.Name, Name = region.Name, Price = region.Price,
		Kind = region.Kind, Codes = region.Codes[operatorId], OperatorId = operatorId, OperatorName = operator.Name, ProfileId = "Regional"}
end

function Config.GetRegionOffers(operatorId)
	local result = {}
	for _, region in ipairs(Catalog.Regions) do
		local offer = Config.ResolveRegion(operatorId, region.Id)
		if offer then table.insert(result, offer) end
	end
	return result
end

function Config.GetDefaultOffer(operatorId)
	local offers = Config.GetRegionOffers(operatorId)
	for _, offer in ipairs(offers) do if offer.Region == "Московская область" then return offer end end
	return offers[1]
end

return Config
