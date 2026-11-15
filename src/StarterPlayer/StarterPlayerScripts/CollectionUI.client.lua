-- Read-only collection view. Ownership and money remain server-authoritative.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("NumberRushUI", 30)
if not gui then warn("NUMBER RUSH: окно терминала не найдено"); return end
local window = gui:WaitForChild("Window", 15)
if not window then warn("NUMBER RUSH: Window не найден"); return end
if window:FindFirstChild("CollectionButton") then return end

local function money(value)
	local reversed = string.format("%.0f", tonumber(value) or 0):reverse()
	return (reversed:gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""))
end

local function label(parent, name, text, position, size, fontSize, z)
	local result = Instance.new("TextLabel")
	result.Name = name
	result.Text = text
	result.Position = position
	result.Size = size
	result.BackgroundTransparency = 1
	result.Font = Enum.Font.Arial
	result.TextSize = fontSize
	result.TextColor3 = Color3.fromRGB(30, 30, 30)
	result.TextXAlignment = Enum.TextXAlignment.Left
	result.ZIndex = z
	result.Parent = parent
	return result
end

local function button(parent, name, text, position, size, z)
	local result = Instance.new("TextButton")
	result.Name = name
	result.Text = text
	result.Position = position
	result.Size = size
	result.Font = Enum.Font.Arial
	result.TextSize = 16
	result.BackgroundColor3 = Color3.fromRGB(235, 235, 225)
	result.BorderColor3 = Color3.fromRGB(130, 130, 120)
	result.TextColor3 = Color3.fromRGB(25, 40, 65)
	result.ZIndex = z
	result.Parent = parent
	return result
end

local openButton = button(window, "CollectionButton", "Коллекция", UDim2.new(1, -196, 0, 52), UDim2.fromOffset(172, 30), 3)
openButton.Active = false
openButton.Interactable = false

local panel = Instance.new("Frame")
panel.Name = "CollectionPanel"
panel.AnchorPoint = window.AnchorPoint
panel.Position = window.Position
panel.Size = window.Size
panel.BackgroundColor3 = Color3.fromRGB(236, 233, 216)
panel.BorderColor3 = Color3.fromRGB(0, 60, 170)
panel.BorderSizePixel = 3
panel.Active = true
panel.Visible = false
panel.ZIndex = 20
panel.Parent = gui

-- Follow the existing terminal geometry without changing its chosen size.
window:GetPropertyChangedSignal("Size"):Connect(function() panel.Size = window.Size end)
window:GetPropertyChangedSignal("Position"):Connect(function() panel.Position = window.Position end)
window:GetPropertyChangedSignal("AnchorPoint"):Connect(function() panel.AnchorPoint = window.AnchorPoint end)

local header = Instance.new("Frame")
header.Name = "TitleBar"
header.Size = UDim2.new(1, 0, 0, 34)
header.BackgroundColor3 = Color3.fromRGB(0, 84, 227)
header.BorderSizePixel = 0
header.ZIndex = 21
header.Parent = panel
local title = label(header, "Title", "NUMBER RUSH — Коллекция", UDim2.fromOffset(12, 0), UDim2.new(1, -60, 1, 0), 18, 22)
title.Font = Enum.Font.ArialBold
title.TextColor3 = Color3.new(1, 1, 1)
local closeButton = button(header, "Close", "X", UDim2.new(1, -34, 0, 4), UDim2.fromOffset(28, 26), 23)
closeButton.BackgroundColor3 = Color3.fromRGB(210, 70, 50)
closeButton.TextColor3 = Color3.new(1, 1, 1)
local countLabel = label(panel, "Count", "Коллекция", UDim2.fromOffset(24, 48), UDim2.new(1, -48, 0, 30), 22, 21)
countLabel.Font = Enum.Font.ArialBold

local search = Instance.new("TextBox")
search.Name = "Search"
search.Position = UDim2.fromOffset(24, 88)
search.Size = UDim2.fromOffset(360, 32)
search.BackgroundColor3 = Color3.fromRGB(255, 255, 250)
search.BorderColor3 = Color3.fromRGB(150, 150, 140)
search.Font = Enum.Font.Arial
search.TextSize = 16
search.Text = ""
search.PlaceholderText = "Поиск по цифрам номера"
search.ClearTextOnFocus = false
search.ZIndex = 21
search.Parent = panel
local rarityButton = button(panel, "RarityFilter", "Все редкости", UDim2.fromOffset(396, 88), UDim2.fromOffset(200, 32), 21)

local list = Instance.new("ScrollingFrame")
list.Name = "Entries"
list.Position = UDim2.fromOffset(24, 136)
list.Size = UDim2.new(1, -48, 1, -180)
list.BackgroundColor3 = Color3.fromRGB(248, 247, 237)
list.BorderColor3 = Color3.fromRGB(150, 150, 140)
list.ScrollBarThickness = 8
list.CanvasSize = UDim2.fromOffset(0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.ZIndex = 21
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = list
local emptyLabel = label(panel, "Empty", "В коллекции пока нет номеров.", UDim2.fromOffset(40, 180), UDim2.new(1, -80, 0, 90), 18, 24)
emptyLabel.TextWrapped = true
emptyLabel.TextXAlignment = Enum.TextXAlignment.Center
emptyLabel.Visible = false
local footer = label(panel, "Footer", "", UDim2.new(0, 24, 1, -32), UDim2.new(1, -48, 0, 24), 14, 21)

local colors = {
	Color3.fromRGB(95, 95, 95), Color3.fromRGB(30, 125, 65),
	Color3.fromRGB(30, 85, 180), Color3.fromRGB(125, 55, 175),
	Color3.fromRGB(175, 100, 0), Color3.fromRGB(180, 40, 65),
}
local inventory = nil
local rarityFilter = 0
local folderConnections = {}
local itemConnections = {}
local renderScheduled = false

local function render()
	local items = {}
	if inventory then
		for _, entry in inventory:GetChildren() do
			if entry:IsA("Folder") and type(entry:GetAttribute("FullNumber")) == "string" then
				table.insert(items, entry)
			end
		end
	end
	table.sort(items, function(a, b)
		local at = a:GetAttribute("AcquiredAt") or 0
		local bt = b:GetAttribute("AcquiredAt") or 0
		if at ~= bt then return at > bt end
		return a.Name < b.Name
	end)
	local capacity = player:GetAttribute("InventoryCapacity") or Config.StartingInventoryCapacity
	openButton.Text = string.format("Коллекция %d/%d", #items, capacity)
	local ready = inventory ~= nil and player:GetAttribute("DataReady") == true
	openButton.Active = ready
	openButton.Interactable = ready
	countLabel.Text = string.format("Мои номера: %d/%d", #items, capacity)
	if not panel.Visible then return end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end
	local query = search.Text:gsub("%D", "")
	local shown = 0
	for _, entry in items do
		local fullNumber = entry:GetAttribute("FullNumber")
		local rarityIndex = entry:GetAttribute("RarityIndex") or 1
		if (rarityFilter == 0 or rarityFilter == rarityIndex)
			and (query == "" or string.find(fullNumber, query, 1, true))
		then
			shown += 1
			local card = Instance.new("Frame")
			card.Name = entry.Name
			card.Size = UDim2.new(1, -24, 0, 108)
			card.LayoutOrder = shown
			card.BackgroundColor3 = Color3.fromRGB(255, 255, 250)
			card.BorderColor3 = Color3.fromRGB(180, 180, 165)
			card.ZIndex = 22
			card.Parent = list
			local numberLabel = label(card, "Number", entry:GetAttribute("DisplayNumber") or fullNumber, UDim2.fromOffset(12, 8), UDim2.new(1, -180, 0, 28), 22, 23)
			numberLabel.Font = Enum.Font.ArialBold
			local rarityLabel = label(card, "Rarity", entry:GetAttribute("RarityName") or "", UDim2.new(1, -170, 0, 8), UDim2.fromOffset(158, 28), 16, 23)
			rarityLabel.TextXAlignment = Enum.TextXAlignment.Right
			rarityLabel.TextColor3 = colors[rarityIndex] or colors[1]
			label(card, "Origin", (entry:GetAttribute("OperatorName") or "") .. " · " .. (entry:GetAttribute("Region") or ""), UDim2.fromOffset(12, 40), UDim2.new(1, -24, 0, 20), 14, 23)
			label(card, "Values", "Продажа: " .. money(entry:GetAttribute("SalePrice")) .. " ₽ · Доход в слоте: " .. money(entry:GetAttribute("IncomePerHour")) .. " ₽/ч", UDim2.fromOffset(12, 70), UDim2.new(1, -24, 0, 24), 16, 23)
		end
	end
	emptyLabel.Visible = shown == 0
	emptyLabel.Text = #items == 0 and "В коллекции пока нет номеров." or "Ничего не найдено. Измените поиск или редкость."
	footer.Text = string.format("Показано: %d из %d", shown, #items)
end

local function queueRender()
	if renderScheduled then return end
	renderScheduled = true
	task.defer(function()
		renderScheduled = false
		if panel.Parent then render() end
	end)
end

local function watchItem(entry)
	if entry:IsA("Folder") and not itemConnections[entry] then
		itemConnections[entry] = entry.AttributeChanged:Connect(queueRender)
	end
end

local function bindInventory(folder)
	for _, connection in folderConnections do connection:Disconnect() end
	table.clear(folderConnections)
	for _, connection in pairs(itemConnections) do connection:Disconnect() end
	table.clear(itemConnections)
	inventory = folder
	for _, entry in folder:GetChildren() do watchItem(entry) end
	table.insert(folderConnections, folder.ChildAdded:Connect(function(entry)
		watchItem(entry)
		queueRender()
	end))
	table.insert(folderConnections, folder.ChildRemoved:Connect(function(entry)
		if itemConnections[entry] then itemConnections[entry]:Disconnect(); itemConnections[entry] = nil end
		queueRender()
	end))
	queueRender()
end

openButton.Activated:Connect(function()
	if not openButton.Active then return end
	panel.Visible = true
	queueRender()
end)
closeButton.Activated:Connect(function() panel.Visible = false end)
search:GetPropertyChangedSignal("Text"):Connect(function()
	local digits = search.Text:gsub("%D", "")
	if search.Text ~= digits then search.Text = digits end
	queueRender()
end)
rarityButton.Activated:Connect(function()
	rarityFilter = (rarityFilter + 1) % (#Config.Rarities + 1)
	rarityButton.Text = rarityFilter == 0 and "Все редкости" or Config.Rarities[rarityFilter].Name
	queueRender()
end)
player:GetAttributeChangedSignal("InventoryCapacity"):Connect(queueRender)
player:GetAttributeChangedSignal("DataReady"):Connect(queueRender)
player.ChildAdded:Connect(function(child)
	if child.Name == "NumberInventory" and child:IsA("Folder") then bindInventory(child) end
end)
local existingInventory = player:FindFirstChild("NumberInventory")
if existingInventory then bindInventory(existingInventory) else queueRender() end
