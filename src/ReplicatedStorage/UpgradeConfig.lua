-- Shared presentation and deterministic rules. Purchases are server-authoritative.
local Upgrades = {}
Upgrades.Order = {"Storage", "Slots", "Luck", "Speed", "Auto"}
Upgrades.Branches = {
	Storage = {Name = "Коллекционер · SIM-хранилище", Icon = "collection", Prices = {3000,7000,10000,15000,20000,30000,40000,60000,85000}, Values = {25,35,50,65,80,100,125,150,175,200}},
	Slots = {Name = "Доходные линии", Icon = "terminal", Prices = {170000, 450000}, Values = {3, 4, 5}},
	Luck = {Name = "Коллекционер · удача", Icon = "upgrades", Prices = {3000,5000,8000,12000,18000,25000,35000,48000,65000,91000}},
	Speed = {Name = "Оператор · скорость", Icon = "settings", Prices = {3000,7000,10000,15000,20000,30000,40000,60000}},
	Auto = {Name = "Автопрокрутка", Icon = "terminal", Prices = {25000}},
}
function Upgrades.Level(data, key)
	return data.Upgrades and data.Upgrades[key] or 0
end
function Upgrades.Weights(base, level)
	local weights, total = {}, 0
	for i, weight in ipairs(base) do
		weights[i] = weight * (i == 1 and 200 or (200 + 3 * level))
		total += weights[i]
	end
	return weights, total
end
function Upgrades.Duration(base, level)
	return math.max(4, base / (1 + 0.025 * level))
end
function Upgrades.Description(key, level)
	local branch = Upgrades.Branches[key]
	if key == "Storage" then return tostring(branch.Values[level + 1]) .. " мест для номеров" end
	if key == "Slots" then return tostring(branch.Values[level + 1]) .. " доходных слотов" end
	if key == "Luck" then return string.format("Удача ×%.3f", 1 + 0.015 * level) end
	if key == "Speed" then return string.format("Выдача за %.2f сек.", Upgrades.Duration(6, level)) end
	return level > 0 and "Автопрокрутка открыта" or "Ручная выдача"
end
function Upgrades.Requirement(levels, key)
	if key == "Auto" and (levels.Speed or 0) < 2 then return "Нужна скорость II" end
	if key == "Slots" then
		local level = levels.Slots or 0
		if level == 0 and (levels.Storage or 0) < 2 then return "Нужно хранилище на 50 мест" end
		if level == 1 and ((levels.Storage or 0) < 5 or (levels.Luck or 0) < 4) then return "Нужны 100 мест и удача IV" end
	end
	return nil
end
return Upgrades
