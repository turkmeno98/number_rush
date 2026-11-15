-- Архив диагностического Script. В рабочей сцене отключён / не подключается сборщиком.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local NumberRules = require(script.Parent:WaitForChild("NumberRules"))
local examples = {
	{"5831946", 1}, {"5831977", 2}, {"5837777", 3}, {"1234321", 4},
	{"7777770", 5}, {"7777777", 6}, {"0123456", 5}, {"1212121", 5},
	{"5123123", 4}, {"4567890", 3},
}
for _, example in examples do
	local actual = NumberRules.GetRarity(example[1])
	assert(actual == example[2], string.format("Ошибка для %s: ожидалась категория %d, получена %s", example[1], example[2], tostring(actual)))
	print(example[1] .. " → " .. Config.Rarities[actual].Name)
end
print("NUMBER RUSH: проверка редкости пройдена — 10 из 10")
local NumberGenerator = require(script.Parent:WaitForChild("NumberGenerator"))
print("NUMBER RUSH: пробная генерация")
for i = 1, 10 do
	local result, generationError = NumberGenerator.Generate("Starter")
	assert(result, generationError)
	assert(NumberRules.GetRarity(result.Digits) == result.RarityIndex, "Категория результата не совпадает с рисунком цифр")
	print(i .. ". " .. result.Digits .. " → " .. result.RarityName)
end
print("NUMBER RUSH: генератор работает")
local NumberEconomy = require(script.Parent:WaitForChild("NumberEconomy"))
local priceExamples = {{"5831946", "900", "Starter", 2089}, {"7777777", "900", "Collector", 80560}, {"9000000", "900", "Collector", 32198}}
for _, example in priceExamples do
	local result = NumberEconomy.Evaluate(example[1], example[2], example[3])
	assert(result.SalePrice == example[4], "Неверная цена для " .. result.DisplayNumber)
	print(string.format("%s | %s | Продажа: %d ₽ | Доход: %d ₽/ч", result.DisplayNumber, result.RarityName, result.SalePrice, result.IncomePerHour))
end
print("NUMBER RUSH: расчёт стоимости работает")
