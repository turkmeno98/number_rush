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

return Config
