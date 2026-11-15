-- Slot requests only; ownership, cooldowns and persistence are checked by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("NumberRushUI", 30)
if not gui then return end
if gui:GetAttribute("InterfaceVersion") == 2 then return end -- DesktopUI owns the new slot view.
local collection = gui:WaitForChild("CollectionPanel", 30)
if not collection then return end
local entries = collection:WaitForChild("Entries", 15)
local remotes = ReplicatedStorage:WaitForChild("NumberRushRemotes", 15)
local request = remotes and remotes:WaitForChild("SlotRequest", 15)
local response = remotes and remotes:WaitForChild("SlotResult", 15)
if not entries or not request or not response then warn("NUMBER RUSH: интерфейс слотов недоступен"); return end

local function text(parent, name, value, position, size, z)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = value
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arial
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(25, 40, 65)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.ZIndex = z
	label.Parent = parent
	return label
end

local function button(parent, name, value, position, size, z)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = value
	b.Position = position
	b.Size = size
	b.Font = Enum.Font.Arial
	b.TextSize = 15
	b.BackgroundColor3 = Color3.fromRGB(235, 235, 225)
	b.BorderColor3 = Color3.fromRGB(130, 130, 120)
	b.TextColor3 = Color3.fromRGB(25, 40, 65)
	b.ZIndex = z
	b.Parent = parent
	return b
end

local panel = Instance.new("Frame")
panel.Name = "IncomeSlotPanel"
panel.AnchorPoint = collection.AnchorPoint
panel.Position = collection.Position
panel.Size = collection.Size
panel.BackgroundColor3 = Color3.fromRGB(236, 233, 216)
panel.BorderColor3 = Color3.fromRGB(0, 60, 170)
panel.BorderSizePixel = 3
panel.Active = true
panel.Visible = false
panel.ZIndex = 30
panel.Parent = gui
for _, property in {"Position", "Size", "AnchorPoint"} do
	collection:GetPropertyChangedSignal(property):Connect(function() panel[property] = collection[property] end)
end
local header = Instance.new("Frame")
header.Name = "TitleBar"
header.Size = UDim2.new(1, 0, 0, 34)
header.BackgroundColor3 = Color3.fromRGB(0, 84, 227)
header.BorderSizePixel = 0
header.ZIndex = 31
header.Parent = panel
local title = text(header, "Title", "NUMBER RUSH — Доходные слоты", UDim2.fromOffset(12, 0), UDim2.new(1, -60, 1, 0), 32)
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.ArialBold
local close = button(header, "Close", "X", UDim2.new(1, -34, 0, 4), UDim2.fromOffset(28, 26), 33)
close.BackgroundColor3 = Color3.fromRGB(210, 70, 50)
close.TextColor3 = Color3.new(1, 1, 1)
local selection = text(panel, "Selection", "Выберите номер в коллекции для установки.", UDim2.fromOffset(24, 44), UDim2.new(1, -48, 0, 42), 31)
local rows = Instance.new("ScrollingFrame")
rows.Name = "Slots"
rows.Position = UDim2.fromOffset(24, 96)
rows.Size = UDim2.new(1, -48, 1, -218)
rows.BackgroundTransparency = 1
rows.BorderSizePixel = 0
rows.ScrollBarThickness = 6
rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
rows.CanvasSize = UDim2.fromOffset(0, 0)
rows.ZIndex = 31
rows.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = rows
local notice = text(panel, "Notice", "Онлайн-доход начисляется автоматически. Замена — раз в 60 минут. Последний занятый слот снять нельзя.", UDim2.new(0, 24, 1, -116), UDim2.new(1, -48, 0, 40), 31)
local status = text(panel, "Status", "", UDim2.new(0, 24, 1, -70), UDim2.new(1, -196, 0, 60), 31)
local refresh = button(panel, "Refresh", "Обновить", UDim2.new(1, -156, 1, -58), UDim2.fromOffset(132, 32), 32)
local open = button(collection, "IncomeSlotsButton", "Доходные слоты", UDim2.new(1, -196, 0, 48), UDim2.fromOffset(172, 30), 25)

local state, selectedId = nil, nil
local busy, uncertain = false, false
local requestSerial = 0
local stateReceivedAt = 0
local timers = {}
local render, send

local function selectedItem()
	local inventory = player:FindFirstChild("NumberInventory")
	return inventory and selectedId and inventory:FindFirstChild(selectedId)
end

render = function()
	if not panel.Visible then return end
	table.clear(timers)
	for _, child in rows:GetChildren() do if child:IsA("Frame") then child:Destroy() end end
	local item = selectedItem()
	selection.Text = item and ("Выбрано: " .. (item:GetAttribute("DisplayNumber") or "номер")) or "Выберите номер в коллекции для установки."
	local ready = player:GetAttribute("DataReady") == true
	refresh.Interactable = ready and not busy
	if not state then return end
	notice.Text = state.IncomeEnabled and "Онлайн-доход начисляется автоматически. Замена — раз в 60 минут. Последний занятый слот снять нельзя." or "Начисление временно недоступно. Нажмите «Обновить»."
	for _, slot in ipairs(state.Slots) do
		local row = Instance.new("Frame")
		row.Name = "Slot" .. slot.SlotIndex
		row.Size = UDim2.new(1, -10, 0, 94)
		row.LayoutOrder = slot.SlotIndex
		row.BackgroundColor3 = Color3.fromRGB(255, 255, 250)
		row.BorderColor3 = Color3.fromRGB(180, 180, 165)
		row.ZIndex = 32
		row.Parent = rows
		local remaining = math.max(0, (slot.NextChangeAt or 0) - state.ServerTime - (os.clock() - stateReceivedAt))
		local description = string.format("Слот %d: %s", slot.SlotIndex, slot.DisplayNumber or "пусто")
		text(row, "Number", description, UDim2.fromOffset(10, 4), UDim2.new(1, -20, 0, 26), 33)
		local detail = remaining > 0 and ("Замена через " .. math.ceil(remaining / 60) .. " мин.") or "Можно установить номер"
		if slot.IssuanceId then detail = tostring(slot.IncomePerHour) .. " ₽/ч · " .. detail end
		local details = text(row, "Details", detail, UDim2.fromOffset(10, 31), UDim2.new(1, -20, 0, 22), 33)
		local install = button(row, "Install", slot.IssuanceId and "Заменить выбранным" or "Установить выбранный", UDim2.fromOffset(10, 59), UDim2.fromOffset(238, 28), 34)
		install.Interactable = ready and not busy and not uncertain and item ~= nil and item:GetAttribute("Location") == "Inventory" and remaining <= 0
		table.insert(timers, function()
			local left = math.max(0, (slot.NextChangeAt or 0) - state.ServerTime - (os.clock() - stateReceivedAt))
			local value = left > 0 and ("Замена через " .. math.ceil(left / 60) .. " мин.") or "Можно установить номер"
			if slot.IssuanceId then value = tostring(slot.IncomePerHour) .. " ₽/ч · " .. value end
			details.Text = value
			install.Interactable = player:GetAttribute("DataReady") == true and not busy and not uncertain and item ~= nil and item.Parent ~= nil and item:GetAttribute("Location") == "Inventory" and left <= 0
		end)
		install.Activated:Connect(function() if install.Interactable then send("Install", slot.SlotIndex, selectedId) end end)
		local remove = button(row, "Remove", "Снять", UDim2.new(1, -108, 0, 59), UDim2.fromOffset(96, 28), 34)
		remove.Interactable = ready and not busy and not uncertain and slot.IssuanceId ~= nil and state.ActiveCount > 1
		remove.Activated:Connect(function() if remove.Interactable then send("Remove", slot.SlotIndex) end end)
	end
end

send = function(action, index, id)
	if busy or player:GetAttribute("DataReady") ~= true then return end
	if action ~= "GetState" and (uncertain or not state) then return end
	busy = true
	requestSerial += 1
	local serial = requestSerial
	status.Text = action == "GetState" and "Загрузка слотов..." or "Сохраняем назначение..."
	render()
	request:FireServer(action, index, id, state and state.Revision)
	task.delay(20, function()
		if busy and serial == requestSerial then
			busy = false
			uncertain = true
			status.Text = "Ответ задерживается. Нажмите «Обновить» для проверки."
			render()
		end
	end)
end

response.OnClientEvent:Connect(function(packet)
	if type(packet) ~= "table" then return end
	busy = false
	requestSerial += 1
	if type(packet.State) == "table" and (not state or packet.State.Revision >= state.Revision) then
		state = packet.State
		stateReceivedAt = os.clock()
		uncertain = false
	end
	if packet.Status == "Error" then
		status.Text = packet.Message or "Не удалось изменить слот."
		if packet.ErrorCode == "RecoveryRequired" then uncertain = true end
	elseif packet.Status == "Success" then
		status.Text = "Назначение сохранено."
	else
		status.Text = packet.State and packet.State.IncomeEnabled and ("Онлайн-доход: " .. tostring(packet.State.TotalBaseIncomePerHour) .. " ₽/ч") or "Состояние слотов обновлено."
	end
	render()
end)

local function show(id)
	selectedId = id
	panel.Visible = true
	render()
	send("GetState")
end

local function decorate(card)
	if not card:IsA("Frame") or card:FindFirstChild("ChooseIncomeSlot") then return end
	card.Size = UDim2.new(1, -24, 0, 146)
	local choose = button(card, "ChooseIncomeSlot", "Выбрать доходный слот", UDim2.fromOffset(12, 106), UDim2.new(1, -24, 0, 28), 24)
	choose.Activated:Connect(function() show(card.Name) end)
end
entries.ChildAdded:Connect(function(card) task.defer(decorate, card) end)
for _, card in entries:GetChildren() do decorate(card) end
open.Activated:Connect(function() show(nil) end)
close.Activated:Connect(function() panel.Visible = false end)
refresh.Activated:Connect(function() send("GetState") end)
player:GetAttributeChangedSignal("DataReady"):Connect(render)
task.spawn(function()
	while gui.Parent do
		task.wait(1)
		if panel.Visible then for _, update in timers do update() end end
	end
end)
