-- NUMBER RUSH desktop. UI state only; money, issuance and slot ownership stay on the server.
local DesktopUI = {}

function DesktopUI.Start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")
	local player = Players.LocalPlayer
	local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
	local playerGui = player:WaitForChild("PlayerGui")
	local previous = playerGui:FindFirstChild("NumberRushUI")
	if previous then previous:Destroy() end
	local C = {
		blue = Color3.fromRGB(0, 78, 190), blueLight = Color3.fromRGB(58, 143, 246),
		cream = Color3.fromRGB(236, 233, 216), paper = Color3.fromRGB(255, 254, 246),
		ink = Color3.fromRGB(29, 47, 70), muted = Color3.fromRGB(104, 114, 122),
		line = Color3.fromRGB(183, 189, 181), pale = Color3.fromRGB(220, 235, 250),
		green = Color3.fromRGB(46, 128, 56), gold = Color3.fromRGB(175, 123, 27),
		red = Color3.fromRGB(186, 63, 42), purple = Color3.fromRGB(125, 77, 167),
	}
	local rarityColors = {C.muted, C.green, C.blue, C.purple, C.gold, C.red}
	local function create(class, parent, props)
		local obj = Instance.new(class)
		for key, value in pairs(props or {}) do obj[key] = value end
		obj.Parent = parent
		return obj
	end
	local function frame(parent, name, position, size, color, z)
		return create("Frame", parent, {Name = name, Position = position, Size = size, BackgroundColor3 = color or C.cream, BorderSizePixel = 0, ZIndex = z or 1})
	end
	local function stroke(obj, color, thickness)
		local existing = obj:FindFirstChildOfClass("UIStroke")
		if existing then existing.Color = color or C.line; existing.Thickness = thickness or 1; return existing end
		return create("UIStroke", obj, {Color = color or C.line, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
	end
	local function corner(obj, radius) create("UICorner", obj, {CornerRadius = UDim.new(0, radius or 4)}) end
	local function gradient(obj, top, bottom)
		create("UIGradient", obj, {Color = ColorSequence.new(top, bottom), Rotation = 90})
	end
	local function label(parent, name, value, position, size, fontSize, color, bold, z)
		return create("TextLabel", parent, {Name = name, Text = value, Position = position, Size = size,
			BackgroundTransparency = 1, Font = bold and Enum.Font.ArialBold or Enum.Font.Arial,
			TextSize = fontSize or 14, TextColor3 = color or C.ink, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true, ZIndex = z or 2})
	end
	local function button(parent, name, value, position, size, callback, color, z)
		local b = create("TextButton", parent, {Name = name, Text = value, Position = position, Size = size,
			BackgroundColor3 = color or C.cream, BorderSizePixel = 0, Font = Enum.Font.ArialBold,
			TextSize = 14, TextColor3 = C.ink, AutoButtonColor = true, ZIndex = z or 3})
		corner(b, 4); stroke(b)
		if callback then b.Activated:Connect(callback) end
		return b
	end
	local function enabled(b, value)
		b.Active = value; b.Interactable = value; b.AutoButtonColor = value
		b.TextTransparency = value and 0 or 0.45
	end
	local function money(value)
		local s = string.format("%.0f", tonumber(value) or 0):reverse():gsub("(%d%d%d)", "%1 "):reverse()
		return (s:gsub("^ ", ""))
	end
	local function fold(value)
		local result = {}
		for _, code in utf8.codes(value) do
			if code >= 0x410 and code <= 0x42f then code = code + 32 elseif code == 0x401 then code = 0x451 end
			table.insert(result, utf8.char(code):lower())
		end
		return table.concat(result)
	end
	local function badge(parent, name, value, x, y, width, color)
		local b = frame(parent, name, UDim2.fromOffset(x, y), UDim2.fromOffset(width, 23), color or C.pale, 4)
		corner(b, 3)
		local t = label(b, "Text", value, UDim2.fromOffset(5, 0), UDim2.new(1, -10, 1, 0), 11, C.ink, true, 5)
		t.TextXAlignment = Enum.TextXAlignment.Center
		return b
	end
	local function textbox(parent, name, placeholder, position, size)
		local t = create("TextBox", parent, {Name = name, PlaceholderText = placeholder, Text = "", ClearTextOnFocus = false,
			Position = position, Size = size, BackgroundColor3 = C.paper, BorderSizePixel = 0,
			Font = Enum.Font.Arial, TextSize = 14, TextColor3 = C.ink, PlaceholderColor3 = C.muted,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4})
		stroke(t); corner(t, 3)
		create("UIPadding", t, {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})
		return t
	end
	local function scroll(parent, name, position, size)
		return create("ScrollingFrame", parent, {Name = name, Position = position, Size = size, BackgroundTransparency = 1,
			BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = C.blue,
			CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 3})
	end
	local function clear(parent)
		for _, child in parent:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	end
	local function listLayout(parent, padding)
		create("UIListLayout", parent, {Padding = UDim.new(0, padding or 8), SortOrder = Enum.SortOrder.LayoutOrder})
		create("UIPadding", parent, {PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 6)})
	end
	-- Small pixel icons, drawn in code so the desktop needs no third-party assets.
	local patterns = {
		collection = {"  ######  "," ##    ## ","##########","##      ##","##      ##","##########"},
		upgrades = {"    ##    ","   ####   ","  ######  ","    ##    ","    ##    ","    ##    "},
		trade = {" #######  "," ##   ##  ","  ## ##   ","   ###    ","    ##    ","     ##   "},
		quests = {"  ######  "," ##    ## "," ## #  ## "," ## ## ## "," ##  #### ","  ######  "},
		top = {" ######## ","###    ###"," ##    ## ","  ######  ","    ##    ","  ######  "},
		shop = {" ##    ## "," ######## "," ##    ## "," ##    ## "," ##    ## "," ######## "},
		terminal = {"##########","##      ##","## #### ##","##      ##","##########","   ####   "},
	}
	local function icon(parent, key, color)
		local pixels = frame(parent, "Icon", UDim2.fromOffset(0, 0), UDim2.fromOffset(30, 20), C.paper, 4)
		pixels.BackgroundTransparency = 1
		for y, row in ipairs(patterns[key] or patterns.terminal) do
			for x = 1, #row do
				if row:sub(x, x) == "#" then frame(pixels, "Pixel", UDim2.fromOffset((x - 1) * 3, (y - 1) * 3), UDim2.fromOffset(3, 3), color, 4) end
			end
		end
		return pixels
	end
	local gui = create("ScreenGui", playerGui, {Name = "NumberRushUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10})
	gui:SetAttribute("InterfaceVersion", 2)
	local root = frame(gui, "Desktop", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.cream)
	root.BackgroundTransparency = 1
	local currentPage, balanceValue = "terminal", nil
	local showPage, renderCollection, renderSlots, renderTop, renderPlayers, refreshControls
	local currentItems, inventory = {}, nil
	local slotState, slotReceivedAt, slotBusy, slotUncertain = nil, 0, false, false
	local slotRequestSerial, selectedItemId, collectionMode = 0, nil, "numbers"
	local spinBusy, activeSequence, nextSequence, animationToken = false, nil, 0, 0
	local spinStarted, rosterPreference = false, nil
	local selectedOperator, selectedOffer, lastItem = 1, Config.Operators[1].Codes[1], nil
	local remotes = ReplicatedStorage:WaitForChild("NumberRushRemotes", 15)
	local requestRemote = remotes and remotes:WaitForChild("SpinRequest", 15)
	local resultRemote = remotes and remotes:WaitForChild("SpinResult", 15)
	local slotRequest = remotes and remotes:WaitForChild("SlotRequest", 15)
	local slotResult = remotes and remotes:WaitForChild("SlotResult", 15)
	local connected = requestRemote and resultRemote and slotRequest and slotResult
	local topbar = frame(root, "ConnectionBar", UDim2.fromOffset(14, 8), UDim2.fromOffset(690, 38), C.cream, 5)
	corner(topbar, 5); stroke(topbar, C.blue, 2)
	local brand = label(topbar, "Brand", "NR", UDim2.fromOffset(9, 0), UDim2.fromOffset(34, 38), 22, C.blue, true)
	local connection = label(topbar, "Connection", "СОЕДИНЕНИЕ...", UDim2.fromOffset(49, 0), UDim2.fromOffset(140, 38), 11, C.muted, true)
	local rateLabel = label(topbar, "Rate", "ДОХОД: —", UDim2.fromOffset(200, 0), UDim2.fromOffset(180, 38), 12, C.green, true)
	local caption = label(topbar, "Caption", "ГОРОДСКОЙ УЗЕЛ СВЯЗИ", UDim2.fromOffset(388, 0), UDim2.fromOffset(218, 38), 11, C.muted, true)
	local helpButton = button(topbar, "Help", "?", UDim2.new(1, -64, 0, 7), UDim2.fromOffset(25, 24), nil, C.paper)
	local languageButton = button(topbar, "Language", "RU", UDim2.new(1, -34, 0, 7), UDim2.fromOffset(28, 24), nil, C.paper)
	local sidebar = frame(root, "Sidebar", UDim2.fromOffset(12, 170), UDim2.fromOffset(164, 296), C.cream, 5)
	corner(sidebar, 6); stroke(sidebar, C.blue, 2)
	local menuLabel = label(sidebar, "Title", "АБОНЕНТСКИЙ ОТДЕЛ", UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 24), 9, C.blue, true)
	menuLabel.TextXAlignment = Enum.TextXAlignment.Center
	local menus = {
		{"collection", "КОЛЛЕКЦИЯ", C.blue}, {"upgrades", "ПРОКАЧКА", C.purple},
		{"trade", "ТОРГИ", Color3.fromRGB(194, 106, 35)}, {"quests", "ЗАДАНИЯ", C.green},
		{"top", "РЕЙТИНГ", C.gold}, {"shop", "МАГАЗИН", Color3.fromRGB(180, 65, 116)},
	}
	local menuButtons = {}
	for index, data in ipairs(menus) do
		local b = button(sidebar, data[1], "", UDim2.fromOffset(0, 0), UDim2.fromOffset(72, 76), function() showPage(data[1]) end, C.paper)
		local i = icon(b, data[1], data[3]); i.Position = UDim2.new(0.5, -15, 0, 12)
		local t = label(b, "Caption", data[2], UDim2.fromOffset(1, 44), UDim2.new(1, -2, 0, 25), 10, C.ink, true, 4)
		t.TextXAlignment = Enum.TextXAlignment.Center
		menuButtons[index] = b
	end
	local roster = frame(root, "PlayerRoster", UDim2.new(1, -180, 0, 75), UDim2.fromOffset(168, 210), C.cream, 20)
	corner(roster, 5); stroke(roster, C.blue)
	label(roster, "Title", "АБОНЕНТЫ", UDim2.fromOffset(10, 0), UDim2.new(1, -40, 0, 34), 12, C.blue, true)
	local rosterClose = button(roster, "Close", "—", UDim2.new(1, -29, 0, 6), UDim2.fromOffset(23, 22), function() rosterPreference = false; roster.Visible = false end)
	local rosterList = scroll(roster, "Players", UDim2.fromOffset(8, 38), UDim2.new(1, -14, 1, -42)); listLayout(rosterList, 5)
	local hud = frame(root, "Taskbar", UDim2.new(0.5, -310, 1, -76), UDim2.fromOffset(620, 64), C.cream, 8)
	corner(hud, 5); stroke(hud, C.blue, 2)
	local terminalButton = button(hud, "Terminal", "Пуск", UDim2.fromOffset(7, 7), UDim2.fromOffset(82, 50), function() showPage("terminal") end, C.green, 9)
	terminalButton.TextColor3 = Color3.new(1, 1, 1); terminalButton.TextSize = 21
	label(hud, "BalanceTitle", "ЛИЦЕВОЙ СЧЁТ", UDim2.fromOffset(106, 7), UDim2.fromOffset(200, 16), 10, C.muted, true, 9)
	local balanceLabel = label(hud, "Balance", "Загрузка...", UDim2.fromOffset(105, 22), UDim2.fromOffset(250, 32), 26, C.ink, true, 9)
	local capacityButton = button(hud, "Collection", "SIM: 0/25", UDim2.new(1, -246, 0, 8), UDim2.fromOffset(116, 47), function() showPage("collection") end, C.paper, 9)
	local subscribers = button(hud, "Subscribers", "Абоненты", UDim2.new(1, -122, 0, 8), UDim2.fromOffset(112, 47), function() rosterPreference = not roster.Visible; roster.Visible = rosterPreference end, C.pale, 9)
	local window = frame(root, "Window", UDim2.new(0.5, -340, 0.5, -260), UDim2.fromOffset(680, 520), C.cream, 10)
	corner(window, 5); stroke(window, C.blue, 3)
	local header = frame(window, "TitleBar", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 38), C.blue, 11)
	gradient(header, C.blueLight, C.blue)
	local headerIcon = icon(header, "terminal", Color3.new(1, 1, 1)); headerIcon.Position = UDim2.fromOffset(10, 9)
	local windowTitle = label(header, "Title", "NUMBER RUSH — ТЕРМИНАЛ", UDim2.fromOffset(49, 0), UDim2.new(1, -125, 1, 0), 16, Color3.new(1, 1, 1), true, 12)
	button(header, "Minimize", "—", UDim2.new(1, -62, 0, 7), UDim2.fromOffset(24, 24), function() window.Visible = false end, C.blueLight, 12).TextColor3 = Color3.new(1, 1, 1)
	button(header, "Close", "X", UDim2.new(1, -31, 0, 7), UDim2.fromOffset(24, 24), function() window.Visible = false end, C.red, 12).TextColor3 = Color3.new(1, 1, 1)
	local body = frame(window, "Body", UDim2.fromOffset(14, 50), UDim2.new(1, -28, 1, -84), C.cream, 11)
	local status = label(window, "Status", "Подключение к станции...", UDim2.new(0, 15, 1, -28), UDim2.new(1, -30, 0, 24), 11, C.muted, false, 12)
	local pages = {}
	for _, key in ipairs({"terminal", "collection", "upgrades", "trade", "quests", "top", "shop"}) do
		local page = frame(body, key, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), C.cream, 11)
		page.BackgroundTransparency = 1; page.Visible = key == currentPage; pages[key] = page
	end
	local modal = frame(body, "Modal", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), C.paper, 25)
	corner(modal, 4); stroke(modal, C.blue, 2); modal.Visible = false
	local modalContent = scroll(modal, "Content", UDim2.fromOffset(18, 48), UDim2.new(1, -36, 1, -62)); modalContent.ZIndex = 26
	local modalTitle = label(modal, "Title", "СПРАВКА", UDim2.fromOffset(18, 6), UDim2.new(1, -70, 0, 30), 17, C.blue, true, 26)
	button(modal, "Close", "X", UDim2.new(1, -36, 0, 10), UDim2.fromOffset(24, 24), function() modal.Visible = false end, C.cream, 27)
	local modalActionCallback
	local modalAction = button(modal, "Action", "", UDim2.new(0, 18, 1, -50), UDim2.new(1, -36, 0, 36), function() if modalActionCallback then modalActionCallback() end end, C.pale, 28)
	modalAction.Visible = false
	local function information(title, paragraphs)
		clear(modalContent); modalTitle.Text = title; modal.Visible = true
		modalAction.Visible = false; modalActionCallback = nil; modalContent.Size = UDim2.new(1, -36, 1, -62); modalContent.CanvasPosition = Vector2.zero
		local y = 0
		for _, value in ipairs(paragraphs) do
			local t = label(modalContent, "Paragraph", value, UDim2.fromOffset(0, y), UDim2.new(1, -8, 0, 62), 15, C.ink, false, 27)
			t.TextYAlignment = Enum.TextYAlignment.Top; y = y + 76
		end
		modalContent.CanvasSize = UDim2.fromOffset(0, y)
	end
	languageButton.Activated:Connect(function()
		window.Visible = true
		information("ЯЗЫК ИНТЕРФЕЙСА", {"Русский язык · RU", "Другие языки пока не подключены."})
	end)
	helpButton.Activated:Connect(function()
		window.Visible = true
		information("СПРАВОЧНАЯ УЗЛА СВЯЗИ", {
			"Пуск — получение номеров. Выберите оператора и код: цена и шансы зависят от профиля, а не от бренда оператора.",
			"Коллекция — поиск, редкость, сортировка и подробности SIM-карт. Установите номер в доходный слот, чтобы получать рубли онлайн.",
			"Замена слота — раз в 60 минут. Снятие не обнуляет таймер; последний занятый слот снять нельзя.",
			"Разделы с отметкой «Скоро» показывают будущие возможности. Покупки, автопродажа и торги в них ещё недоступны.",
		})
	end)
	-- Generator: same server request sequence and existing economic offers.
	local generator = pages.terminal
	label(generator, "Section", "ВЫДАЧА АБОНЕНТСКИХ НОМЕРОВ", UDim2.fromOffset(0, 0), UDim2.new(1, -90, 0, 22), 11, C.muted, true)
	button(generator, "Probabilities", "Шансы", UDim2.new(1, -82, 0, -2), UDim2.fromOffset(82, 26), function()
		local profile = Config.Profiles[selectedOffer.ProfileId]
		local lines = {profile.Name .. " профиль · " .. money(profile.Price) .. " ₽ за попытку"}
		for i, weight in ipairs(profile.Weights) do table.insert(lines, Config.Rarities[i].Name .. ": " .. string.format("%.5f", weight / 100000) .. "%") end
		information("ВЕРОЯТНОСТИ ВЫДАЧИ", lines)
	end)
	local operatorButtons = {}
	local selectOperator, selectOffer
	for i, op in ipairs(Config.Operators) do
		operatorButtons[i] = button(generator, op.Id, op.Name, UDim2.new((i - 1) / 4, 0, 0, 32), UDim2.new(0.25, -6, 0, 32), function() if not spinBusy then selectOperator(i) end end, C.paper)
	end
	local codeButton = button(generator, "CodeSelector", "Выбрать регион и код", UDim2.fromOffset(0, 74), UDim2.new(1, -94, 0, 36), nil, C.paper)
	local autoSettings = button(generator, "AutoSettings", "Авто...", UDim2.new(1, -86, 0, 74), UDim2.fromOffset(86, 36), function()
		clear(modalContent); modalTitle.Text = "АВТОПРОДАЖА — СКОРО"; modal.Visible = true
		modalAction.Visible = false; modalActionCallback = nil; modalContent.Size = UDim2.new(1, -36, 1, -62); modalContent.CanvasPosition = Vector2.zero
		label(modalContent, "State", "ВЫКЛЮЧЕНА · продажа системе ещё не подключена", UDim2.fromOffset(0, 0), UDim2.new(1, -8, 0, 32), 14, C.muted, true, 27)
		local sellTab = button(modalContent, "SellTab", "ПРОДАВАТЬ", UDim2.fromOffset(0, 42), UDim2.new(0.5, -5, 0, 32), nil, C.pale, 27)
		local keepTab = button(modalContent, "KeepTab", "ОСТАВЛЯТЬ", UDim2.new(0.5, 5, 0, 42), UDim2.new(0.5, -13, 0, 32), nil, C.cream, 27)
		enabled(sellTab, false); enabled(keepTab, false)
		label(modalContent, "RarityTitle", "ПО РЕДКОСТИ · ПРЕДВАРИТЕЛЬНЫЙ ПРОСМОТР", UDim2.fromOffset(0, 85), UDim2.new(1, -8, 0, 24), 11, C.muted, true, 27)
		for i, rarity in ipairs(Config.Rarities) do
			local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
			local b = button(modalContent, "Rarity" .. i, rarity.Name, UDim2.new(col * 0.5, col == 0 and 0 or 5, 0, 116 + row * 42), UDim2.new(0.5, -8, 0, 34), nil, C.paper, 27)
			b.TextColor3 = rarityColors[i]; stroke(b, rarityColors[i]); enabled(b, false)
		end
		label(modalContent, "ThresholdTitle", "ЦЕНОВОЙ ПОРОГ И ПРИОРИТЕТ СОХРАНЕНИЯ", UDim2.fromOffset(0, 250), UDim2.new(1, -8, 0, 26), 11, C.muted, true, 27)
		label(modalContent, "Threshold", "Появятся вместе с серверной продажей. Пока все номера остаются в коллекции.", UDim2.fromOffset(0, 280), UDim2.new(1, -8, 0, 55), 14, C.ink, false, 27)
		modalContent.CanvasSize = UDim2.fromOffset(0, 345)
	end)
	local ticket = frame(generator, "NumberCard", UDim2.fromOffset(0, 122), UDim2.new(1, 0, 1, -218), C.paper)
	corner(ticket, 5); stroke(ticket)
	local punch = frame(ticket, "SIMChip", UDim2.fromOffset(18, 18), UDim2.fromOffset(34, 27), Color3.fromRGB(221, 188, 103), 3)
	corner(punch, 4); stroke(punch, C.gold)
	for i = 1, 2 do frame(punch, "Contact", UDim2.new(i / 3, 0, 0, 0), UDim2.new(0, 1, 1, 0), C.gold, 4) end
	frame(punch, "Contact", UDim2.new(0, 0, 0.5, 0), UDim2.new(1, 0, 0, 1), C.gold, 4)
	local ticketBrand = label(ticket, "Operator", "БиЛайнк / АБОНЕНТСКАЯ КАРТОЧКА", UDim2.fromOffset(65, 18), UDim2.new(1, -78, 0, 28), 11, C.muted, true)
	local number = label(ticket, "Number", "+7 (903) •••-••-••", UDim2.new(0, 14, 0.34, 0), UDim2.new(1, -28, 0, 52), 32, C.ink, true)
	number.Font = Enum.Font.Code; number.TextXAlignment = Enum.TextXAlignment.Center
	local resultDetails = label(ticket, "Details", "Гарантия: обычный и выше", UDim2.new(0, 16, 1, -58), UDim2.new(1, -32, 0, 38), 13, C.muted)
	resultDetails.TextXAlignment = Enum.TextXAlignment.Center
	local spinButton = button(generator, "SpinButton", "ПОЛУЧИТЬ НОМЕР", UDim2.new(0, 132, 1, -66), UDim2.new(1, -132, 0, 43), nil, C.green)
	spinButton.TextColor3 = Color3.new(1, 1, 1); spinButton.TextSize = 17
	local multiButtons = {}
	for count = 1, 4 do
		local b = button(generator, "Batch" .. count, "×" .. count, UDim2.new(0, (count - 1) * 30, 1, -66), UDim2.fromOffset(28, 43), count > 1 and function()
			information("ПАКЕТНАЯ ВЫДАЧА — СКОРО", {"Сейчас доступна одна выдача за раз. Покупка пакетов ×2–×4 будет подключена отдельным серверным обновлением."})
		end or nil, count == 1 and C.pale or C.cream)
		multiButtons[count] = b
		if count > 1 then b.TextColor3 = C.muted end
	end
	local generatorNote = label(generator, "Timing", "Одна SIM-карта · 6 секунд · оплата только на сервере", UDim2.new(0, 0, 1, -18), UDim2.new(1, 0, 0, 18), 10, C.muted)
	local regionPopup = frame(generator, "RegionPopup", UDim2.fromOffset(0, 114), UDim2.new(1, 0, 1, -190), C.paper, 15)
	stroke(regionPopup, C.blue, 2); corner(regionPopup, 4); regionPopup.Visible = false
	local regionSearch = textbox(regionPopup, "Search", "Название региона или код...", UDim2.fromOffset(12, 12), UDim2.new(1, -55, 0, 32))
	regionSearch.ZIndex = 16
	button(regionPopup, "Close", "X", UDim2.new(1, -34, 0, 16), UDim2.fromOffset(24, 24), function() regionPopup.Visible = false end, C.cream, 17)
	local regionList = scroll(regionPopup, "Regions", UDim2.fromOffset(12, 53), UDim2.new(1, -24, 1, -62)); regionList.ZIndex = 16; listLayout(regionList, 6)
	local function renderRegions()
		clear(regionList)
		local query = fold(regionSearch.Text)
		for _, offer in ipairs(Config.Operators[selectedOperator].Codes) do
			if query == "" or string.find(fold(offer.Region), query, 1, true) or string.find(offer.Code, query, 1, true) then
				local profile = Config.Profiles[offer.ProfileId]
				local b = button(regionList, "Code" .. offer.Code, "", UDim2.fromOffset(0, 0), UDim2.new(1, -8, 0, 58), function() selectOffer(offer); regionPopup.Visible = false end, C.cream, 17)
				badge(b, "Code", "+7 " .. offer.Code, 10, 17, 65, C.pale).ZIndex = 18
				label(b, "Region", offer.Region, UDim2.fromOffset(86, 6), UDim2.new(1, -192, 0, 25), 14, C.ink, true, 18)
				label(b, "Profile", profile.Name, UDim2.fromOffset(86, 30), UDim2.new(1, -190, 0, 18), 11, C.muted, false, 18)
				local price = label(b, "Price", money(profile.Price) .. " ₽", UDim2.new(1, -100, 0, 14), UDim2.fromOffset(90, 30), 14, C.blue, true, 18)
				price.TextXAlignment = Enum.TextXAlignment.Right
			end
		end
	end
	selectOffer = function(offer)
		if spinBusy then return end
		selectedOffer = offer
		local info = Config.CodeOffers[offer.Code]; local profile = Config.Profiles[offer.ProfileId]
		codeButton.Text = info.Region .. "  ·  +7 (" .. offer.Code .. ")  v"
		if not lastItem then
			ticketBrand.Text = info.OperatorName .. " / АБОНЕНТСКАЯ КАРТОЧКА"
			number.Text = "+7 (" .. offer.Code .. ") •••-••-••"
		end
		local minimum = 1
		for i, weight in ipairs(profile.Weights) do if weight > 0 then minimum = i; break end end
		if not lastItem then resultDetails.Text = "Гарантия: " .. Config.Rarities[minimum].Name .. " и выше" end
		refreshControls()
	end
	selectOperator = function(index)
		selectedOperator = index
		for i, b in ipairs(operatorButtons) do b.BackgroundColor3 = i == index and C.pale or C.paper end
		local preferred = Config.Operators[index].Codes[1]
		for _, offer in ipairs(Config.Operators[index].Codes) do if offer.ProfileId == selectedOffer.ProfileId then preferred = offer; break end end
		selectOffer(preferred); renderRegions()
	end
	codeButton.Activated:Connect(function() if not spinBusy then regionPopup.Visible = not regionPopup.Visible; renderRegions() end end)
	regionSearch:GetPropertyChangedSignal("Text"):Connect(renderRegions)
	-- Collection: real inventory cards, local filters and authoritative slot actions.
	local collection = pages.collection
	local collectionTabs = {}
	local setCollectionMode, requestSlots
	collectionTabs.numbers = button(collection, "NumbersTab", "SIM-КАРТЫ", UDim2.fromOffset(0, 0), UDim2.fromOffset(128, 32), function() setCollectionMode("numbers") end, C.pale)
	collectionTabs.slots = button(collection, "SlotsTab", "ДОХОДНЫЕ СЛОТЫ", UDim2.fromOffset(136, 0), UDim2.fromOffset(170, 32), function() setCollectionMode("slots") end)
	local collectionCount = label(collection, "Count", "0 / 25", UDim2.new(1, -100, 0, 0), UDim2.fromOffset(100, 32), 14, C.blue, true)
	collectionCount.TextXAlignment = Enum.TextXAlignment.Right
	local cardsPane = frame(collection, "CardsPane", UDim2.fromOffset(0, 42), UDim2.new(1, 0, 1, -42)); cardsPane.BackgroundTransparency = 1
	local search = textbox(cardsPane, "Search", "Поиск по цифрам номера", UDim2.fromOffset(0, 0), UDim2.new(1, -194, 0, 32))
	local rarityFilter, sortMode = 0, 1
	local rarityButton = button(cardsPane, "Rarity", "Все редкости", UDim2.new(1, -184, 0, 0), UDim2.fromOffset(184, 32), nil, C.paper)
	local sortButton = button(cardsPane, "Sort", "Порядок: новые", UDim2.fromOffset(0, 40), UDim2.fromOffset(174, 27), nil)
	label(cardsPane, "CardTip", "Нажмите на карточку — подробности и установка", UDim2.new(0, 188, 0, 40), UDim2.new(1, -188, 0, 27), 11, C.muted)
	local cards = scroll(cardsPane, "Cards", UDim2.fromOffset(0, 77), UDim2.new(1, 0, 1, -77))
	local cardGrid = create("UIGridLayout", cards, {CellSize = UDim2.new(0.5, -7, 0, 156), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder})
	create("UIPadding", cards, {PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 5), PaddingBottom = UDim.new(0, 6)})
	local emptyCards = label(cardsPane, "Empty", "", UDim2.fromOffset(18, 100), UDim2.new(1, -36, 0, 110), 17, C.muted)
	emptyCards.TextXAlignment = Enum.TextXAlignment.Center; emptyCards.Visible = false
	local slotsPane = frame(collection, "SlotsPane", UDim2.fromOffset(0, 42), UDim2.new(1, 0, 1, -42)); slotsPane.BackgroundTransparency = 1; slotsPane.Visible = false
	local slotSelection = label(slotsPane, "Selection", "Выберите SIM-карту в коллекции для установки.", UDim2.fromOffset(0, 0), UDim2.new(1, -110, 0, 36), 13, C.ink)
	local slotRefresh = button(slotsPane, "Refresh", "Обновить", UDim2.new(1, -100, 0, 0), UDim2.fromOffset(100, 32), function() requestSlots("GetState") end, C.paper)
	local slotRows = scroll(slotsPane, "Slots", UDim2.fromOffset(0, 45), UDim2.new(1, 0, 1, -83)); listLayout(slotRows, 9)
	label(slotsPane, "Rule", "Замена раз в 60 минут · последний источник дохода защищён", UDim2.new(0, 0, 1, -30), UDim2.new(1, 0, 0, 28), 11, C.muted)
	local slotTimers = {}
	local function displayItem(item)
		lastItem = item
		number.Text = item.DisplayNumber or "+7 (---) --- -- --"
		number.TextColor3 = rarityColors[item.RarityIndex or 1] or C.ink
		ticketBrand.Text = (item.OperatorName or "NUMBER RUSH") .. " / " .. (item.Region or "КОЛЛЕКЦИЯ")
		resultDetails.Text = (item.RarityName or "") .. "  ·  Оценка " .. money(item.SalePrice) .. " ₽\nВ слоте: " .. money(item.IncomePerHour) .. " ₽/ч"
	end
	local function itemDetails(item)
		information("ПАСПОРТ SIM-КАРТЫ", {
			(item.DisplayNumber or "") .. "\n" .. (item.RarityName or "") .. " · " .. (item.OperatorName or "") .. " · " .. (item.Region or ""),
			"Оценочная стоимость: " .. money(item.SalePrice) .. " ₽\nДоход при установке: " .. money(item.IncomePerHour) .. " ₽/ч",
			string.format("Расчёт: база %s ₽ × цифры %.2f × код %.2f × совпадение %.2f", money(item.BasePrice), item.DigitMultiplier or 1, item.PrestigeMultiplier or 1, item.CodeMatchMultiplier or 1),
			item.Location == "IncomeSlot" and ("Установлен в доходный слот №" .. tostring(item.IncomeSlotIndex)) or "Номер находится в коллекции. Продажа системе пока не подключена.",
		})
		modalAction.Visible = true
		modalAction.Text = item.Location == "IncomeSlot" and "ПОКАЗАТЬ ДОХОДНЫЕ СЛОТЫ" or "УСТАНОВИТЬ В ДОХОДНЫЙ СЛОТ"
		modalContent.Size = UDim2.new(1, -36, 1, -112)
		modalActionCallback = function()
			selectedItemId = item.IssuanceId; modal.Visible = false; setCollectionMode("slots"); requestSlots("GetState")
		end
		modalContent.CanvasSize = UDim2.fromOffset(0, 304)
	end
	renderCollection = function()
		clear(cards)
		collectionCount.Text = tostring(#currentItems) .. " / " .. tostring(player:GetAttribute("InventoryCapacity") or Config.StartingInventoryCapacity)
		local ordered = table.clone(currentItems)
		table.sort(ordered, function(a, b)
			local av = sortMode == 2 and (a.SalePrice or 0) or sortMode == 3 and (a.RarityIndex or 0) or (a.AcquiredAt or 0)
			local bv = sortMode == 2 and (b.SalePrice or 0) or sortMode == 3 and (b.RarityIndex or 0) or (b.AcquiredAt or 0)
			if av == bv then return a.IssuanceId < b.IssuanceId end
			return av > bv
		end)
		local query, shown = search.Text:gsub("%D", ""), 0
		for _, item in ipairs(ordered) do
			if (rarityFilter == 0 or item.RarityIndex == rarityFilter) and (query == "" or string.find(item.FullNumber or "", query, 1, true)) then
				shown = shown + 1
				local color = rarityColors[item.RarityIndex or 1] or C.muted
				local card = button(cards, item.IssuanceId, "", UDim2.fromOffset(0, 0), UDim2.fromOffset(280, 156), function() itemDetails(item) end, C.paper)
				card.LayoutOrder = shown; stroke(card, color)
				frame(card, "Stripe", UDim2.fromOffset(0, 8), UDim2.new(0, 4, 1, -16), color, 4)
				label(card, "Rarity", item.RarityName or "", UDim2.fromOffset(14, 9), UDim2.new(1, -24, 0, 19), 11, color, true, 4)
				local phone = label(card, "Number", item.DisplayNumber or "", UDim2.fromOffset(13, 34), UDim2.new(1, -20, 0, 31), 20, C.ink, true, 4)
				phone.Font = Enum.Font.Code
				label(card, "Operator", (item.OperatorName or "") .. " · " .. (item.Region or ""), UDim2.fromOffset(14, 68), UDim2.new(1, -25, 0, 27), 10, C.muted, false, 4)
				label(card, "Value", money(item.SalePrice) .. " ₽  ·  " .. money(item.IncomePerHour) .. " ₽/ч", UDim2.fromOffset(14, 101), UDim2.new(1, -25, 0, 22), 12, C.ink, true, 4)
				label(card, "Location", item.Location == "IncomeSlot" and ("В СЛОТЕ №" .. tostring(item.IncomeSlotIndex)) or "ОТКРЫТЬ ПАСПОРТ  →", UDim2.fromOffset(14, 130), UDim2.new(1, -25, 0, 16), 10, item.Location == "IncomeSlot" and C.green or C.blue, true, 4)
			end
		end
		emptyCards.Visible = shown == 0
		emptyCards.Text = #currentItems == 0 and "Здесь будут ваши SIM-карты.\nПолучите первый номер в терминале." or "Номера не найдены.\nИзмените поиск или редкость."
	end
	local function getSelectedItem()
		for _, item in ipairs(currentItems) do if item.IssuanceId == selectedItemId then return item end end
		return nil
	end
	renderSlots = function()
		clear(slotRows); table.clear(slotTimers)
		local item = getSelectedItem()
		slotSelection.Text = item and ("Выбрано: " .. item.DisplayNumber) or "Откройте паспорт SIM-карты, чтобы выбрать её для установки."
		enabled(slotRefresh, not slotBusy and player:GetAttribute("DataReady") == true)
		if not slotState then
			label(slotRows, "Waiting", "Запрашиваем состояние слотов...", UDim2.fromOffset(0, 0), UDim2.new(1, -8, 0, 70), 16, C.muted)
			return
		end
		for _, slot in ipairs(slotState.Slots) do
			local row = frame(slotRows, "Slot" .. slot.SlotIndex, UDim2.fromOffset(0, 0), UDim2.new(1, -9, 0, 100), C.paper, 3)
			corner(row, 4); stroke(row, slot.IssuanceId and C.green or C.line)
			badge(row, "Index", tostring(slot.SlotIndex), 12, 12, 30, slot.IssuanceId and C.pale or C.cream)
			label(row, "Number", slot.DisplayNumber or "Свободная линия", UDim2.fromOffset(54, 9), UDim2.new(1, -66, 0, 26), 18, C.ink, true, 4)
			local timer = label(row, "Timer", "", UDim2.fromOffset(54, 36), UDim2.new(1, -66, 0, 20), 11, C.muted, false, 4)
			local install = button(row, "Install", slot.IssuanceId and "Заменить выбранным" or "Установить выбранный", UDim2.fromOffset(12, 65), UDim2.new(0.62, -16, 0, 27), function() requestSlots("Install", slot.SlotIndex, selectedItemId) end, C.pale, 5)
			local remove = button(row, "Remove", "Снять", UDim2.new(0.65, 0, 0, 65), UDim2.new(0.35, -13, 0, 27), function() requestSlots("Remove", slot.SlotIndex) end, C.cream, 5)
			local function update()
				local remaining = math.max(0, (slot.NextChangeAt or 0) - slotState.ServerTime - (os.clock() - slotReceivedAt))
				timer.Text = (slot.IssuanceId and (money(slot.IncomePerHour) .. " ₽/ч · ") or "") .. (remaining > 0 and ("Замена через " .. math.ceil(remaining / 60) .. " мин.") or "Замена доступна")
				local ready = not slotBusy and not slotUncertain and not spinBusy and player:GetAttribute("DataReady") == true
				enabled(install, ready and item ~= nil and item.Location == "Inventory" and remaining <= 0)
				enabled(remove, ready and slot.IssuanceId ~= nil and slotState.ActiveCount > 1)
			end
			update(); table.insert(slotTimers, update)
		end
	end
	requestSlots = function(action, index, issuanceId)
		if not connected or slotBusy or player:GetAttribute("DataReady") ~= true then return end
		if action ~= "GetState" and (slotUncertain or not slotState or spinBusy) then return end
		slotBusy = true; slotRequestSerial = slotRequestSerial + 1
		local serial = slotRequestSerial
		status.Text = action == "GetState" and "Получаем состояние линий..." or "Сохраняем назначение..."
		renderSlots(); refreshControls()
		slotRequest:FireServer(action, index, issuanceId, slotState and slotState.Revision)
		task.delay(20, function()
			if slotBusy and serial == slotRequestSerial then
				slotBusy = false; slotUncertain = true
				status.Text = "Ответ задерживается. Нажмите «Обновить» для проверки назначения."
				renderSlots(); refreshControls()
			end
		end)
	end
	setCollectionMode = function(mode)
		collectionMode = mode; cardsPane.Visible = mode == "numbers"; slotsPane.Visible = mode == "slots"
		collectionTabs.numbers.BackgroundColor3 = mode == "numbers" and C.pale or C.cream
		collectionTabs.slots.BackgroundColor3 = mode == "slots" and C.pale or C.cream
		if mode == "slots" then renderSlots(); requestSlots("GetState") else cards.CanvasPosition = Vector2.zero; renderCollection(); status.Text = "Ваши SIM-карты · поиск, сортировка и паспорта номеров" end
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		local digits = search.Text:gsub("%D", "")
		if search.Text ~= digits then search.Text = digits end
		cards.CanvasPosition = Vector2.zero; renderCollection()
	end)
	rarityButton.Activated:Connect(function()
		rarityFilter = (rarityFilter + 1) % (#Config.Rarities + 1)
		rarityButton.Text = rarityFilter == 0 and "Все редкости" or Config.Rarities[rarityFilter].Name
		cards.CanvasPosition = Vector2.zero; renderCollection()
	end)
	sortButton.Activated:Connect(function()
		sortMode = sortMode % 3 + 1; sortButton.Text = ({"Порядок: новые", "Порядок: по цене", "Порядок: редкость"})[sortMode]
		cards.CanvasPosition = Vector2.zero; renderCollection()
	end)
	-- Future features are deliberate, labelled previews. No invented listings, rewards or purchases.
	local function planned(parent, headline, description, y)
		local panel = frame(parent, "Planned", UDim2.fromOffset(0, y or 0), UDim2.new(1, 0, 0, 88), C.paper)
		corner(panel, 4); stroke(panel)
		badge(panel, "Soon", "СКОРО", 12, 12, 65, Color3.fromRGB(249, 231, 178))
		label(panel, "Title", headline, UDim2.fromOffset(88, 9), UDim2.new(1, -100, 0, 26), 17, C.ink, true)
		label(panel, "Description", description, UDim2.fromOffset(12, 43), UDim2.new(1, -24, 0, 34), 13, C.muted)
		return panel
	end
	local upgrades = pages.upgrades
	planned(upgrades, "ДЕРЕВО УЛУЧШЕНИЙ", "Схема будущего развития. Покупки пока недоступны; параметры — по балансу v0.2.")
	local tree = scroll(upgrades, "UpgradeTree", UDim2.fromOffset(0, 102), UDim2.new(1, 0, 1, -102))
	tree.AutomaticCanvasSize = Enum.AutomaticSize.None; tree.CanvasSize = UDim2.fromOffset(940, 540); tree.ScrollingDirection = Enum.ScrollingDirection.XY
	tree.BackgroundTransparency = 0; tree.BackgroundColor3 = Color3.fromRGB(225, 233, 231); corner(tree, 4)
	local branches = {
		{"Доходные слоты", "3 → 4 → 5", 40, 40, C.blue}, {"Коллекция", "25 → 200 мест", 340, 40, C.blue},
		{"Автопрокрутка", "Автоматическая выдача", 640, 40, C.green}, {"Удача", "Пять ступеней", 40, 212, C.green},
		{"Скорость", "От 6 до 4 секунд", 340, 212, C.gold}, {"Особые выдачи", "Счастливые и блатные", 640, 212, C.purple},
		{"Крафт", "Пять рецептов", 40, 384, C.purple}, {"Задания", "До четырёх активных", 340, 384, C.green},
		{"Репутация", "Звания и оформление", 640, 384, C.gold},
	}
	for _, node in ipairs(branches) do
		if node[3] < 640 then frame(tree, "Wire", UDim2.fromOffset(node[3] + 242, node[4] + 46), UDim2.fromOffset(58, 2), C.line) end
		if node[4] < 384 then frame(tree, "Wire", UDim2.fromOffset(node[3] + 120, node[4] + 98), UDim2.fromOffset(2, 74), C.line) end
		local n = button(tree, "Node", "", UDim2.fromOffset(node[3], node[4]), UDim2.fromOffset(242, 98), function()
			information(node[1] .. " — СКОРО", {node[2], "Эта ветка ещё не подключена. Рубли не списываются, улучшения не выдаются."})
		end, C.paper)
		stroke(n, node[5], 2)
		label(n, "Title", node[1], UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 25), 16, node[5], true)
		label(n, "Value", node[2], UDim2.fromOffset(12, 39), UDim2.new(1, -24, 0, 23), 13, C.ink)
		label(n, "State", "СКОРО  /  НЕ ПРИОБРЕТЕНО", UDim2.fromOffset(12, 73), UDim2.new(1, -24, 0, 16), 9, C.muted, true)
	end
	local trade = pages.trade
	local marketTab, auctionTab
	local tradePreview = frame(trade, "Preview", UDim2.fromOffset(0, 48), UDim2.new(1, 0, 1, -48)); tradePreview.BackgroundTransparency = 1
	local function tradeMode(auction)
		marketTab.BackgroundColor3 = auction and C.cream or C.pale; auctionTab.BackgroundColor3 = auction and C.pale or C.cream
		clear(tradePreview)
		planned(tradePreview, auction and "АУКЦИОН ГОТОВИТСЯ К ОТКРЫТИЮ" or "БИРЖА SIM-КАРТ", "Торги между игроками ещё не подключены. Активных лотов и истории сделок нет.")
		local notice = label(tradePreview, "Rules", auction and "ПО ПЛАНУ\n\nТорги на 5 минут · комиссия 10%\nПродление при ставке в последние секунды\nРезерв денег и места под номер" or "ПО ПЛАНУ\n\nЛоты на 5 минут · комиссия 5%\nПоиск по номеру, коду и редкости\nПодтверждение покупки и передача владельцу", UDim2.fromOffset(16, 112), UDim2.new(1, -32, 0, 160), 16, C.ink)
		notice.TextYAlignment = Enum.TextYAlignment.Top
		button(tradePreview, "DisabledTrade", "ОТКРЫТИЕ СКОРО", UDim2.new(0, 0, 1, -48), UDim2.new(1, 0, 0, 38), nil, C.cream).Interactable = false
	end
	marketTab = button(trade, "MarketTab", "РЫНОК", UDim2.fromOffset(0, 0), UDim2.fromOffset(140, 34), function() tradeMode(false) end, C.pale)
	auctionTab = button(trade, "AuctionTab", "АУКЦИОН", UDim2.fromOffset(148, 0), UDim2.fromOffset(140, 34), function() tradeMode(true) end)
	tradeMode(false)
	local quests = pages.quests
	planned(quests, "ЖУРНАЛ АБОНЕНТСКОГО ОТДЕЛА", "Задания ещё не выдаются. Здесь появятся реальные цели, прогресс и награды.")
	local questsList = scroll(quests, "PlannedQuests", UDim2.fromOffset(0, 102), UDim2.new(1, 0, 1, -102)); listLayout(questsList, 10)
	for i, data in ipairs({{"Ежедневные цели", "Получение номеров, мини-игры и коллекционирование"}, {"Заказы NPC", "Подбор номера для посетителей офиса"}, {"Достижения", "Редкие находки и собранные коллекции"}}) do
		local row = frame(questsList, "FutureQuest" .. i, UDim2.fromOffset(0, 0), UDim2.new(1, -8, 0, 86), C.paper)
		corner(row, 4); stroke(row)
		badge(row, "Index", "0" .. i, 12, 14, 35, C.pale)
		label(row, "Title", data[1], UDim2.fromOffset(60, 9), UDim2.new(1, -74, 0, 26), 16, C.ink, true)
		label(row, "Detail", data[2], UDim2.fromOffset(60, 39), UDim2.new(1, -74, 0, 30), 12, C.muted)
	end
	local shop = pages.shop
	planned(shop, "ВИТРИНА ОФИСА СВЯЗИ", "Магазин готовится к открытию. Сейчас покупки за рубли и Robux недоступны.")
	local shopList = scroll(shop, "Showcase", UDim2.fromOffset(0, 102), UDim2.new(1, 0, 1, -102)); listLayout(shopList, 10)
	for _, data in ipairs({{"Темы кабинета", "Новые обои, мебель и оформление рабочего места", C.blue}, {"Оформление SIM-карт", "Коллекционные рамки без экономических бонусов", C.purple}, {"VIP", "Умеренные преимущества и косметика по правилам v0.2", C.gold}}) do
		local row = frame(shopList, "ShowcaseCard", UDim2.fromOffset(0, 0), UDim2.new(1, -8, 0, 92), C.paper)
		corner(row, 4); stroke(row, data[3])
		label(row, "Title", data[1], UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 27), 18, data[3], true)
		label(row, "Description", data[2] .. " · СКОРО", UDim2.fromOffset(16, 43), UDim2.new(1, -32, 0, 38), 13, C.muted)
	end
	-- Current-server ranking, explicitly distinguished from the future global leaderboard.
	local rankingMode = "balance"
	local top = pages.top
	local topButtons = {}
	for i, data in ipairs({{"balance", "БАЛАНС"}, {"collection", "КОЛЛЕКЦИЯ"}}) do
		topButtons[data[1]] = button(top, data[1], data[2], UDim2.fromOffset((i - 1) * 148, 0), UDim2.fromOffset(140, 33), function() rankingMode = data[1]; renderTop() end)
	end
	label(top, "Scope", "Только этот сервер · общий рейтинг — скоро", UDim2.fromOffset(0, 43), UDim2.new(1, 0, 0, 27), 12, C.muted)
	local topList = scroll(top, "Ranking", UDim2.fromOffset(0, 80), UDim2.new(1, 0, 1, -80)); listLayout(topList, 8)
	local function playerBalance(p)
		local stats = p:FindFirstChild("leaderstats"); local value = stats and stats:FindFirstChild("Рубли")
		return value and value.Value or nil
	end
	renderTop = function()
		clear(topList)
		for key, b in pairs(topButtons) do b.BackgroundColor3 = key == rankingMode and C.pale or C.cream end
		local people = Players:GetPlayers()
		table.sort(people, function(a, b)
			local av = rankingMode == "balance" and (playerBalance(a) or -1) or (a:GetAttribute("InventoryCount") or -1)
			local bv = rankingMode == "balance" and (playerBalance(b) or -1) or (b:GetAttribute("InventoryCount") or -1)
			if av == bv then return a.UserId < b.UserId end
			return av > bv
		end)
		for i, p in ipairs(people) do
			local row = frame(topList, "Player" .. p.UserId, UDim2.fromOffset(0, 0), UDim2.new(1, -8, 0, 66), C.paper)
			corner(row, 4); stroke(row, i == 1 and C.gold or C.line)
			badge(row, "Place", tostring(i), 12, 20, 30, i == 1 and Color3.fromRGB(249, 231, 178) or C.pale)
			label(row, "Name", p.DisplayName, UDim2.fromOffset(56, 9), UDim2.new(0.6, -60, 0, 24), 15, C.ink, true)
			label(row, "Username", "@" .. p.Name, UDim2.fromOffset(56, 35), UDim2.new(0.6, -60, 0, 20), 10, C.muted)
			local value
			if rankingMode == "balance" then value = playerBalance(p) else value = p:GetAttribute("InventoryCount") end
			local t = label(row, "Value", value ~= nil and (money(value) .. (rankingMode == "balance" and " ₽" or " SIM")) or "Загрузка...", UDim2.new(0.6, 0, 0, 13), UDim2.new(0.4, -14, 0, 40), 18, C.blue, true)
			t.TextXAlignment = Enum.TextXAlignment.Right
		end
	end
	renderPlayers = function()
		clear(rosterList)
		for _, p in ipairs(Players:GetPlayers()) do
			local row = frame(rosterList, "Player" .. p.UserId, UDim2.fromOffset(0, 0), UDim2.new(1, -7, 0, 38), C.paper)
			corner(row, 4)
			local initials = label(row, "Avatar", p.DisplayName:sub(1, 2), UDim2.fromOffset(4, 4), UDim2.fromOffset(30, 30), 14, C.blue, true)
			initials.TextXAlignment = Enum.TextXAlignment.Center
			label(row, "Name", p.DisplayName, UDim2.fromOffset(40, 3), UDim2.new(1, -46, 0, 32), 11, p == player and C.blue or C.ink, true)
		end
	end
	-- Desktop routing and viewport layout: no changes to Roblox's native player list.
	local pageTitles = {terminal = "ТЕРМИНАЛ ВЫДАЧИ", collection = "КОЛЛЕКЦИЯ SIM-КАРТ", upgrades = "ПРОКАЧКА", trade = "ТОРГИ", quests = "ЗАДАНИЯ", top = "РЕЙТИНГ", shop = "МАГАЗИН"}
	showPage = function(key)
		modal.Visible = false; regionPopup.Visible = false; currentPage = key; window.Visible = true
		windowTitle.Text = "NUMBER RUSH — " .. pageTitles[key]
		for name, page in pairs(pages) do page.Visible = name == key end
		for i, data in ipairs(menus) do menuButtons[i].BackgroundColor3 = data[1] == key and C.pale or C.paper end
		if key == "collection" then cards.CanvasPosition = Vector2.zero; renderCollection(); if collectionMode == "slots" then requestSlots("GetState") end end
		if key == "top" then renderTop() end
		status.Text = key == "terminal" and "Выберите оператора и код. Цена указана до оплаты." or key == "collection" and "Ваши номера · данные получены с сервера" or key == "top" and "Актуальные данные игроков текущего сервера" or "Предварительный просмотр · этот раздел ещё не подключён"
	end
	local function layoutDesktop()
		local size = root.AbsoluteSize; local narrow = size.X < 1050
		local sideWidth = narrow and 78 or 164
		sidebar.Size = UDim2.fromOffset(sideWidth, narrow and 430 or 296)
		sidebar.Position = UDim2.fromOffset(10, math.max(58, (size.Y - sidebar.Size.Y.Offset) / 2 - 12))
		menuLabel.Visible = not narrow
		for i, b in ipairs(menuButtons) do
			b.Position = narrow and UDim2.fromOffset(6, 8 + (i - 1) * 69) or UDim2.fromOffset(7 + ((i - 1) % 2) * 78, 34 + math.floor((i - 1) / 2) * 84)
			b.Size = UDim2.fromOffset(narrow and 66 or 72, narrow and 61 or 76)
			b.Caption.Position = UDim2.fromOffset(1, narrow and 35 or 44)
			b.Caption.TextSize = narrow and 9 or 10
			b.Icon.Position = UDim2.new(0.5, -15, 0, narrow and 8 or 12)
		end
		roster.Visible = rosterPreference == nil and size.X >= 1250 or rosterPreference == true
		local left = sideWidth + 28; local right = roster.Visible and size.X >= 1250 and 194 or 16
		local width = math.min(700, size.X - left - right)
		local height = math.min(540, size.Y - 154)
		window.Size = UDim2.fromOffset(math.max(350, width), math.max(360, height))
		window.Position = UDim2.fromOffset(left + math.max(0, (size.X - left - right - width) / 2), math.max(58, (size.Y - height) / 2 - 18))
		roster.Position = UDim2.new(1, -180, 0, 60)
		topbar.Size = UDim2.fromOffset(math.min(690, size.X - 28), 38)
		topbar.Position = UDim2.new(0.5, -topbar.Size.X.Offset / 2, 0, 8)
		caption.Visible = size.X >= 760
		rateLabel.Position = UDim2.fromOffset(size.X < 760 and 180 or 200, 0)
		rateLabel.Size = UDim2.fromOffset(size.X < 760 and 165 or 180, 38)
		hud.Size = UDim2.fromOffset(math.min(620, size.X - 24), 64)
		hud.Position = UDim2.new(0.5, -hud.Size.X.Offset / 2, 1, -76)
		balanceLabel.Size = UDim2.new(1, -370, 0, 32)
		balanceLabel.TextSize = size.X < 700 and 22 or 26
		local oneColumn = width < 480
		cardGrid.CellSize = oneColumn and UDim2.new(1, -12, 0, 156) or UDim2.new(0.5, -7, 0, 156)
		number.TextSize = width < 540 and 26 or 32
		local compact = height < 480
		if compact then
			punch.Position = UDim2.fromOffset(16, 8); punch.Size = UDim2.fromOffset(26, 20)
			ticketBrand.Position = UDim2.fromOffset(52, 6); ticketBrand.Size = UDim2.new(1, -64, 0, 22); ticketBrand.TextSize = 10
			number.Position = UDim2.new(0, 12, 0, 29); number.Size = UDim2.new(1, -24, 0, 34); number.TextSize = 26
			resultDetails.Position = UDim2.new(0, 12, 1, -34); resultDetails.Size = UDim2.new(1, -24, 0, 30); resultDetails.TextSize = 11
		else
			punch.Position = UDim2.fromOffset(18, 18); punch.Size = UDim2.fromOffset(34, 27)
			ticketBrand.Position = UDim2.fromOffset(65, 18); ticketBrand.Size = UDim2.new(1, -78, 0, 28); ticketBrand.TextSize = 11
			number.Position = UDim2.new(0, 14, 0.34, 0); number.Size = UDim2.new(1, -28, 0, 52)
			resultDetails.Position = UDim2.new(0, 16, 1, -58); resultDetails.Size = UDim2.new(1, -32, 0, 38); resultDetails.TextSize = 13
		end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutDesktop)
	layoutDesktop()
	refreshControls = function()
		local serverSequence = player:GetAttribute("NextSpinSequence")
		if type(serverSequence) == "number" then nextSequence = math.max(nextSequence, serverSequence) end
		local ready = player:GetAttribute("DataReady") == true
		connection.Text = ready and "ЛИНИЯ ПОДКЛЮЧЕНА" or "СОЕДИНЕНИЕ..."; connection.TextColor3 = ready and C.green or C.muted
		local income = player:GetAttribute("IncomeEnabled") == true
		rateLabel.Text = income and ("ДОХОД: " .. money(player:GetAttribute("TotalBaseIncomePerHour")) .. " ₽/ч") or "ДОХОД НЕАКТИВЕН"
		capacityButton.Text = "SIM: " .. tostring(player:GetAttribute("InventoryCount") or #currentItems) .. "/" .. tostring(player:GetAttribute("InventoryCapacity") or Config.StartingInventoryCapacity)
		local profile = Config.Profiles[selectedOffer.ProfileId]
		local count = player:GetAttribute("InventoryCount") or 0
		local capacity = player:GetAttribute("InventoryCapacity") or Config.StartingInventoryCapacity
		local canSpin = connected and ready and not spinBusy and not slotBusy and balanceValue ~= nil and nextSequence >= 1 and balanceValue.Value >= profile.Price and count < capacity
		enabled(spinButton, canSpin == true)
		spinButton.Text = spinBusy and "ПОЛУЧАЕМ НОМЕР..." or count >= capacity and "КОЛЛЕКЦИЯ ЗАПОЛНЕНА" or ("ПОЛУЧИТЬ · " .. money(profile.Price) .. " ₽")
		for _, b in ipairs(operatorButtons) do enabled(b, not spinBusy) end
		enabled(codeButton, not spinBusy)
		if balanceValue then balanceLabel.Text = money(balanceValue.Value) .. " ₽" end
	end
	local visualRandom = Random.new()
	if connected then
		resultRemote.OnClientEvent:Connect(function(packet)
			if type(packet) ~= "table" then return end
			if type(packet.NextSequence) == "number" then nextSequence = math.max(nextSequence, packet.NextSequence) end
			if packet.Sequence ~= nil and packet.Sequence ~= activeSequence then return end
			if packet.Status == "Started" then
				spinStarted = true
				animationToken = animationToken + 1; local token = animationToken; local startedAt = os.clock()
				task.spawn(function()
					while spinBusy and token == animationToken and gui.Parent do
						number.Text = string.format("+7 (%s) %03d-%02d-%02d", packet.Code, visualRandom:NextInteger(0, 999), visualRandom:NextInteger(0, 99), visualRandom:NextInteger(0, 99))
						local left = math.ceil(math.max(0, (packet.Duration or Config.SpinDuration) - (os.clock() - startedAt)))
						status.Text = left > 0 and ("Станция подбирает номер... " .. left .. " сек.") or "Подтверждаем выдачу и сохранение..."
						task.wait(0.08)
					end
				end)
				return
			end
			if packet.Status == "Error" and packet.ErrorCode == "Busy" and spinBusy and spinStarted then return end
			if packet.Status ~= "Success" and packet.Status ~= "Error" and packet.Status ~= "Cancelled" then return end
			animationToken = animationToken + 1; spinBusy = false; spinStarted = false; activeSequence = nil
			if packet.Status == "Success" and packet.Item then
				displayItem(packet.Item); status.Text = "Номер выдан и сохранён. Откройте коллекцию для установки в слот."
			elseif packet.Status == "Cancelled" then
				number.Text = "Выдача отменена"; resultDetails.Text = "Стоимость возвращена"; status.Text = packet.Reason or "Повторите попытку."
			else status.Text = packet.Message or "Не удалось получить номер." end
			refreshControls(); renderSlots()
		end)
		slotResult.OnClientEvent:Connect(function(packet)
			if type(packet) ~= "table" then return end
			slotBusy = false; slotRequestSerial = slotRequestSerial + 1
			if type(packet.State) == "table" and (not slotState or packet.State.Revision >= slotState.Revision) then
				slotState = packet.State; slotReceivedAt = os.clock(); slotUncertain = false
			end
			if packet.ErrorCode == "RecoveryRequired" then slotUncertain = true end
			status.Text = packet.Status == "Error" and (packet.Message or "Не удалось изменить слот.") or packet.Status == "Success" and "Назначение сохранено." or "Состояние доходных линий обновлено."
			renderSlots(); refreshControls()
		end)
	else status.Text = "Станция недоступна: не найдены сетевые события." end
	spinButton.Activated:Connect(function()
		if not spinButton.Interactable or spinBusy or not connected then return end
		spinBusy = true; spinStarted = false; activeSequence = nextSequence; regionPopup.Visible = false
		local code, sequence = selectedOffer.Code, activeSequence
		ticketBrand.Text = Config.CodeOffers[code].OperatorName .. " / АБОНЕНТСКАЯ КАРТОЧКА"
		resultDetails.Text = "Запрос отправлен на станцию"; number.TextColor3 = C.ink
		status.Text = "Подключаемся к оператору..."; refreshControls()
		requestRemote:FireServer(code, sequence)
		task.delay(60, function()
			if spinBusy and activeSequence == sequence then
				animationToken = animationToken + 1
				status.Text = "Выдача задерживается. Дождитесь ответа или переподключитесь."
			end
		end)
	end)
	local inventoryConnections, itemConnections, scheduled = {}, {}, false
	local function updateInventory()
		currentItems = {}
		if inventory then
			for _, entry in inventory:GetChildren() do
				if entry:IsA("Folder") and type(entry:GetAttribute("FullNumber")) == "string" then
					local item = entry:GetAttributes(); item.IssuanceId = entry.Name; table.insert(currentItems, item)
				end
			end
		end
		if not lastItem and not spinBusy and #currentItems > 0 then
			local newest = currentItems[1]
			for _, item in ipairs(currentItems) do if (item.AcquiredAt or 0) > (newest.AcquiredAt or 0) then newest = item end end
			displayItem(newest)
		end
		if renderCollection then renderCollection(); renderSlots(); refreshControls() end
	end
	local function queueInventory()
		if scheduled then return end
		scheduled = true
		task.defer(function() scheduled = false; if gui.Parent then updateInventory() end end)
	end
	local function watchItem(entry)
		if not itemConnections[entry] then itemConnections[entry] = entry.AttributeChanged:Connect(queueInventory) end
	end
	local function bindInventory(folder)
		for _, c in ipairs(inventoryConnections) do c:Disconnect() end
		for _, c in pairs(itemConnections) do c:Disconnect() end
		inventoryConnections = {}; itemConnections = {}; inventory = folder
		for _, entry in folder:GetChildren() do watchItem(entry) end
		table.insert(inventoryConnections, folder.ChildAdded:Connect(function(entry) watchItem(entry); queueInventory() end))
		table.insert(inventoryConnections, folder.ChildRemoved:Connect(function(entry)
			if itemConnections[entry] then itemConnections[entry]:Disconnect(); itemConnections[entry] = nil end
			queueInventory()
		end))
		queueInventory()
	end
	player.ChildAdded:Connect(function(child) if child.Name == "NumberInventory" and child:IsA("Folder") then bindInventory(child) end end)
	local existing = player:FindFirstChild("NumberInventory"); if existing then bindInventory(existing) end
	for _, attr in ipairs({"DataReady", "NextSpinSequence", "InventoryCount", "InventoryCapacity", "IncomeEnabled", "TotalBaseIncomePerHour"}) do
		player:GetAttributeChangedSignal(attr):Connect(function()
			refreshControls()
			if attr == "InventoryCapacity" then renderCollection() end
			if attr == "DataReady" then
				renderSlots()
				if player:GetAttribute("DataReady") == true and currentPage == "collection" and collectionMode == "slots" then requestSlots("GetState") end
			end
		end)
	end
	Players.PlayerAdded:Connect(function() renderPlayers(); renderTop() end)
	Players.PlayerRemoving:Connect(function() task.defer(function() if gui.Parent then renderPlayers(); renderTop() end end) end)
	task.spawn(function()
		local stats = player:WaitForChild("leaderstats", 30)
		if not stats then status.Text = "Профиль не загрузился. Переподключитесь."; return end
		balanceValue = stats:WaitForChild("Рубли", 10)
		if not balanceValue then return end
		balanceValue:GetPropertyChangedSignal("Value"):Connect(refreshControls)
		refreshControls()
	end)
	task.spawn(function()
		local counter = 0
		while gui.Parent do
			task.wait(1); counter = counter + 1
			if currentPage == "collection" and collectionMode == "slots" then for _, update in ipairs(slotTimers) do update() end end
			if counter % 5 == 0 and currentPage == "top" and window.Visible then renderTop() end
		end
	end)
	selectOperator(1); renderPlayers(); renderTop(); renderCollection(); refreshControls(); showPage("terminal")
	window.BackgroundTransparency = 1
	TweenService:Create(window, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
end

return DesktopUI
