-- ОТКЛЮЧЁН после проверки. Не входит в рабочую сборку.
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
if not RunService:IsStudio() then return end
local testStore = DataStoreService:GetDataStore("NR_ConnectionCheck_v1")
local success, result = pcall(function()
	return testStore:UpdateAsync("CheckCounter", function(oldValue)
		local counter = 0
		if type(oldValue) == "number" then counter = oldValue end
		return counter + 1
	end)
end)
if success then print("NUMBER RUSH: хранилище доступно. Проверка №" .. tostring(result))
else warn("NUMBER RUSH: ошибка доступа к хранилищу: " .. tostring(result)) end
