local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local oldGui = playerGui:FindFirstChild("NumberRushUI")
if oldGui then oldGui:Destroy() end

local function formatMoney(value)
	local text = string.format("%.0f", value)
	local formatted = text:reverse():gsub("(%d%d%d)", "%1 ")
	return formatted:reverse():gsub("^ ", "")
end

local gui = Instance.new("ScreenGui")
gui.Name = "NumberRushUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.Size = UDim2.fromOffset(620, 420)
window.BackgroundColor3 = Color3.fromRGB(236, 233, 216)
window.BorderSizePixel = 3
window.BorderColor3 = Color3.fromRGB(0, 60, 170)
window.Parent = gui

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = Color3.fromRGB(0, 84, 227)
titleBar.BorderSizePixel = 0
titleBar.Parent = window
local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new(Color3.fromRGB(55, 130, 245), Color3.fromRGB(0, 55, 170))
titleGradient.Rotation = 90
titleGradient.Parent = titleBar

local function makeLabel(name, text, position, size)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arial
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(25, 25, 25)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = window
	return label
end

local titleLabel = makeLabel("Title", "NUMBER RUSH — Терминал оператора", UDim2.fromOffset(12, 0), UDim2.new(1, -24, 0, 34))
titleLabel.Font = Enum.Font.ArialBold
titleLabel.TextColor3 = Color3.new(1, 1, 1)
local balanceLabel = makeLabel("Balance", "Баланс: загрузка...", UDim2.fromOffset(24, 52), UDim2.new(1, -48, 0, 30))
balanceLabel.Font = Enum.Font.ArialBold
balanceLabel.TextSize = 22
local profileLabel = makeLabel("Profile", "Стартовая прокрутка", UDim2.fromOffset(24, 96), UDim2.new(1, -48, 0, 28))

local resultPanel = Instance.new("Frame")
resultPanel.Name = "ResultPanel"
resultPanel.Position = UDim2.fromOffset(24, 140)
resultPanel.Size = UDim2.new(1, -48, 0, 130)
resultPanel.BackgroundColor3 = Color3.fromRGB(255, 255, 250)
resultPanel.BorderColor3 = Color3.fromRGB(150, 150, 140)
resultPanel.BorderSizePixel = 1
resultPanel.Parent = window
local resultLabel = Instance.new("TextLabel")
resultLabel.Name = "Number"
resultLabel.Size = UDim2.new(1, -24, 0, 60)
resultLabel.Position = UDim2.fromOffset(12, 12)
resultLabel.BackgroundTransparency = 1
resultLabel.Font = Enum.Font.ArialBold
resultLabel.TextSize = 30
resultLabel.Text = "+7 (---) --- -- --"
resultLabel.TextColor3 = Color3.fromRGB(30, 45, 70)
resultLabel.Parent = resultPanel
local detailsLabel = Instance.new("TextLabel")
detailsLabel.Name = "Details"
detailsLabel.Position = UDim2.fromOffset(12, 78)
detailsLabel.Size = UDim2.new(1, -24, 0, 36)
detailsLabel.BackgroundTransparency = 1
detailsLabel.Font = Enum.Font.Arial
detailsLabel.TextSize = 16
detailsLabel.Text = "Здесь появится полученный номер"
detailsLabel.TextColor3 = Color3.fromRGB(90, 90, 90)
detailsLabel.Parent = resultPanel

local spinButton = Instance.new("TextButton")
spinButton.Name = "SpinButton"
spinButton.Position = UDim2.fromOffset(24, 294)
spinButton.Size = UDim2.new(1, -48, 0, 52)
spinButton.BackgroundColor3 = Color3.fromRGB(215, 215, 205)
spinButton.BorderColor3 = Color3.fromRGB(130, 130, 120)
spinButton.Font = Enum.Font.ArialBold
spinButton.TextSize = 22
spinButton.TextColor3 = Color3.fromRGB(100, 100, 100)
spinButton.Text = "Крутить — " .. formatMoney(Config.Profiles.Starter.Price) .. " ₽"
spinButton.AutoButtonColor = false
spinButton.Active = false
spinButton.Parent = window
local statusLabel = makeLabel("Status", "Продолжительность: " .. Config.SpinDuration .. " секунд", UDim2.fromOffset(24, 364), UDim2.new(1, -48, 0, 28))
statusLabel.TextSize = 16

-- Исправление ожидания данных из шага 19: ограниченные таймауты.
task.spawn(function()
	statusLabel.Text = "Загрузка профиля..."
	local stats = player:WaitForChild("leaderstats", 30)
	if not stats then
		balanceLabel.Text = "Баланс недоступен"
		statusLabel.Text = "Профиль не загрузился. Переподключитесь."
		warn("NUMBER RUSH UI: leaderstats не появился за 30 секунд")
		return
	end
	local rubles = stats:WaitForChild("Рубли", 10)
	if not rubles then
		balanceLabel.Text = "Баланс недоступен"
		statusLabel.Text = "Не найден показатель рублей."
		warn("NUMBER RUSH UI: в leaderstats отсутствует Рубли")
		return
	end
	local function updateBalance() balanceLabel.Text = "Баланс: " .. formatMoney(rubles.Value) .. " ₽" end
	rubles:GetPropertyChangedSignal("Value"):Connect(updateBalance)
	updateBalance()
	statusLabel.Text = "Продолжительность: " .. Config.SpinDuration .. " секунд"
end)

-- Выбор оператора, региона и кода (шаг 20).
window.Size = UDim2.fromOffset(620, 540)
profileLabel.Position = UDim2.fromOffset(24, 254)
resultPanel.Position = UDim2.fromOffset(24, 294)
resultPanel.Size = UDim2.new(1, -48, 0, 112)
resultLabel.Position = UDim2.fromOffset(12, 6)
resultLabel.Size = UDim2.new(1, -24, 0, 50)
detailsLabel.Position = UDim2.fromOffset(12, 64)
detailsLabel.Size = UDim2.new(1, -24, 0, 32)
spinButton.Position = UDim2.fromOffset(24, 424)
spinButton.Size = UDim2.new(1, -48, 0, 44)
statusLabel.Position = UDim2.fromOffset(24, 484)
makeLabel("OperatorTitle", "Оператор", UDim2.fromOffset(24, 94), UDim2.new(1, -48, 0, 22))
makeLabel("CodeTitle", "Регион и код", UDim2.fromOffset(24, 164), UDim2.new(1, -48, 0, 22))

local function makeChoiceFrame(name, y, height)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = UDim2.fromOffset(24, y)
	frame.Size = UDim2.new(1, -48, 0, height)
	frame.BackgroundTransparency = 1
	frame.Parent = window
	return frame
end
local operatorFrame = makeChoiceFrame("Operators", 120, 34)
local codeFrame = makeChoiceFrame("Codes", 190, 52)

local function makeChoiceButton(parent, text, index, count)
	local button = Instance.new("TextButton")
	button.Name = "Choice" .. index
	button.Position = UDim2.new((index - 1) / count, 3, 0, 0)
	button.Size = UDim2.new(1 / count, -6, 1, 0)
	button.BackgroundColor3 = Color3.fromRGB(240, 240, 230)
	button.BorderColor3 = Color3.fromRGB(140, 140, 130)
	button.Font = Enum.Font.Arial
	button.TextSize = 16
	button.TextWrapped = true
	button.TextColor3 = Color3.fromRGB(30, 30, 30)
	button.Text = text
	button.Parent = parent
	return button
end

local function highlightButton(button, selected)
	if selected then
		button.BackgroundColor3 = Color3.fromRGB(210, 230, 255)
		button.BorderColor3 = Color3.fromRGB(0, 84, 227)
	else
		button.BackgroundColor3 = Color3.fromRGB(240, 240, 230)
		button.BorderColor3 = Color3.fromRGB(140, 140, 130)
	end
end

local operatorButtons, codeButtons = {}, {}
local selectedOffer = nil

local function selectOffer(offer)
	selectedOffer = offer
	local profile = Config.Profiles[offer.ProfileId]
	local catalogOffer = Config.CodeOffers[offer.Code]
	window:SetAttribute("SelectedCode", offer.Code)
	profileLabel.Text = catalogOffer.OperatorName .. " · " .. profile.Name
	spinButton.Text = "Крутить — " .. formatMoney(profile.Price) .. " ₽"
	resultLabel.Text = "+7 (" .. offer.Code .. ") --- -- --"
	local minimumRarity = 1
	for index, weight in profile.Weights do
		if weight > 0 then minimumRarity = index; break end
	end
	detailsLabel.Text = "Гарантия: " .. Config.Rarities[minimumRarity].Name .. " и выше"
	for _, entry in codeButtons do highlightButton(entry.Button, entry.Offer.Code == offer.Code) end
end

local function selectOperator(operatorIndex)
	local operator = Config.Operators[operatorIndex]
	local previousRegion = nil
	if selectedOffer then previousRegion = selectedOffer.Region end
	for index, button in operatorButtons do highlightButton(button, index == operatorIndex) end
	for _, entry in codeButtons do entry.Button:Destroy() end
	table.clear(codeButtons)
	local preferredOffer = operator.Codes[1]
	for index, codeOffer in operator.Codes do
		local offer = codeOffer
		local button = makeChoiceButton(codeFrame, offer.Region .. "\n+7 (" .. offer.Code .. ")", index, #operator.Codes)
		table.insert(codeButtons, {Button = button, Offer = offer})
		button.Activated:Connect(function() selectOffer(offer) end)
		if offer.Region == previousRegion then preferredOffer = offer end
	end
	selectOffer(preferredOffer)
end

for index, operator in Config.Operators do
	local operatorIndex = index
	local button = makeChoiceButton(operatorFrame, operator.Name, index, #Config.Operators)
	operatorButtons[index] = button
	button.Activated:Connect(function() selectOperator(operatorIndex) end)
end
selectOperator(1)

-- Подключение платной прокрутки (шаг 25).
-- Не включён предложенный в шаге 21 автоскейл: пользователь отказался от изменения окна.
local spinRemotes = ReplicatedStorage:WaitForChild("NumberRushRemotes", 15)
if not spinRemotes then
	statusLabel.Text = "Терминал недоступен"
	warn("NUMBER RUSH UI: папка NumberRushRemotes не найдена")
	return
end
local requestRemote = spinRemotes:WaitForChild("SpinRequest", 15)
local resultRemote = spinRemotes:WaitForChild("SpinResult", 15)
if not requestRemote or not resultRemote then
	statusLabel.Text = "Терминал недоступен"
	warn("NUMBER RUSH UI: отсутствуют события прокрутки")
	return
end

local busy = false
local nextSequence = 0
local activeSequence = nil
local animationToken = 0
local balanceValue = nil
local visualRandom = Random.new()
statusLabel.TextWrapped = true
statusLabel.TextSize = 14
statusLabel.Size = UDim2.new(1, -48, 0, 42)

local function refreshControls()
	local serverSequence = player:GetAttribute("NextSpinSequence")
	if type(serverSequence) == "number" then nextSequence = math.max(nextSequence, serverSequence) end
	local ready = player:GetAttribute("DataReady") == true
	local offer = selectedOffer
	local profile = offer and Config.Profiles[offer.ProfileId] or nil
	local money = balanceValue and balanceValue.Value or 0
	local count = player:GetAttribute("InventoryCount") or 0
	local capacity = player:GetAttribute("InventoryCapacity") or 25
	local enabled = ready and not busy and profile ~= nil and balanceValue ~= nil
		and nextSequence >= 1 and money >= profile.Price and count < capacity
	spinButton.Active = enabled
	spinButton.Interactable = enabled
	spinButton.AutoButtonColor = enabled
	if enabled then
		spinButton.BackgroundColor3 = Color3.fromRGB(220, 235, 255)
		spinButton.TextColor3 = Color3.fromRGB(20, 45, 80)
	else
		spinButton.BackgroundColor3 = Color3.fromRGB(215, 215, 205)
		spinButton.TextColor3 = Color3.fromRGB(100, 100, 100)
	end
	if busy then spinButton.Text = "Прокрутка..."
	elseif count >= capacity then spinButton.Text = "Коллекция заполнена"
	elseif profile then spinButton.Text = "Крутить — " .. formatMoney(profile.Price) .. " ₽" end
	for _, frame in {operatorFrame, codeFrame} do
		for _, button in frame:GetChildren() do
			if button:IsA("TextButton") then button.Active = not busy; button.Interactable = not busy end
		end
	end
end

local function stopAnimation() animationToken += 1 end

local function startAnimation(code, duration)
	animationToken += 1
	local token = animationToken
	local startedAt = os.clock()
	task.spawn(function()
		while busy and animationToken == token do
			resultLabel.Text = string.format("+7 (%s) %03d-%02d-%02d", code, visualRandom:NextInteger(0, 999), visualRandom:NextInteger(0, 99), visualRandom:NextInteger(0, 99))
			local remaining = math.ceil(math.max(0, duration - (os.clock() - startedAt)))
			if remaining > 0 then statusLabel.Text = "Получение номера... " .. remaining .. " сек."
			else statusLabel.Text = "Завершаем выдачу номера..." end
			task.wait(0.08)
		end
	end)
end

resultRemote.OnClientEvent:Connect(function(packet)
	if type(packet) ~= "table" then return end
	if type(packet.NextSequence) == "number" then nextSequence = math.max(nextSequence, packet.NextSequence) end
	if packet.Sequence ~= nil and packet.Sequence ~= activeSequence then return end
	if packet.Status == "Started" then
		startAnimation(packet.Code, tonumber(packet.Duration) or Config.SpinDuration)
		return
	end
	if packet.Status == "Error" and packet.ErrorCode == "Busy" and busy then return end
	if packet.Status ~= "Success" and packet.Status ~= "Cancelled" and packet.Status ~= "Error" then return end
	stopAnimation()
	busy = false
	activeSequence = nil
	if packet.Status == "Success" and packet.Item then
		local item = packet.Item
		resultLabel.Text = item.DisplayNumber
		detailsLabel.Text = string.format("%s · Продажа: %s ₽\nДоход в слоте: %s ₽/ч", item.RarityName, formatMoney(item.SalePrice), formatMoney(item.IncomePerHour))
		statusLabel.Text = string.format("Номер добавлен в коллекцию: %d/%d", packet.InventoryCount or 0, player:GetAttribute("InventoryCapacity") or 25)
	elseif packet.Status == "Cancelled" then
		resultLabel.Text = "Выдача отменена"
		detailsLabel.Text = "Стоимость прокрутки возвращена"
		statusLabel.Text = packet.Reason or "Попробуйте ещё раз."
	else
		statusLabel.Text = packet.Message or "Не удалось выполнить прокрутку."
	end
	refreshControls()
end)

spinButton.Activated:Connect(function()
	if busy or not spinButton.Active or not selectedOffer then return end
	busy = true
	activeSequence = nextSequence
	local sequence = activeSequence
	local code = selectedOffer.Code
	detailsLabel.Text = "Ожидаем ответ терминала"
	statusLabel.Text = "Отправляем запрос..."
	refreshControls()
	requestRemote:FireServer(code, sequence)
	task.delay(60, function()
		if busy and activeSequence == sequence then
			stopAnimation()
			statusLabel.Text = "Выдача задерживается. Дождитесь ответа или переподключитесь."
		end
	end)
end)

for _, attribute in {"DataReady", "NextSpinSequence", "InventoryCount", "InventoryCapacity"} do
	player:GetAttributeChangedSignal(attribute):Connect(refreshControls)
end
window:GetAttributeChangedSignal("SelectedCode"):Connect(refreshControls)
task.spawn(function()
	local stats = player:WaitForChild("leaderstats", 30)
	if not stats then return end
	balanceValue = stats:WaitForChild("Рубли", 10)
	if not balanceValue then return end
	balanceValue:GetPropertyChangedSignal("Value"):Connect(refreshControls)
	refreshControls()
end)
refreshControls()
