local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PlayerDataStore = require(script.Parent:WaitForChild("PlayerDataStore"))
local SpinService = require(script.Parent:WaitForChild("SpinService"))
local remotes = ReplicatedStorage:WaitForChild("NumberRushRemotes")
local spinRequest = remotes:WaitForChild("SpinRequest")
local spinResult = remotes:WaitForChild("SpinResult")
local sessions, loading = {}, {}
local shuttingDown = false

local function send(player, packet)
	if player.Parent == Players then spinResult:FireClient(player, packet) end
end

local function publishInventory(player, session)
	local folder = player:FindFirstChild("NumberInventory")
	if not folder then folder = Instance.new("Folder"); folder.Name = "NumberInventory"; folder.Parent = player end
	folder:ClearAllChildren()
	local count = 0
	for issuanceId, item in pairs(session.Data.Inventory) do
		local entry = Instance.new("Folder")
		entry.Name = tostring(issuanceId)
		for key, value in pairs(item) do
			local valueType = type(value)
			if valueType == "string" or valueType == "number" or valueType == "boolean" then entry:SetAttribute(key, value) end
		end
		entry.Parent = folder
		count += 1
	end
	player:SetAttribute("InventoryCount", count)
	player:SetAttribute("NextSpinSequence", session.Data.NextSpinSequence or 1)
end

local function closeProfile(player)
	local session = sessions[player]
	if not session or session.Closing then return end
	session.Closing = true
	player:SetAttribute("DataReady", false)
	if session.BalanceConnection then session.BalanceConnection:Disconnect() end
	local deadline = os.clock() + 20
	while session.Busy and os.clock() < deadline do task.wait(0.1) end
	local saved, saveError = false, "Не удалось завершить сохранение"
	for attempt = 1, 3 do
		if os.clock() >= deadline then break end
		if not session.Busy then
			saved, saveError = PlayerDataStore.Save(session, true)
			if saved then break end
		end
		task.wait(1)
	end
	if saved then
		print("NUMBER RUSH: профиль сохранён — " .. player.Name)
	else
		warn("NUMBER RUSH: ошибка сохранения — " .. player.Name .. ": " .. tostring(saveError))
	end
	sessions[player] = nil
end

local function stopSession(player, message)
	player:SetAttribute("DataReady", false)
	task.spawn(closeProfile, player)
	if player.Parent == Players then player:Kick(message) end
end

local function setupPlayer(player)
	if sessions[player] or loading[player] or shuttingDown then return end
	loading[player] = true
	player:SetAttribute("DataReady", false)
	local session, loadError = nil, nil
	for attempt = 1, 3 do
		if player.Parent ~= Players or shuttingDown then break end
		session, loadError = PlayerDataStore.Load(player.UserId)
		if session then break end
		if attempt < 3 then task.wait(2) end
	end
	loading[player] = nil
	if not session then
		if player.Parent == Players and not shuttingDown then
			warn("NUMBER RUSH: ошибка загрузки: " .. tostring(loadError))
			player:Kick("Профиль недоступен. Подключитесь немного позже.")
		end
		return
	end
	sessions[player] = session
	session.NextSaveAt = os.clock() + 30
	if player.Parent ~= Players or shuttingDown then closeProfile(player); return end
	if session.Data.NextSpinSequence == nil then session.Data.NextSpinSequence = 1 end
	local recovered, recoveryError, recoveryDetails = SpinService.Recover(session)
	if not recovered then
		warn("NUMBER RUSH: восстановление выдачи: " .. tostring(recoveryDetails or recoveryError))
		stopSession(player, "Не удалось восстановить профиль. Подключитесь немного позже.")
		return
	end
	if player.Parent ~= Players or shuttingDown then closeProfile(player); return end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local rubles = Instance.new("IntValue")
	rubles.Name = "Рубли"
	rubles.Value = session.Data.Balance
	rubles.Parent = leaderstats
	session.BalanceValue = rubles
	player:SetAttribute("InventoryCapacity", session.Data.InventoryCapacity)
	player:SetAttribute("IncomeSlotCount", session.Data.IncomeSlotCount)
	session.BalanceConnection = rubles:GetPropertyChangedSignal("Value"):Connect(function()
		if session.Closing or session.Closed then return end
		local value = rubles.Value
		if value < 0 or value > 1000000000000 then
			rubles.Value = session.Data.Balance
			warn("NUMBER RUSH: отклонён некорректный баланс")
			return
		end
		session.Data.Balance = value
	end)
	publishInventory(player, session)
	leaderstats.Parent = player
	player:SetAttribute("DataReady", true)
	print("NUMBER RUSH: профиль загружен. Баланс: " .. tostring(session.Data.Balance))
end

local messages = {
	InvalidCode = "Выберите доступный код.",
	InvalidSequence = "Обновите выбор и повторите попытку.",
	StaleRequest = "Состояние терминала обновилось. Повторите попытку.",
	Busy = "Прокрутка уже выполняется.", SessionUnavailable = "Профиль временно недоступен.",
	NotEnoughMoney = "Недостаточно рублей.", InventoryFull = "В коллекции нет свободных мест.",
	GenerationFailed = "Не удалось подготовить номер. Повторите попытку.",
	RecoveryRequired = "Для проверки выдачи нужно переподключиться.",
}

local function sendError(player, session, sequence, code)
	send(player, {
		Status = "Error", ErrorCode = code, Sequence = sequence,
		Message = messages[code] or "Не удалось выполнить прокрутку.",
		NextSequence = session and (session.Data.NextSpinSequence or 1) or nil,
		Ready = player:GetAttribute("DataReady") == true,
	})
end

spinRequest.OnServerEvent:Connect(function(player, code, sequence)
	local session = sessions[player]
	if not session or player:GetAttribute("DataReady") ~= true then sendError(player, session, nil, "SessionUnavailable"); return end
	local now = os.clock()
	if session.LastRequestAt and now - session.LastRequestAt < 0.25 then return end
	session.LastRequestAt = now
	if session.RequestBusy or session.SpinBusy then sendError(player, session, nil, "Busy"); return end
	if type(code) ~= "string" or not Config.CodeOffers[code] then sendError(player, session, nil, "InvalidCode"); return end
	if type(sequence) ~= "number" or sequence % 1 ~= 0 or sequence < 1 or sequence > 1000000000 then sendError(player, session, nil, "InvalidSequence"); return end
	local lastSpin = session.Data.LastSpin
	local repeated = lastSpin and lastSpin.Sequence == sequence
	if not repeated then
		if sequence ~= (session.Data.NextSpinSequence or 1) then sendError(player, session, sequence, "StaleRequest"); return end
		local offer = Config.CodeOffers[code]
		local profile = Config.Profiles[offer.ProfileId]
		if session.Data.Balance < profile.Price then sendError(player, session, sequence, "NotEnoughMoney"); return end
		local count = 0
		for _ in pairs(session.Data.Inventory) do count += 1 end
		if count >= session.Data.InventoryCapacity then sendError(player, session, sequence, "InventoryFull"); return end
	end
	session.RequestBusy = true
	if not repeated then send(player, {Status = "Started", Sequence = sequence, Code = code, Duration = Config.SpinDuration}) end
	local receipt, errorCode, details = SpinService.Start(session, code, sequence)
	session.RequestBusy = false
	if not receipt then
		warn("NUMBER RUSH: прокрутка: " .. tostring(errorCode) .. " " .. tostring(details or ""))
		if errorCode == "RecoveryRequired" then
			player:SetAttribute("DataReady", false)
			sendError(player, session, sequence, errorCode)
			stopSession(player, "Профиль временно недоступен. Переподключитесь для проверки выдачи.")
		else
			sendError(player, session, sequence, errorCode)
		end
		return
	end
	if session.Closing or session.Closed or player.Parent ~= Players then return end
	publishInventory(player, session)
	receipt.Balance = session.Data.Balance
	receipt.NextSequence = session.Data.NextSpinSequence or 1
	receipt.InventoryCount = player:GetAttribute("InventoryCount")
	send(player, receipt)
end)

Players.PlayerRemoving:Connect(closeProfile)
Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do task.spawn(setupPlayer, player) end

task.spawn(function()
	while not shuttingDown do
		task.wait(5)
		for player, session in pairs(sessions) do
			if session.Closing or session.Closed then continue end
			if os.time() >= session.LeaseUntil - 15 then
				stopSession(player, "Связь с хранилищем потеряна. Подключитесь немного позже.")
				continue
			end
			if session.SpinBusy or session.RequestBusy then continue end
			if os.clock() >= session.NextSaveAt and not session.Busy then
				session.NextSaveAt = os.clock() + 30
				task.spawn(function()
					if session.Closing or session.Closed or session.SpinBusy or session.RequestBusy then return end
					local saved, saveError = PlayerDataStore.Save(session, false)
					if not saved then warn("NUMBER RUSH: ошибка автосохранения: " .. tostring(saveError)) end
				end)
			end
		end
	end
end)

game:BindToClose(function()
	shuttingDown = true
	for player in pairs(sessions) do task.spawn(closeProfile, player) end
	local deadline = os.clock() + 25
	while os.clock() < deadline do
		if next(sessions) == nil and next(loading) == nil then break end
		task.wait(0.1)
	end
end)
