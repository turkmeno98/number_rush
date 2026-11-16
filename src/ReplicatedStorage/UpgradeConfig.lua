-- Shared presentation and deterministic rules. Purchases are server-authoritative.
local Upgrades = {}
Upgrades.Order = {"Storage", "Slots", "Luck", "Speed", "Auto"}
Upgrades.Branches = {
	Storage = {Name = "SIM-хранилище", Icon = "collection", Prices = {10000, 35000, 75000, 150000}, Values = {25, 50, 100, 150, 200}},
	Slots = {Name = "Доходные линии", Icon = "terminal", Prices = {170000, 450000}, Values = {3, 4, 5}},
	Luck = {Name = "Удача", Icon = "upgrades", Prices = {10000, 20000, 40000, 80000, 160000}},
	Speed = {Name = "Скорость станции", Icon = "settings", Prices = {10000, 25000, 50000, 100000}},
	Auto = {Name = "Автопрокрутка", Icon = "terminal", Prices = {25000}},
}
function Upgrades.Level(data, key)
	return data.Upgrades and data.Upgrades[key] or 0
end
function Upgrades.Weights(base, level)
	local weights, total = {}, 0
	for i, weight in ipairs(base) do
		weights[i] = weight * (i == 1 and 100 or (100 + 3 * level))
		total += weights[i]
	end
	return weights, total
end
function Upgrades.Duration(base, level)
	return math.max(4, base / (1 + 0.05 * level))
end
function Upgrades.Description(key, level)
	local branch = Upgrades.Branches[key]
	if key == "Storage" then return tostring(branch.Values[level + 1]) .. " мест для номеров" end
	if key == "Slots" then return tostring(branch.Values[level + 1]) .. " доходных слотов" end
	if key == "Luck" then return string.format("Удача ×%.2f", 1 + 0.03 * level) end
	if key == "Speed" then return string.format("Выдача за %.2f сек.", Upgrades.Duration(6, level)) end
	return level > 0 and "Автопрокрутка открыта" or "Ручная выдача"
end
return Upgrades
