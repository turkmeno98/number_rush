local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local storeName = "NR_Profiles_LIVE_v1"
if RunService:IsStudio() then storeName = "NR_Profiles_DEV_v1" end
local store = DataStoreService:GetDataStore(storeName)
local PlayerDataStore = {}
PlayerDataStore.LeaseSeconds = 120

local function createDefaultData()
	return {
		Balance = Config.StartingBalance, Inventory = {}, IncomeSlots = {},
		InventoryCapacity = Config.StartingInventoryCapacity,
		IncomeSlotCount = Config.StartingIncomeSlots,
	}
end

local function validData(data)
	return type(data) == "table" and type(data.Balance) == "number"
		and data.Balance >= 0 and data.Balance <= 1000000000000 and data.Balance % 1 == 0
		and type(data.Inventory) == "table" and type(data.IncomeSlots) == "table"
		and type(data.InventoryCapacity) == "number" and type(data.IncomeSlotCount) == "number"
end

local function copyTable(source)
	local copy = {}
	for key, value in pairs(source) do
		if type(value) == "table" then copy[key] = copyTable(value) else copy[key] = value end
	end
	return copy
end

function PlayerDataStore.Load(userId)
	local key = "Player_" .. tostring(userId)
	local token = HttpService:GenerateGUID(false)
	local failureReason = "Профиль недоступен"
	local success, record = pcall(function()
		return store:UpdateAsync(key, function(oldRecord)
			local now = os.time()
			if oldRecord == nil then
				oldRecord = {SchemaVersion = 1, Data = createDefaultData()}
			end
			if type(oldRecord) ~= "table" or oldRecord.SchemaVersion ~= 1 or not validData(oldRecord.Data) then
				failureReason = "Неизвестный или повреждённый профиль"
				return nil
			end
			local lock = oldRecord.Session
			if lock ~= nil then
				if type(lock) ~= "table" or type(lock.Id) ~= "string" or type(lock.ExpiresAt) ~= "number" then
					failureReason = "Некорректная блокировка профиля"
					return nil
				end
				if lock.Id ~= token and lock.ExpiresAt > now then
					failureReason = "Профиль ещё открыт другим сервером"
					return nil
				end
			end
			oldRecord.Session = {Id = token, ExpiresAt = now + PlayerDataStore.LeaseSeconds}
			oldRecord.UpdatedAt = now
			return oldRecord
		end)
	end)
	if not success then return nil, tostring(record) end
	if type(record) ~= "table" or type(record.Session) ~= "table" or record.Session.Id ~= token then return nil, failureReason end
	return {UserId = userId, Key = key, Token = token, Data = copyTable(record.Data), LeaseUntil = record.Session.ExpiresAt, Busy = false, Closed = false}
end

function PlayerDataStore.Save(session, release)
	if session.Closed then return true end
	if session.Busy then return false, "Сохранение уже выполняется" end
	if not validData(session.Data) then return false, "Некорректные данные для сохранения" end
	if session.BeforeSave then
		local ok, reason = session.BeforeSave()
		if not ok then return false, reason end
	end
	local snapshot = copyTable(session.Data)
	session.Busy = true
	local failureReason = "Блокировка профиля потеряна"
	local success, record = pcall(function()
		return store:UpdateAsync(session.Key, function(oldRecord)
			local now = os.time()
			if type(oldRecord) ~= "table" or oldRecord.SchemaVersion ~= 1 or type(oldRecord.Session) ~= "table" then return nil end
			local lock = oldRecord.Session
			if lock.Id ~= session.Token or type(lock.ExpiresAt) ~= "number" or lock.ExpiresAt <= now then return nil end
			oldRecord.Data = snapshot
			oldRecord.UpdatedAt = now
			if release then
				oldRecord.Session = nil
			else
				oldRecord.Session = {Id = session.Token, ExpiresAt = now + PlayerDataStore.LeaseSeconds}
			end
			return oldRecord
		end)
	end)
	session.Busy = false
	if not success then return false, tostring(record) end
	if type(record) ~= "table" then return false, failureReason end
	if release then session.Closed = true; session.LeaseUntil = 0 else session.LeaseUntil = record.Session.ExpiresAt end
	return true
end

return PlayerDataStore
