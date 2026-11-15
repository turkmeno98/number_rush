-- ОПАСЕН для текущего баланса: выставляет 90000. Архив, не входит в рабочую сборку.
-- В пользовательской Studio отключён перед повторной проверкой сохранения.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local handled = {}
local function changeTestBalance(player)
	if handled[player] then return end
	handled[player] = true
	local stats = player:WaitForChild("leaderstats", 30)
	if not stats then warn("Проверка: показатели игрока не загрузились"); return end
	local rubles = stats:WaitForChild("Рубли", 5)
	if not rubles then warn("Проверка: баланс не найден"); return end
	rubles.Value = 90000
	task.wait(1)
	print("Проверка: баланс изменён на 90000")
end
Players.PlayerAdded:Connect(changeTestBalance)
for _, player in Players:GetPlayers() do task.spawn(changeTestBalance, player) end
