-- NUMBER RUSH desktop. UI state only; money, issuance and slot ownership stay on the server.
local DesktopUI = {}

function DesktopUI.Start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")
	local SoundService = game:GetService("SoundService")
	local player = Players.LocalPlayer
	local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
	local UpgradeRules = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
	local News = require(ReplicatedStorage:WaitForChild("NewsConfig"))
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
	-- Layered, shaded desktop icons are code-native and require no external assets.
	local function icon(parent, key, color)
		local art = frame(parent, "Icon", UDim2.fromOffset(0, 0), UDim2.fromOffset(48, 48), C.paper, 4)
		art.BackgroundTransparency = 1
		local function shape(x, y, w, h, fill, round, rotation)
			local r = frame(art, "Part", UDim2.fromOffset(x, y), UDim2.fromOffset(w, h), fill, 5)
			if round then corner(r, round) end
			if rotation then r.Rotation = rotation end
			return r
		end
		local white = Color3.fromRGB(248, 253, 255)
		local blue = key == "collection" and color or Color3.fromRGB(45, 116, 215)
		local gold = Color3.fromRGB(241, 185, 53)
		local shadow = shape(7, 37, 35, 6, Color3.fromRGB(18, 49, 79), 4); shadow.BackgroundTransparency = 0.6
		if key == "terminal" then
			local screen = shape(3, 3, 40, 29, Color3.fromRGB(211, 220, 232), 4); stroke(screen, Color3.fromRGB(105, 127, 155))
			local glass = shape(7, 7, 32, 20, blue, 2); gradient(glass, Color3.fromRGB(101, 195, 255), C.blue)
			shape(19, 32, 9, 5, Color3.fromRGB(177, 193, 213)); shape(11, 38, 27, 4, white, 2)
			shape(11, 11, 10, 2, white, 1); shape(11, 16, 19, 2, Color3.fromRGB(157, 224, 255), 1)
		elseif key == "collection" or key == "trade" then
			local back = shape(7, 4, 31, 35, blue, 4, -8); gradient(back, C.blueLight, C.blue)
			local card = shape(13, 10, 29, 34, white, 4); stroke(card, Color3.fromRGB(143, 166, 192))
			shape(18, 17, 15, 12, gold, 3); shape(23, 17, 1, 12, C.gold); shape(28, 17, 1, 12, C.gold); shape(18, 23, 15, 1, C.gold)
			shape(18, 34, 17, 2, key == "trade" and C.green or blue, 1)
		elseif key == "profile" then
			local book = shape(4, 4, 39, 38, blue, 5); gradient(book, C.blueLight, C.blue)
			shape(14, 9, 17, 17, Color3.fromRGB(255, 216, 165), 9)
			shape(9, 28, 28, 11, Color3.fromRGB(224, 244, 255), 5)
			shape(35, 32, 10, 10, Color3.fromRGB(69, 185, 84), 5); stroke(art:FindFirstChild("Part"), C.blue)
		elseif key == "mail" then
			local envelope = shape(3, 12, 41, 29, white, 3); stroke(envelope, Color3.fromRGB(144, 172, 196))
			shape(7, 13, 23, 2, blue, nil, 31); shape(22, 13, 23, 2, blue, nil, -31)
			shape(28, 29, 16, 12, gold, 3); label(art, "At", "@", UDim2.fromOffset(28, 26), UDim2.fromOffset(17, 17), 16, C.blue, true, 7)
		elseif key == "boosts" then
			shape(17, 3, 14, 7, Color3.fromRGB(225, 191, 100), 2)
			shape(19, 10, 10, 7, Color3.fromRGB(202, 236, 245), 2)
			local bottle = shape(9, 16, 30, 26, color or C.purple, 11); gradient(bottle, Color3.fromRGB(182, 146, 241), C.purple)
			shape(14, 20, 4, 13, Color3.fromRGB(232, 220, 255), 2)
			label(art, "Plus", "+", UDim2.fromOffset(21, 21), UDim2.fromOffset(13, 17), 19, white, true, 7)
		elseif key == "settings" then
			for i = 0, 5 do shape(20, 3, 9, 41, Color3.fromRGB(176, 190, 207), 2, i * 30) end
			shape(9, 9, 30, 30, Color3.fromRGB(115, 141, 174), 15)
			shape(17, 17, 14, 14, Color3.fromRGB(221, 236, 250), 7)
		elseif key == "top" then
			local cup = shape(10, 5, 28, 24, gold, 8); gradient(cup, Color3.fromRGB(255, 229, 124), Color3.fromRGB(219, 145, 27))
			shape(4, 9, 7, 16, gold, 3); shape(38, 9, 7, 16, gold, 3); shape(21, 27, 7, 9, gold)
			shape(13, 36, 23, 5, Color3.fromRGB(133, 83, 28), 2)
		elseif key == "upgrades" then
			for i = 1, 3 do local bar = shape(5 + (i - 1) * 13, 38 - i * 8, 10, i * 8 + 3, color or C.purple, 2); gradient(bar, Color3.fromRGB(190, 165, 242), color or C.purple) end
			shape(9, 9, 28, 4, gold, 2, -28); shape(31, 2, 5, 14, gold, 1, -30)
		elseif key == "shop" then
			local bag = shape(7, 15, 34, 27, Color3.fromRGB(70, 157, 80), 4); gradient(bag, Color3.fromRGB(145, 210, 105), C.green)
			local handle = shape(16, 5, 16, 17, C.cream, 8); stroke(handle, C.green, 3); handle.BackgroundTransparency = 1
			shape(12, 20, 3, 15, Color3.fromRGB(193, 235, 160), 2)
		else
			shape(9, 5, 30, 38, Color3.fromRGB(169, 121, 66), 3)
			shape(12, 9, 24, 30, white, 2); shape(17, 3, 14, 8, Color3.fromRGB(166, 184, 202), 2)
			for i = 1, 3 do shape(17, 14 + i * 6, 14, 2, C.green, 1) end
		end
		return art
	end
	local gui = create("ScreenGui", playerGui, {Name = "NumberRushUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10})
	gui:SetAttribute("InterfaceVersion", 2)
	local root = frame(gui, "Desktop", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.cream)
	root.BackgroundTransparency = 1
	local expanded, setExpanded, beginSpin, layoutDesktop = true, nil, nil, nil
	local maximized = false
	local wallpaper = frame(root, "Wallpaper", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(57, 137, 221), 0)
	wallpaper.ClipsDescendants = true
	gradient(wallpaper, Color3.fromRGB(32, 112, 207), Color3.fromRGB(167, 221, 247))
	local hillBack = frame(wallpaper, "DistantHill", UDim2.new(-0.2, 0, 0.62, 0), UDim2.new(1.5, 0, 0.8, 0), Color3.fromRGB(96, 164, 62), 1)
	corner(hillBack, 500); hillBack.Rotation = -10; gradient(hillBack, Color3.fromRGB(125, 189, 67), Color3.fromRGB(52, 127, 57))
	local hill = frame(wallpaper, "GreenHill", UDim2.new(-0.3, 0, 0.72, 0), UDim2.new(1.7, 0, 0.9, 0), Color3.fromRGB(81, 154, 47), 2)
	corner(hill, 500); hill.Rotation = 11; gradient(hill, Color3.fromRGB(111, 181, 49), Color3.fromRGB(33, 112, 57))
	for i, cloud in ipairs({{0.3, 0.16, 170}, {0.65, 0.1, 215}, {0.83, 0.29, 120}}) do
		local c = frame(wallpaper, "Cloud" .. i, UDim2.fromScale(cloud[1], cloud[2]), UDim2.fromOffset(cloud[3], 24), Color3.new(1, 1, 1), 1)
		corner(c, 24); c.BackgroundTransparency = 0.55
		local puff = frame(c, "Puff", UDim2.fromOffset(22, -12), UDim2.fromOffset(cloud[3] * 0.55, 39), Color3.new(1, 1, 1), 1); corner(puff, 30); puff.BackgroundTransparency = 0.55
	end
	label(wallpaper, "Watermark", "NUMBER RUSH\nГородской узел связи", UDim2.new(1, -250, 1, -130), UDim2.fromOffset(230, 60), 23, Color3.fromRGB(220, 244, 215), true, 3).TextXAlignment = Enum.TextXAlignment.Right
	local currentPage, balanceValue = "terminal", nil
	local showPage, renderCollection, renderSlots, renderTop, renderPlayers, refreshControls, renderProfile
	local progress = {Busy = false, Auto = false, Uncertain = false, Render = function() end}
	local profilePlayer = player
	local currentItems, inventory = {}, nil
	local slotState, slotReceivedAt, slotBusy, slotUncertain = nil, 0, false, false
	local slotRequestSerial, selectedItemId, collectionMode = 0, nil, "numbers"
	local spinBusy, activeSequence, nextSequence, animationToken = false, nil, 0, 0
	local spinStarted, rosterPreference = false, nil
	local selectedOperator, selectedOffer, lastItem = 1, Config.GetDefaultOffer(Config.Operators[1].Id), nil
	local remotes = ReplicatedStorage:WaitForChild("NumberRushRemotes", 15)
	local requestRemote = remotes and remotes:WaitForChild("SpinRequest", 15)
	local resultRemote = remotes and remotes:WaitForChild("SpinResult", 15)
	local slotRequest = remotes and remotes:WaitForChild("SlotRequest", 15)
	local slotResult = remotes and remotes:WaitForChild("SlotResult", 15)
	progress.Request = remotes and remotes:WaitForChild("ProgressRequest", 15)
	progress.Result = remotes and remotes:WaitForChild("ProgressResult", 15)
	local connected = progress.Request and progress.Result and requestRemote and resultRemote and slotRequest and slotResult
	local topbar = frame(root, "ConnectionBar", UDim2.fromOffset(14, 8), UDim2.fromOffset(690, 38), C.cream, 5)
	corner(topbar, 5); stroke(topbar, C.blue, 2)
	local brand = label(topbar, "Brand", "NR", UDim2.fromOffset(9, 0), UDim2.fromOffset(34, 38), 22, C.blue, true)
	local connection = label(topbar, "Connection", "СОЕДИНЕНИЕ...", UDim2.fromOffset(49, 0), UDim2.fromOffset(140, 38), 11, C.muted, true)
	local rateLabel = label(topbar, "Rate", "ДОХОД: —", UDim2.fromOffset(200, 0), UDim2.fromOffset(180, 38), 12, C.green, true)
	local caption = label(topbar, "Caption", "ГОРОДСКОЙ УЗЕЛ СВЯЗИ", UDim2.fromOffset(388, 0), UDim2.fromOffset(218, 38), 11, C.muted, true)
	local helpButton = button(topbar, "Help", "?", UDim2.new(1, -64, 0, 7), UDim2.fromOffset(25, 24), nil, C.paper)
	label(topbar, "Language", "RU", UDim2.new(1, -34, 0, 7), UDim2.fromOffset(28, 24), 12, C.muted, true)
	local sidebar = frame(root, "Sidebar", UDim2.fromOffset(12, 170), UDim2.fromOffset(164, 296), C.cream, 5)
	corner(sidebar, 6); stroke(sidebar, C.blue, 2)
	local menuLabel = label(sidebar, "Title", "АБОНЕНТСКИЙ ОТДЕЛ", UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 24), 9, C.blue, true)
	menuLabel.TextXAlignment = Enum.TextXAlignment.Center
	local menus = {
		{"terminal", "ТЕРМИНАЛ", C.blue}, {"collection", "НОМЕРА", C.blue}, {"profile", "ПРОФИЛЬ", C.blue},
		{"mail", "ПОЧТА", C.blue}, {"settings", "НАСТРОЙКИ", C.muted}, {"upgrades", "ПРОКАЧКА", C.purple},
		{"top", "РЕЙТИНГ", C.gold},
	}
	local menuButtons = {}
	for index, data in ipairs(menus) do
		local b = button(sidebar, data[1], "", UDim2.fromOffset(0, 0), UDim2.fromOffset(72, 76), function() if data[1] == "profile" then profilePlayer = player end; showPage(data[1]) end, C.paper)
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
	local terminalButton = button(hud, "Terminal", "ПК", UDim2.fromOffset(7, 7), UDim2.fromOffset(82, 50), function() if expanded then setExpanded(false) else showPage("terminal") end end, C.green, 9)
	terminalButton.TextColor3 = Color3.new(1, 1, 1); terminalButton.TextSize = 21
	label(hud, "BalanceTitle", "ЛИЦЕВОЙ СЧЁТ", UDim2.fromOffset(106, 7), UDim2.fromOffset(200, 16), 10, C.muted, true, 9)
	local balanceLabel = label(hud, "Balance", "Загрузка...", UDim2.fromOffset(105, 22), UDim2.fromOffset(250, 32), 26, C.ink, true, 9)
	local capacityButton = label(hud, "Collection", "SIM: 0/25", UDim2.new(1, -246, 0, 8), UDim2.fromOffset(116, 47), 14, C.blue, true, 9)
	local subscribers = button(hud, "Subscribers", "Абоненты", UDim2.new(1, -122, 0, 8), UDim2.fromOffset(112, 47), function() rosterPreference = not roster.Visible; roster.Visible = rosterPreference end, C.pale, 9)
	local window = frame(root, "Window", UDim2.new(0.5, -340, 0.5, -260), UDim2.fromOffset(680, 520), C.cream, 10)
	corner(window, 5); stroke(window, C.blue, 3)
	local header = frame(window, "TitleBar", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 38), C.blue, 11)
	gradient(header, C.blueLight, C.blue)
	local headerIcon = icon(header, "terminal", Color3.new(1, 1, 1)); headerIcon.Position = UDim2.fromOffset(10, 9)
	create("UIScale", headerIcon, {Scale = 0.52})
	local windowTitle = label(header, "Title", "NUMBER RUSH — ТЕРМИНАЛ", UDim2.fromOffset(49, 0), UDim2.new(1, -125, 1, 0), 16, Color3.new(1, 1, 1), true, 12)
	button(header, "Maximize", "[]", UDim2.new(1, -62, 0, 7), UDim2.fromOffset(24, 24), function() maximized = not maximized; layoutDesktop() end, C.blueLight, 12).TextColor3 = Color3.new(1, 1, 1)
	button(header, "Close", "X", UDim2.new(1, -31, 0, 7), UDim2.fromOffset(24, 24), function() setExpanded(false) end, C.red, 12).TextColor3 = Color3.new(1, 1, 1)
	local body = frame(window, "Body", UDim2.fromOffset(14, 50), UDim2.new(1, -28, 1, -84), C.cream, 11)
	local status = label(window, "Status", "Подключение к станции...", UDim2.new(0, 15, 1, -28), UDim2.new(1, -30, 0, 24), 11, C.muted, false, 12)
	local pages = {}
	for _, key in ipairs({"terminal", "collection", "upgrades", "top", "profile", "mail", "settings"}) do
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
			local height = game:GetService("TextService"):GetTextSize(value, 15, Enum.Font.Arial, Vector2.new(math.max(240, modalContent.AbsoluteSize.X - 12), 10000)).Y + 6
			local t = label(modalContent, "Paragraph", value, UDim2.fromOffset(0, y), UDim2.new(1, -8, 0, height), 15, C.ink, false, 27)
			t.TextYAlignment = Enum.TextYAlignment.Top; y = y + height + 10
		end
		modalContent.CanvasSize = UDim2.fromOffset(0, y)
	end
	progress.Send = function(action, key, level)
		if progress.Busy or progress.Uncertain or spinBusy or slotBusy or player:GetAttribute("DataReady") ~= true then return end
		progress.Auto = false; progress.Busy = true; refreshControls(); progress.Render()
		progress.Request:FireServer(action, key, level)
		task.delay(45, function()
			if progress.Busy and gui.Parent then progress.Uncertain = true; status.Text = "Сохранение задерживается. Переподключитесь для проверки операции."; refreshControls() end
		end)
	end
	progress.ConfirmSale = function(item)
		if not item or progress.Busy or spinBusy or slotBusy then return end
		progress.Auto = false
		information("Продажа номера", {item.DisplayNumber, "Вы получите " .. money(item.SalePrice) .. " ₽. Номер будет удалён из коллекции."})
		modalContent.Size = UDim2.new(1, -36, 1, -110)
		modalAction.Text = "Продать за " .. money(item.SalePrice) .. " ₽"; modalAction.Visible = true
		modalActionCallback = function() modal.Visible = false; progress.Send("Sell", item.IssuanceId) end
		refreshControls()
	end
	helpButton.Activated:Connect(function()
		window.Visible = true
		information("СПРАВОЧНАЯ УЗЛА СВЯЗИ", {
			"Выберите оператора и регион. Код подберёт станция. Шансы одинаковы везде; доплата за крупный город не гарантирует редкость.",
			"Список номеров — красивые SIM-карточки, поиск, редкость и сортировка. Кнопка на карточке открывает установку в доходные слоты.",
			"Слоты меняются без ожидания. «Закрепить лучшее» выбирает максимальный доход, затем стоимость. Последний занятый слот снять нельзя.",
			"Прокачка расширяет хранилище и доходные линии, повышает удачу и скорость. Ненужные номера можно продать из списка с подтверждением.",
		})
	end)
	-- Generator: same server request sequence and existing economic offers.
	local generator = pages.terminal
	label(generator, "Section", "ВЫДАЧА АБОНЕНТСКИХ НОМЕРОВ", UDim2.fromOffset(0, 0), UDim2.new(1, -90, 0, 22), 11, C.muted, true)
	button(generator, "Probabilities", "Шансы", UDim2.new(1, -82, 0, -2), UDim2.fromOffset(82, 26), function()
		local weights, total = UpgradeRules.Weights(Config.Profiles.Regional.Weights, player:GetAttribute("UpgradeLuck") or 0)
		local lines = {selectedOffer.Region .. " · " .. money(selectedOffer.Price) .. " ₽ за попытку. Шансы учитывают вашу прокачку удачи и одинаковы во всех регионах."}
		for i, weight in ipairs(weights) do
			local percent = string.format("%.5f", weight * 100 / total):gsub("0+$", ""):gsub("%.$", ""):gsub("%.", ",")
			table.insert(lines, Config.Rarities[i].Name .. ": " .. percent .. "%")
		end
		information("ВЕРОЯТНОСТИ ВЫДАЧИ", lines)
	end)
	local operatorButtons = {}
	local selectOperator, selectOffer
	for i, op in ipairs(Config.Operators) do
		operatorButtons[i] = button(generator, op.Id, op.Name, UDim2.new((i - 1) / 4, 0, 0, 32), UDim2.new(0.25, -6, 0, 32), function() if not spinBusy then selectOperator(i) end end, C.paper)
	end
	local codeButton = button(generator, "CodeSelector", "Выбрать регион", UDim2.fromOffset(0, 74), UDim2.new(1, -94, 0, 36), nil, C.paper)
	progress.ToggleAuto = function()
		if progress.Auto then progress.Auto = false; refreshControls(); return end
		if (player:GetAttribute("UpgradeAuto") or 0) < 1 then showPage("upgrades"); return end
		if progress.Busy or progress.Uncertain then return end
		progress.Auto = true; refreshControls()
	end
	progress.AutoButton = button(generator, "AutoToggle", "Авто: выкл", UDim2.new(1, -106, 0, 74), UDim2.fromOffset(106, 36), progress.ToggleAuto, C.pale)
	codeButton.Size = UDim2.new(1, -114, 0, 36)
	local ticket = frame(generator, "NumberCard", UDim2.fromOffset(0, 122), UDim2.new(1, 0, 1, -250), C.paper)
	corner(ticket, 5); stroke(ticket)
	local ticketStroke = ticket:FindFirstChildOfClass("UIStroke")
	local operatorRibbon = frame(ticket, "OperatorColor", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 5), C.blue, 3)
	local punch = frame(ticket, "SIMChip", UDim2.fromOffset(18, 18), UDim2.fromOffset(34, 27), Color3.fromRGB(221, 188, 103), 3)
	corner(punch, 4); stroke(punch, C.gold)
	for i = 1, 2 do frame(punch, "Contact", UDim2.new(i / 3, 0, 0, 0), UDim2.new(0, 1, 1, 0), C.gold, 4) end
	frame(punch, "Contact", UDim2.new(0, 0, 0.5, 0), UDim2.new(1, 0, 0, 1), C.gold, 4)
	local ticketBrand = label(ticket, "Operator", "БиЛайнк / АБОНЕНТСКАЯ КАРТОЧКА", UDim2.fromOffset(65, 18), UDim2.new(1, -78, 0, 28), 11, C.muted, true)
	local number = label(ticket, "Number", "+7 (903) •••-••-••", UDim2.new(0, 14, 0.34, 0), UDim2.new(1, -28, 0, 52), 32, C.ink, true)
	number.Font = Enum.Font.Code; number.TextXAlignment = Enum.TextXAlignment.Center
	local resultDetails = label(ticket, "Details", "Все шесть редкостей · единые шансы", UDim2.new(0, 16, 1, -58), UDim2.new(1, -32, 0, 38), 13, C.muted)
	resultDetails.TextXAlignment = Enum.TextXAlignment.Center
	local spinButton = button(generator, "SpinButton", "ПОЛУЧИТЬ НОМЕР", UDim2.new(0, 0, 1, -66), UDim2.new(1, 0, 0, 43), nil, C.green)
	spinButton.TextColor3 = Color3.new(1, 1, 1); spinButton.TextSize = 17
	progress.SellResult = button(generator, "SellResult", "Продать номер", UDim2.new(0, 0, 1, -105), UDim2.new(1, 0, 0, 30), function() progress.ConfirmSale(lastItem) end, C.paper)
	progress.SellResult.Visible = false
	local generatorNote = label(generator, "Timing", "Одна SIM-карта · 6 секунд · оплата только на сервере", UDim2.new(0, 0, 1, -18), UDim2.new(1, 0, 0, 18), 10, C.muted)
	local regionPopup = frame(generator, "RegionPopup", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), C.paper, 15)
	stroke(regionPopup, C.blue, 2); corner(regionPopup, 4); regionPopup.Visible = false
	local regionSearch = textbox(regionPopup, "Search", "Регион или город...", UDim2.fromOffset(12, 12), UDim2.new(1, -55, 0, 32))
	regionSearch.ZIndex = 16
	button(regionPopup, "Close", "X", UDim2.new(1, -34, 0, 16), UDim2.fromOffset(24, 24), function() regionPopup.Visible = false end, C.cream, 17)
	local regionList = scroll(regionPopup, "Regions", UDim2.fromOffset(12, 53), UDim2.new(1, -24, 1, -62)); regionList.ZIndex = 16; listLayout(regionList, 6)
	local function renderRegions()
		clear(regionList)
		local query = fold(regionSearch.Text)
		for _, offer in ipairs(Config.GetRegionOffers(Config.Operators[selectedOperator].Id)) do
			if query == "" or string.find(fold(offer.Region), query, 1, true) then
				local b = button(regionList, offer.Id, "", UDim2.fromOffset(0, 0), UDim2.new(1, -8, 0, 58), function() selectOffer(offer); regionPopup.Visible = false end, C.cream, 17)
				badge(b, "Kind", offer.Kind == "City" and "ГОРОД" or "РЕГИОН", 10, 17, 65, C.pale).ZIndex = 18
				label(b, "Region", offer.Region, UDim2.fromOffset(86, 6), UDim2.new(1, -192, 0, 25), 14, C.ink, true, 18)
				label(b, "Profile", "Код подберёт станция", UDim2.fromOffset(86, 30), UDim2.new(1, -190, 0, 18), 11, C.muted, false, 18)
				local price = label(b, "Price", money(offer.Price) .. " ₽", UDim2.new(1, -100, 0, 14), UDim2.fromOffset(90, 30), 14, C.blue, true, 18)
				price.TextXAlignment = Enum.TextXAlignment.Right
			end
		end
	end
	selectOffer = function(offer)
		if spinBusy then return end
		selectedOffer = offer
		local info = Config.OperatorById[offer.OperatorId]
		codeButton.Text = offer.Region .. "  ·  " .. money(offer.Price) .. " ₽  v"
		if not lastItem then
			ticketBrand.Text = info.Name .. " / АБОНЕНТСКАЯ КАРТОЧКА"
			number.Text = "+7 (9••) •••-••-••"
			operatorRibbon.BackgroundColor3 = info.ThemeColor; ticketStroke.Color = info.ThemeColor
		end
		if not lastItem then resultDetails.Text = "Все шесть редкостей · единые шансы" end
		refreshControls()
	end
	selectOperator = function(index)
		selectedOperator = index
		for i, b in ipairs(operatorButtons) do
			b.BackgroundColor3 = Config.Operators[i].ThemeColor; b.TextColor3 = Config.Operators[i].TextColor
			stroke(b, i == index and C.ink or C.line, i == index and 2 or 1)
		end
		local preferred = Config.ResolveRegion(Config.Operators[index].Id, selectedOffer.Id) or Config.GetDefaultOffer(Config.Operators[index].Id)
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
	label(cardsPane, "CardTip", "SIM-карты · цвет рамки показывает редкость", UDim2.new(0, 188, 0, 40), UDim2.new(1, -188, 0, 27), 11, C.muted)
	local cards = scroll(cardsPane, "Cards", UDim2.fromOffset(0, 77), UDim2.new(1, 0, 1, -77))
	local cardGrid = create("UIGridLayout", cards, {CellSize = UDim2.new(0.5, -7, 0, 210), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder})
	create("UIPadding", cards, {PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 5), PaddingBottom = UDim.new(0, 6)})
	local emptyCards = label(cardsPane, "Empty", "", UDim2.fromOffset(18, 100), UDim2.new(1, -36, 0, 110), 17, C.muted)
	emptyCards.TextXAlignment = Enum.TextXAlignment.Center; emptyCards.Visible = false
	local slotsPane = frame(collection, "SlotsPane", UDim2.fromOffset(0, 42), UDim2.new(1, 0, 1, -42)); slotsPane.BackgroundTransparency = 1; slotsPane.Visible = false
	local slotSelection = label(slotsPane, "Selection", "Выберите SIM-карту в коллекции для установки.", UDim2.fromOffset(0, 0), UDim2.new(1, -110, 0, 36), 13, C.ink)
	local slotRefresh = button(slotsPane, "Refresh", "Обновить", UDim2.new(1, -100, 0, 0), UDim2.fromOffset(100, 32), function() requestSlots("GetState") end, C.paper)
	local equipBest = button(slotsPane, "EquipBest", "ЗАКРЕПИТЬ ЛУЧШЕЕ · МАКСИМАЛЬНЫЙ ДОХОД", UDim2.fromOffset(0, 41), UDim2.new(1, 0, 0, 33), function() requestSlots("EquipBest") end, C.pale)
	local slotRows = scroll(slotsPane, "Slots", UDim2.fromOffset(0, 84), UDim2.new(1, 0, 1, -122)); listLayout(slotRows, 9)
	label(slotsPane, "Rule", "Замена без ожидания · последний источник дохода защищён", UDim2.new(0, 0, 1, -30), UDim2.new(1, 0, 0, 28), 11, C.muted)
	local slotTimers = {}
	local function displayItem(item)
		lastItem = item
		local brand = Config.OperatorById[item.OperatorId]
		operatorRibbon.BackgroundColor3 = brand and brand.ThemeColor or C.blue
		ticket.BackgroundColor3 = (brand and brand.ThemeColor or C.blue):Lerp(C.paper, 0.96)
		ticketStroke.Color = rarityColors[item.RarityIndex or 1] or C.line; ticketStroke.Thickness = 2
		ticketStroke.Thickness = 4
		TweenService:Create(ticketStroke, TweenInfo.new(0.55), {Thickness = 2}):Play()
		number.TextTransparency = 0.35
		TweenService:Create(number, TweenInfo.new(0.28), {TextTransparency = 0}):Play()
		punch.Rotation = -6
		TweenService:Create(punch, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Rotation = 0}):Play()
		number.Text = item.DisplayNumber or "+7 (---) --- -- --"
		number.TextColor3 = rarityColors[item.RarityIndex or 1] or C.ink
		ticketBrand.Text = (item.OperatorName or "NUMBER RUSH") .. " / " .. (item.Region or "КОЛЛЕКЦИЯ")
		resultDetails.Text = (item.RarityName or "") .. "  ·  Оценка " .. money(item.SalePrice) .. " ₽\nВ слоте: " .. money(item.IncomePerHour) .. " ₽/ч"
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
				local brand = Config.OperatorById[item.OperatorId]
				local primary = brand and brand.ThemeColor or C.blue
				local card = frame(cards, item.IssuanceId, UDim2.fromOffset(0, 0), UDim2.fromOffset(280, 210), primary:Lerp(C.paper, 0.96))
				card.LayoutOrder = shown; corner(card, 5); stroke(card, color, 2)
				frame(card, "Stripe", UDim2.fromOffset(7, 34), UDim2.new(0, 4, 0, 32), primary, 4)
				label(card, "Rarity", item.RarityName or "", UDim2.fromOffset(12, 7), UDim2.new(0.57, -12, 0, 21), 10, color, true, 4)
				local value = label(card, "Price", money(item.SalePrice) .. " ₽", UDim2.new(0.57, 0, 0, 7), UDim2.new(0.43, -12, 0, 21), 12, C.ink, true, 4); value.TextXAlignment = Enum.TextXAlignment.Right
				local sim = icon(card, "collection", primary); sim.Position = UDim2.fromOffset(16, 34); create("UIScale", sim, {Scale = 0.55})
				label(card, "Operator", item.OperatorName or "", UDim2.fromOffset(48, 34), UDim2.new(1, -58, 0, 17), 12, primary == Config.Operators[1].ThemeColor and C.ink or primary, true, 4)
				label(card, "Region", item.Region or "", UDim2.fromOffset(48, 51), UDim2.new(1, -58, 0, 20), 10, C.muted, false, 4)
				local phone = label(card, "Number", item.DisplayNumber or "", UDim2.fromOffset(12, 77), UDim2.new(1, -24, 0, 27), cards.AbsoluteSize.X < 560 and 16 or 20, C.ink, true, 4)
				phone.Font = Enum.Font.Code
				label(card, "Income", money(item.IncomePerHour) .. " ₽/ч в слоте", UDim2.fromOffset(12, 108), UDim2.new(1, -24, 0, 20), 12, C.green, true, 4)
				local digits = label(card, "Digits", string.format("Цифры ×%.3f", item.DigitMultiplier or 1), UDim2.fromOffset(12, 139), UDim2.new(0.48, -12, 0, 25), 12, C.green, true, 4)
				local tip = frame(card, "PriceTip", UDim2.fromOffset(10, 46), UDim2.new(1, -20, 0, 80), C.cream, 8); corner(tip, 4); stroke(tip, color); tip.Visible = false
				label(tip, "Formula", string.format("Цифры ×%.2f\nСерия ×%.2f\nСовпадение ×%.2f", item.DigitMultiplier or 1, item.PrestigeMultiplier or 1, item.CodeMatchMultiplier or 1), UDim2.fromOffset(9, 5), UDim2.new(1, -18, 1, -10), 12, C.ink, false, 9)
				digits.MouseEnter:Connect(function() tip.Visible = true end)
				digits.MouseLeave:Connect(function() tip.Visible = false end)
				button(card, "Assign", item.Location == "IncomeSlot" and ("Слот №" .. tostring(item.IncomeSlotIndex)) or "В доход", UDim2.new(0.51, 0, 0, 137), UDim2.new(0.49, -12, 0, 27), function()
					selectedItemId = item.IssuanceId; setCollectionMode("slots")
				end, C.pale, 5)
				local sell = button(card, "Sell", item.Location == "IncomeSlot" and "Установлен · продажа недоступна" or ("Продать за " .. money(item.SalePrice) .. " ₽"), UDim2.fromOffset(12, 174), UDim2.new(1, -24, 0, 26), function()
					if progress.Busy or spinBusy or slotBusy then return end
					information("ПРОДАЖА НОМЕРА", {item.DisplayNumber, "Вы получите " .. money(item.SalePrice) .. " ₽. Номер исчезнет из коллекции и станет доступен для новой выдачи. Отменить продажу нельзя."})
					modalContent.Size = UDim2.new(1, -36, 1, -110)
					modalAction.Text = "Подтвердить продажу · " .. money(item.SalePrice) .. " ₽"; modalAction.Visible = true
					modalActionCallback = function() modal.Visible = false; progress.Send("Sell", item.IssuanceId) end
				end, C.cream, 5)
				enabled(sell, item.Location == "Inventory" and not progress.Busy and not progress.Uncertain)
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
		slotSelection.Text = item and ("Выбрано: " .. item.DisplayNumber) or "Нажмите «В доход» на нужной SIM-карте."
		enabled(slotRefresh, not slotBusy and player:GetAttribute("DataReady") == true)
		enabled(equipBest, slotState ~= nil and not slotBusy and not spinBusy and not slotUncertain and player:GetAttribute("DataReady") == true)
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
		if not connected or progress.Busy or progress.Uncertain or slotBusy or player:GetAttribute("DataReady") ~= true then return end
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
		if mode == "slots" then renderSlots(); requestSlots("GetState") else cards.CanvasPosition = Vector2.zero; renderCollection(); status.Text = "Ваши SIM-карты · поиск, сортировка и доходные линии" end
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
	-- Only implemented branches are visible in the first release.
	do
	local upgrades = pages.upgrades
	local intro = frame(upgrades, "Intro", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 68), C.pale)
	corner(intro, 4); stroke(intro)
	local art = icon(intro, "upgrades", C.blue); art.Position = UDim2.fromOffset(12, 8)
	label(intro, "Title", "Модернизация узла связи", UDim2.fromOffset(66, 7), UDim2.new(1, -78, 0, 26), 19, C.blue, true)
	label(intro, "Hint", "Постоянные улучшения за игровые рубли", UDim2.fromOffset(66, 35), UDim2.new(1, -78, 0, 25), 12, C.ink)
	local tree = scroll(upgrades, "UpgradeTree", UDim2.fromOffset(0, 80), UDim2.new(1, 0, 1, -80)); listLayout(tree, 10)
	local colors = {Storage = C.blue, Slots = C.green, Luck = C.purple, Speed = C.gold, Auto = C.blue}
	progress.Render = function()
		clear(tree)
		for order, key in ipairs(UpgradeRules.Order) do
			local branch = UpgradeRules.Branches[key]
			local level = player:GetAttribute("Upgrade" .. key) or 0
			local price = branch.Prices[level + 1]
			local levels = {}; for _, k in ipairs(UpgradeRules.Order) do levels[k] = player:GetAttribute("Upgrade" .. k) or 0 end
			local locked = price and UpgradeRules.Requirement(levels, key)
			local row = frame(tree, key, UDim2.fromOffset(0, 0), UDim2.new(1, -9, 0, 148), C.paper)
			row.LayoutOrder = order; corner(row, 5); stroke(row, colors[key])
			local i = icon(row, branch.Icon, colors[key]); i.Position = UDim2.fromOffset(12, 12)
			label(row, "Title", branch.Name, UDim2.fromOffset(70, 9), UDim2.new(1, -145, 0, 27), 17, colors[key], true)
			local rank = label(row, "Level", level .. "/" .. #branch.Prices, UDim2.new(1, -66, 0, 12), UDim2.fromOffset(54, 24), 14, colors[key], true); rank.TextXAlignment = Enum.TextXAlignment.Right
			label(row, "Current", UpgradeRules.Description(key, level), UDim2.fromOffset(70, 39), UDim2.new(1, -82, 0, 22), 13, C.ink)
			label(row, "Next", locked or price and ("Далее: " .. UpgradeRules.Description(key, level + 1)) or "Все ступени приобретены", UDim2.fromOffset(14, 77), UDim2.new(1, -28, 0, 23), 12, C.muted)
			for step = 1, #branch.Prices do
				local pip = frame(row, "Step" .. step, UDim2.fromOffset(16 + (step - 1) * 15, 116), UDim2.fromOffset(10, 10), step <= level and colors[key] or C.cream); corner(pip, 2); stroke(pip)
			end
			local buy = button(row, "Buy", progress.Busy and "Сохранение..." or price and ("Улучшить · " .. money(price) .. " ₽") or "Максимум", UDim2.new(0.5, 0, 0, 105), UDim2.new(0.5, -14, 0, 32), function()
				information(branch.Name, {UpgradeRules.Description(key, level) .. " → " .. UpgradeRules.Description(key, math.min(level + 1, #branch.Prices)), "Стоимость: " .. money(price) .. " ₽. Улучшение сохранится после выхода из игры."})
				modalContent.Size = UDim2.new(1, -36, 1, -110)
				modalAction.Text = "Купить за " .. money(price) .. " ₽"; modalAction.Visible = true
				modalActionCallback = function() modal.Visible = false; progress.Send("Buy", key, level) end
			end, price and C.pale or C.cream)
			enabled(buy, not locked and price ~= nil and not progress.Busy and not progress.Uncertain and not spinBusy and not slotBusy and player:GetAttribute("DataReady") == true and balanceValue ~= nil and balanceValue.Value >= (price or 0))
		end
	end
	end
	-- Current-server ranking, explicitly distinguished from the future global leaderboard.
	local rankingMode = "balance"
	local top = pages.top
	local topButtons = {}
	for i, data in ipairs({{"balance", "БАЛАНС"}, {"collection", "КОЛЛЕКЦИЯ"}}) do
		topButtons[data[1]] = button(top, data[1], data[2], UDim2.fromOffset((i - 1) * 148, 0), UDim2.fromOffset(140, 33), function() rankingMode = data[1]; renderTop() end)
	end
	label(top, "Scope", "Рейтинг игроков текущего сервера", UDim2.fromOffset(0, 43), UDim2.new(1, 0, 0, 27), 12, C.muted)
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
			local row = button(rosterList, "Player" .. p.UserId, "", UDim2.fromOffset(0, 0), UDim2.new(1, -7, 0, 38), function() profilePlayer = p; showPage("profile") end, C.paper)
			corner(row, 4)
			local initials = label(row, "Avatar", p.DisplayName:sub(1, 2), UDim2.fromOffset(4, 4), UDim2.fromOffset(30, 30), 14, C.blue, true)
			initials.TextXAlignment = Enum.TextXAlignment.Center
			label(row, "Name", p.DisplayName, UDim2.fromOffset(40, 3), UDim2.new(1, -46, 0, 32), 11, p == player and C.blue or C.ink, true)
		end
	end
	-- Public profile is assembled from the server's replicated folders, never fabricated totals.
	local profileContent = scroll(pages.profile, "Profile", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1))
	renderProfile = function()
		clear(profileContent)
		local p = profilePlayer
		if not p or p.Parent ~= Players then
			label(profileContent, "Unavailable", "Абонент отключился от сервера.", UDim2.fromOffset(10, 10), UDim2.new(1, -20, 0, 70), 17, C.muted); return
		end
		local items, total, best = {}, 0, nil
		local inv = p:FindFirstChild("NumberInventory")
		if inv then for _, entry in inv:GetChildren() do
			local item = entry:GetAttributes()
			if type(item.SalePrice) == "number" then
				total = total + item.SalePrice; table.insert(items, item)
				if not best or item.SalePrice > best.SalePrice or (item.SalePrice == best.SalePrice and (item.FullNumber or "") < (best.FullNumber or "")) then best = item end
			end
		end end
		local head = frame(profileContent, "Identity", UDim2.fromOffset(3, 3), UDim2.new(1, -10, 0, 94), C.paper)
		corner(head, 5); stroke(head, C.blue)
		local avatar = create("ImageLabel", head, {Name = "Avatar", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(70, 70), BackgroundColor3 = C.pale, BorderSizePixel = 0, ZIndex = 4})
		corner(avatar, 7)
		task.spawn(function()
			local ok, url = pcall(function() return Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150) end)
			if ok and avatar.Parent then avatar.Image = url end
		end)
		label(head, "Name", p.DisplayName, UDim2.fromOffset(94, 8), UDim2.new(1, -110, 0, 30), 23, C.blue, true)
		label(head, "Username", "@" .. p.Name, UDim2.fromOffset(94, 40), UDim2.new(1, -110, 0, 20), 13, C.muted)
		label(head, "Public", "АБОНЕНТ В СЕТИ · ОТКРЫТЫЙ ПРОФИЛЬ", UDim2.fromOffset(94, 65), UDim2.new(1, -110, 0, 19), 10, C.green, true)
		for i, data in ipairs({{"Баланс", playerBalance(p) and money(playerBalance(p)) .. " ₽" or "Загрузка..."}, {"Стоимость номеров", money(total) .. " ₽"}, {"Номеров", tostring(#items)}, {"Попыток выдачи", tostring(math.max(0, (p:GetAttribute("NextSpinSequence") or 1) - 1))}}) do
			local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
			local tile = frame(profileContent, "Stat" .. i, UDim2.new(col * 0.5, 3, 0, 108 + row * 76), UDim2.new(0.5, -9, 0, 66), C.paper)
			corner(tile, 4); stroke(tile)
			label(tile, "Caption", data[1], UDim2.fromOffset(12, 7), UDim2.new(1, -24, 0, 20), 12, C.muted)
			label(tile, "Value", data[2], UDim2.fromOffset(12, 27), UDim2.new(1, -24, 0, 32), 20, C.blue, true)
		end
		local showcase = frame(profileContent, "BestNumber", UDim2.fromOffset(3, 266), UDim2.new(1, -10, 0, 108), C.paper)
		corner(showcase, 4); stroke(showcase, C.gold)
		label(showcase, "Caption", "ЛУЧШИЙ НОМЕР · ПО ОЦЕНОЧНОЙ СТОИМОСТИ", UDim2.fromOffset(13, 7), UDim2.new(1, -26, 0, 22), 10, C.gold, true)
		label(showcase, "Number", best and best.DisplayNumber or "Пока нет номеров", UDim2.fromOffset(13, 33), UDim2.new(1, -26, 0, 33), 24, C.ink, true).Font = Enum.Font.Code
		label(showcase, "Value", best and ((best.RarityName or "") .. " · " .. money(best.SalePrice) .. " ₽") or "Получите номер в терминале", UDim2.fromOffset(13, 72), UDim2.new(1, -26, 0, 26), 13, C.muted)
		label(profileContent, "SlotTitle", "НОМЕРА НА ДОХОДНЫХ ЛИНИЯХ", UDim2.fromOffset(6, 389), UDim2.new(1, -16, 0, 26), 12, C.blue, true)
		local y = 423
		local publicSlots = p:FindFirstChild("IncomeSlots")
		if publicSlots then for _, slot in publicSlots:GetChildren() do
			local phone = slot:GetAttribute("DisplayNumber")
			if phone then
				label(profileContent, "IncomeLine", "№" .. slot.Name .. "  " .. phone .. "  ·  " .. money(slot:GetAttribute("IncomePerHour")) .. " ₽/ч", UDim2.fromOffset(12, y), UDim2.new(1, -24, 0, 35), 15, C.ink)
				y = y + 41
			end
		end end
		profileContent.CanvasSize = UDim2.fromOffset(0, y + 12)
	end
	do
	local mail = pages.mail
	local mailNews, mailRewards
	local mailContent = scroll(mail, "Messages", UDim2.fromOffset(0, 45), UDim2.new(1, 0, 1, -45))
	local function renderMail(rewards, activeArticle)
		clear(mailContent)
		mailNews.BackgroundColor3 = rewards and C.cream or C.pale; mailRewards.BackgroundColor3 = rewards and C.pale or C.cream
		mailContent.CanvasPosition = Vector2.zero
		if rewards then
			label(mailContent, "Title", "СИСТЕМНЫЕ НАГРАДЫ", UDim2.fromOffset(12, 12), UDim2.new(1, -24, 0, 50), 22, C.blue, true)
			label(mailContent, "Body", "Наград к получению пока нет.\n\nСистема выдачи подарков ещё не подключена.", UDim2.fromOffset(12, 79), UDim2.new(1, -24, 0, 180), 16, C.ink).TextYAlignment = Enum.TextYAlignment.Top
			mailContent.CanvasSize = UDim2.fromOffset(0, 270); return
		end
		local y = 3
		for i, article in ipairs(News) do
			button(mailContent, article.Id, article.Title .. "\n" .. article.Date, UDim2.fromOffset(3, y), UDim2.new(1, -10, 0, 60), function() renderMail(false, i) end, i == (activeArticle or 1) and C.pale or C.paper)
			y = y + 72
			if i == (activeArticle or 1) then
				local height = game:GetService("TextService"):GetTextSize(article.Body, 15, Enum.Font.Arial, Vector2.new(math.max(260, mailContent.AbsoluteSize.X - 30), 10000)).Y + 12
				local text = label(mailContent, "ArticleBody", article.Body, UDim2.fromOffset(12, y), UDim2.new(1, -30, 0, height), 15, C.ink)
				text.TextYAlignment = Enum.TextYAlignment.Top; y = y + height + 16
			end
		end
		mailContent.CanvasSize = UDim2.fromOffset(0, y + 8)
	end
	mailNews = button(mail, "News", "НОВОСТИ", UDim2.fromOffset(0, 0), UDim2.fromOffset(140, 32), function() renderMail(false) end, C.pale)
	mailRewards = button(mail, "Rewards", "НАГРАДЫ", UDim2.fromOffset(148, 0), UDim2.fromOffset(140, 32), function() renderMail(true) end)
	mailRewards.Visible = false
	renderMail(false)
	end
	do
	local settingsList = scroll(pages.settings, "Options", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1))
	local draggingSlider, sliders = nil, {}
	local function volumeControl(name, captionText, y, initial)
		local group = SoundService:FindFirstChild("NumberRush" .. name)
		if not group then group = Instance.new("SoundGroup"); group.Name = "NumberRush" .. name; group.Volume = initial; group.Parent = SoundService end
		local row = frame(settingsList, name, UDim2.fromOffset(3, y), UDim2.new(1, -10, 0, 85), C.paper); corner(row, 4); stroke(row)
		label(row, "Caption", captionText, UDim2.fromOffset(14, 8), UDim2.new(1, -80, 0, 26), 16, C.blue, true)
		local value = label(row, "Value", "", UDim2.new(1, -68, 0, 8), UDim2.fromOffset(54, 26), 15, C.ink, true)
		local track = frame(row, "Track", UDim2.fromOffset(16, 53), UDim2.new(1, -32, 0, 8), C.cream, 4); corner(track, 4); track.Active = true
		local fill = frame(track, "Fill", UDim2.fromOffset(0, 0), UDim2.fromScale(group.Volume, 1), C.blueLight, 5); corner(fill, 4)
		local knob = button(track, "Knob", "", UDim2.new(group.Volume, -9, 0.5, -9), UDim2.fromOffset(18, 18), nil, C.paper, 6); corner(knob, 9)
		local function update(x)
			local v = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
			group.Volume = v; fill.Size = UDim2.fromScale(v, 1); knob.Position = UDim2.new(v, -9, 0.5, -9); value.Text = math.floor(v * 100 + 0.5) .. "%"
		end
		value.Text = math.floor(group.Volume * 100 + 0.5) .. "%"
		track.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = name; update(input.Position.X) end end)
		knob.MouseButton1Down:Connect(function() draggingSlider = name end)
		sliders[name] = update
	end
	volumeControl("Music", "МУЗЫКА", 3, 0.6); volumeControl("Effects", "ЗВУКИ ИГРЫ", 99, 1)
	UserInputService.InputChanged:Connect(function(input) if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then sliders[draggingSlider](input.Position.X) end end)
	UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = nil end end)
	label(settingsList, "AudioNote", "Громкость сохраняется до выхода из игры. Музыкальное сопровождение ещё не добавлено.", UDim2.fromOffset(6, 194), UDim2.new(1, -16, 0, 52), 12, C.muted)
	settingsList.CanvasSize = UDim2.fromOffset(0, 250)
	end
	-- The compact terminal mirrors the same labels and invokes the same request function.
	local compact = frame(root, "CompactTerminal", UDim2.new(0.5, -310, 1, -182), UDim2.fromOffset(620, 98), C.cream, 22)
	corner(compact, 5); stroke(compact, C.blue, 2); compact.Visible = false
	local miniNumber = label(compact, "Number", number.Text, UDim2.fromOffset(15, 25), UDim2.new(1, -182, 0, 34), 24, C.ink, true, 23); miniNumber.Font = Enum.Font.Code
	local miniOffer = label(compact, "Offer", "", UDim2.fromOffset(15, 5), UDim2.new(1, -55, 0, 20), 11, C.blue, true, 23)
	local miniStatus = label(compact, "Status", "", UDim2.fromOffset(15, 64), UDim2.new(1, -182, 0, 25), 11, C.muted, false, 23)
	local miniSpin = button(compact, "Spin", "КРУТИТЬ", UDim2.new(1, -156, 0, 31), UDim2.fromOffset(140, 48), function() if beginSpin then beginSpin() end end, C.green, 23); miniSpin.TextColor3 = Color3.new(1, 1, 1)
	progress.MiniAuto = button(compact, "AutoToggle", "Авто: выкл", UDim2.new(1, -156, 0, 3), UDim2.fromOffset(108, 24), progress.ToggleAuto, C.pale, 24); progress.MiniAuto.TextSize = 11
	button(compact, "Expand", "↑", UDim2.new(1, -38, 0, 3), UDim2.fromOffset(30, 24), function() setExpanded(true); showPage("terminal") end, C.pale, 24)
	number:GetPropertyChangedSignal("Text"):Connect(function() miniNumber.Text = number.Text end)
	number:GetPropertyChangedSignal("TextColor3"):Connect(function() miniNumber.TextColor3 = number.TextColor3 end)
	number:GetPropertyChangedSignal("TextTransparency"):Connect(function() miniNumber.TextTransparency = number.TextTransparency end)
	status:GetPropertyChangedSignal("Text"):Connect(function()
		miniStatus.Text = spinBusy and status.Text or lastItem and ((lastItem.RarityName or "") .. " · оценка " .. money(lastItem.SalePrice) .. " ₽") or "Одна выдача · один платёж"
	end)
	setExpanded = function(value)
		expanded = value; wallpaper.Visible = value; sidebar.Visible = true; topbar.Visible = value; window.Visible = value
		compact.Visible = not value
		if not value then roster.Visible = false end
		root:SetAttribute("Expanded", value)
		if layoutDesktop then layoutDesktop() end
	end
	-- Desktop routing and viewport layout: no changes to Roblox's native player list.
	local pageTitles = {terminal = "ТЕРМИНАЛ ВЫДАЧИ", collection = "СПИСОК НОМЕРОВ", upgrades = "ПРОКАЧКА", trade = "ТОРГИ", quests = "ЗАДАНИЯ", top = "РЕЙТИНГ", shop = "МАГАЗИН", profile = "ПРОФИЛЬ АБОНЕНТА", boosts = "ИНВЕНТАРЬ БУСТОВ", mail = "ПОЧТА", settings = "НАСТРОЙКИ"}
	showPage = function(key)
		if key == "terminal" then
			if not expanded then setExpanded(true) end
		else
			if expanded then setExpanded(false) end
			compact.Visible = false
		end
		modal.Visible = false; regionPopup.Visible = false; currentPage = key; window.Visible = true
		windowTitle.Text = "NUMBER RUSH — " .. pageTitles[key]
		for name, page in pairs(pages) do page.Visible = name == key end
		for i, data in ipairs(menus) do menuButtons[i].BackgroundColor3 = data[1] == key and C.pale or C.paper; menuButtons[i].BackgroundTransparency = 0 end
		if key == "collection" then cards.CanvasPosition = Vector2.zero; renderCollection(); if collectionMode == "slots" then requestSlots("GetState") end end
		if key == "upgrades" then progress.Render() end
		if key == "top" then renderTop() end
		if key == "profile" then renderProfile() end
		local pageStatus = {terminal = "Выберите оператора и регион. Цена указана до оплаты.", collection = "Ваши номера · данные получены с сервера", top = "Актуальные данные игроков текущего сервера", profile = "Открытый профиль · реальные данные текущего сервера", upgrades = "Постоянные улучшения · покупки сохраняются в профиле", settings = "Громкость звука в текущей сессии", mail = "Новости NUMBER RUSH", boosts = "Инвентарь только для бустов · выдача усилений ещё не подключена"}
		status.Text = pageStatus[key] or "Предварительный просмотр · этот раздел ещё не подключён"
	end
	layoutDesktop = function()
		local size = root.AbsoluteSize; local narrow = size.X < 1050
		local sideWidth = 164
		sidebar.Size = UDim2.fromOffset(sideWidth, 295)
		sidebar.Position = UDim2.fromOffset(10, math.max(53, (size.Y - 295) / 2 - 15))
		sidebar.BackgroundTransparency = 0.05; sidebar:FindFirstChildOfClass("UIStroke").Transparency = 0
		menuLabel.Visible = false
		for i, b in ipairs(menuButtons) do
			b.Position = UDim2.fromOffset(4 + ((i - 1) % 2) * 79, 5 + math.floor((i - 1) / 2) * 71)
			b.Size = UDim2.fromOffset(75, 68)
			b.Caption.Position = UDim2.fromOffset(0, 46); b.Caption.Size = UDim2.new(1, 0, 0, 20)
			b.Caption.TextSize = 10; b.Caption.TextColor3 = C.ink; b.Caption.TextStrokeTransparency = 1
			b.Icon.Position = UDim2.new(0.5, -24, 0, 0)
			b.BackgroundColor3 = menus[i][1] == currentPage and C.pale or C.paper; b.BackgroundTransparency = 0
			b:FindFirstChildOfClass("UIStroke").Transparency = 0.5
		end
		roster.Visible = expanded and (rosterPreference == nil and size.X >= 1250 or rosterPreference == true)
		local left = sideWidth + 28; local right = roster.Visible and size.X >= 1250 and 194 or 16
		local width = math.min(700, size.X - left - right)
		local height = math.min(620, size.Y - 128)
		window.Size = UDim2.fromOffset(math.max(350, width), math.max(360, height))
		window.Position = UDim2.fromOffset(left + math.max(0, (size.X - left - right - width) / 2), 54)
		if maximized then width = size.X - 32; height = size.Y - 120; window.Size = UDim2.fromOffset(width, height); window.Position = UDim2.fromOffset(16, 50) end
		roster.Position = UDim2.new(1, -180, 0, 60)
		topbar.Size = UDim2.fromOffset(math.min(690, size.X - 28), 38)
		topbar.Position = UDim2.new(0.5, -topbar.Size.X.Offset / 2, 0, 8)
		caption.Visible = size.X >= 760
		rateLabel.Position = UDim2.fromOffset(size.X < 760 and 180 or 200, 0)
		rateLabel.Size = UDim2.fromOffset(size.X < 760 and 165 or 180, 38)
		hud.Size = UDim2.fromOffset(math.min(620, size.X - 24), 64)
		hud.Position = UDim2.new(0.5, -hud.Size.X.Offset / 2, 1, -76)
		if expanded then hud.Size = UDim2.new(1, 0, 0, 58); hud.Position = UDim2.new(0, 0, 1, -58) end
		compact.Size = UDim2.fromOffset(math.min(620, size.X - 24), 98); compact.Position = UDim2.new(0.5, -compact.Size.X.Offset / 2, 1, -182)
		if not expanded and size.X < 950 then compact.Size = UDim2.fromOffset(math.max(350, size.X - 200), 98); compact.Position = UDim2.new(1, -compact.Size.X.Offset - 10, 1, -182) end
		balanceLabel.Size = UDim2.new(1, -460, 0, 32)
		balanceLabel.TextSize = size.X < 700 and 22 or 26
		local oneColumn = width < 480
		cardGrid.CellSize = oneColumn and UDim2.new(1, -12, 0, 210) or UDim2.new(0.5, -7, 0, 210)
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
	local dragOrigin, dragPosition
	header.Active = true
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not maximized then dragOrigin = input.Position; dragPosition = window.Position end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragOrigin and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragOrigin
			local x = math.clamp(dragPosition.X.Offset + delta.X, 0, math.max(0, root.AbsoluteSize.X - window.AbsoluteSize.X))
			local y = math.clamp(dragPosition.Y.Offset + delta.Y, 45, math.max(45, root.AbsoluteSize.Y - 60 - window.AbsoluteSize.Y))
			window.Position = UDim2.fromOffset(x, y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragOrigin = nil end end)
	refreshControls = function()
		local serverSequence = player:GetAttribute("NextSpinSequence")
		if type(serverSequence) == "number" then nextSequence = math.max(nextSequence, serverSequence) end
		local ready = player:GetAttribute("DataReady") == true
		connection.Text = ready and "ЛИНИЯ ПОДКЛЮЧЕНА" or "СОЕДИНЕНИЕ..."; connection.TextColor3 = ready and C.green or C.muted
		local income = player:GetAttribute("IncomeEnabled") == true
		rateLabel.Text = income and ("ДОХОД: " .. money(player:GetAttribute("TotalBaseIncomePerHour")) .. " ₽/ч") or "ДОХОД НЕАКТИВЕН"
		capacityButton.Text = "SIM: " .. tostring(player:GetAttribute("InventoryCount") or #currentItems) .. "/" .. tostring(player:GetAttribute("InventoryCapacity") or Config.StartingInventoryCapacity)
		local count = player:GetAttribute("InventoryCount") or 0
		local capacity = player:GetAttribute("InventoryCapacity") or Config.StartingInventoryCapacity
		local ownedResult = nil
		for _, item in ipairs(currentItems) do if lastItem and item.IssuanceId == lastItem.IssuanceId then ownedResult = item end end
		progress.SellResult.Visible = ownedResult ~= nil
		progress.SellResult.Text = ownedResult and (ownedResult.Location == "Inventory" and ("Продать за " .. money(ownedResult.SalePrice) .. " ₽") or "Номер установлен в доходный слот") or "Номер продан"
		enabled(progress.SellResult, ownedResult ~= nil and ownedResult.Location == "Inventory" and not spinBusy and not slotBusy and not progress.Busy and not progress.Uncertain)
		local canSpin = connected and ready and not spinBusy and not slotBusy and not progress.Busy and not progress.Uncertain and balanceValue ~= nil and nextSequence >= 1 and balanceValue.Value >= selectedOffer.Price and count < capacity
		-- Keep buttons stable under the mouse while income updates the balance.
		for _, key in ipairs(UpgradeRules.Order) do
			local row = pages.upgrades.UpgradeTree:FindFirstChild(key)
			if row then
				local price = UpgradeRules.Branches[key].Prices[(player:GetAttribute("Upgrade" .. key) or 0) + 1]
				local levels = {}; for _, k in ipairs(UpgradeRules.Order) do levels[k] = player:GetAttribute("Upgrade" .. k) or 0 end
				enabled(row.Buy, not UpgradeRules.Requirement(levels, key) and price ~= nil and ready and not spinBusy and not slotBusy and not progress.Busy and not progress.Uncertain and balanceValue ~= nil and balanceValue.Value >= (price or 0))
			end
		end
		if progress.Auto and (not ready or progress.Uncertain or balanceValue == nil or balanceValue.Value < selectedOffer.Price or count >= capacity) then progress.Auto = false end
		progress.AutoButton.Text = (player:GetAttribute("UpgradeAuto") or 0) < 1 and "Открыть авто" or progress.Auto and "Авто: вкл" or "Авто: выкл"
		progress.AutoButton.BackgroundColor3 = progress.Auto and C.green or C.pale
		progress.AutoButton.TextColor3 = progress.Auto and Color3.new(1, 1, 1) or C.ink
		progress.MiniAuto.Text = progress.AutoButton.Text
		progress.MiniAuto.BackgroundColor3 = progress.AutoButton.BackgroundColor3
		progress.MiniAuto.TextColor3 = progress.AutoButton.TextColor3
		generatorNote.Text = string.format("Одна SIM-карта · %.2f сек. · удача ×%.3f", UpgradeRules.Duration(Config.SpinDuration, player:GetAttribute("UpgradeSpeed") or 0), 1 + 0.015 * (player:GetAttribute("UpgradeLuck") or 0))
		enabled(spinButton, canSpin == true)
		enabled(miniSpin, canSpin == true)
		miniSpin.Text = spinBusy and "ВЫДАЧА..." or (money(selectedOffer.Price) .. " ₽\nКРУТИТЬ")
		miniOffer.Text = selectedOffer.OperatorName .. " · " .. selectedOffer.Region
		spinButton.Text = spinBusy and "ПОЛУЧАЕМ НОМЕР..." or count >= capacity and "КОЛЛЕКЦИЯ ЗАПОЛНЕНА" or ("ПОЛУЧИТЬ · " .. money(selectedOffer.Price) .. " ₽")
		for _, b in ipairs(operatorButtons) do enabled(b, not spinBusy) end
		enabled(codeButton, not spinBusy)
		if balanceValue then
			balanceLabel.Text = money(balanceValue.Value) .. " ₽"
			local measured = game:GetService("TextService"):GetTextSize(balanceLabel.Text, 26, Enum.Font.ArialBold, Vector2.new(10000, 100)).X
			balanceLabel.TextSize = math.clamp(math.floor(26 * math.max(20, balanceLabel.AbsoluteSize.X - 4) / math.max(1, measured)), 16, 26)
		end
	end
	progress.Result.OnClientEvent:Connect(function(packet)
		if type(packet) ~= "table" then return end
		progress.Busy = false; progress.Uncertain = false
		status.Text = packet.Status == "Success" and (packet.Action == "Sell" and ("Номер продан за " .. money(packet.Amount) .. " ₽") or "Улучшение приобретено и сохранено.") or packet.Message or "Операция завершена."
		progress.Render(); renderCollection(); refreshControls()
	end)
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
						local phase = os.clock() - startedAt
						punch.Rotation = math.sin(phase * 7) * 3
						number.TextTransparency = 0.05 + math.abs(math.sin(phase * 5)) * 0.12
						local codes = selectedOffer.Codes
						number.Text = string.format("+7 (%s) %03d-%02d-%02d", codes[visualRandom:NextInteger(1, #codes)], visualRandom:NextInteger(0, 999), visualRandom:NextInteger(0, 99), visualRandom:NextInteger(0, 99))
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
			punch.Rotation = 0; number.TextTransparency = 0
			if packet.Status == "Success" and packet.Item then
				displayItem(packet.Item); status.Text = "Номер выдан и сохранён. Откройте коллекцию для установки в слот."
			elseif packet.Status == "Cancelled" then
				number.Text = "Выдача отменена"; resultDetails.Text = "Стоимость возвращена"; status.Text = packet.Reason or "Повторите попытку."
			else status.Text = packet.Message or "Не удалось получить номер." end
			if packet.Status ~= "Success" then progress.Auto = false end
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
	beginSpin = function()
		if not spinButton.Interactable or spinBusy or not connected then return end
		spinBusy = true; spinStarted = false; activeSequence = nextSequence; regionPopup.Visible = false
		local operatorId, regionId, sequence = selectedOffer.OperatorId, selectedOffer.Id, activeSequence
		local brand = Config.OperatorById[operatorId]
		ticketBrand.Text = brand.Name .. " / " .. selectedOffer.Region
		operatorRibbon.BackgroundColor3 = brand.ThemeColor; ticketStroke.Color = brand.ThemeColor
		resultDetails.Text = "Запрос отправлен на станцию"; number.TextColor3 = C.ink
		status.Text = "Подключаемся к оператору..."; refreshControls()
		requestRemote:FireServer(operatorId, regionId, sequence)
		task.delay(60, function()
			if spinBusy and activeSequence == sequence then
				animationToken = animationToken + 1
				status.Text = "Выдача задерживается. Дождитесь ответа или переподключитесь."
			end
		end)
	end
	spinButton.Activated:Connect(beginSpin)
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
	for _, attr in ipairs({"DataReady", "NextSpinSequence", "InventoryCount", "InventoryCapacity", "IncomeEnabled", "TotalBaseIncomePerHour", "UpgradeStorage", "UpgradeSlots", "UpgradeLuck", "UpgradeSpeed", "UpgradeAuto"}) do
		player:GetAttributeChangedSignal(attr):Connect(function()
			refreshControls()
			if attr:sub(1, 7) == "Upgrade" or attr == "DataReady" then progress.Render() end
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
			if currentPage == "profile" and window.Visible and profilePlayer and profilePlayer.Parent == Players then
				local tile = profileContent:FindFirstChild("Stat1")
				local text = tile and tile:FindFirstChild("Value")
				if text then local amount = playerBalance(profilePlayer); text.Text = amount and money(amount) .. " ₽" or "Загрузка..." end
			end
		end
	end)
	task.spawn(function()
		while gui.Parent do
			task.wait(0.5)
			if progress.Auto and not spinBusy and not slotBusy and not progress.Busy and not progress.Uncertain then
				refreshControls()
				if progress.Auto and spinButton.Interactable then beginSpin() end
			end
		end
	end)
	selectOperator(1); renderPlayers(); renderTop(); renderCollection(); refreshControls(); showPage("terminal")
	window.BackgroundTransparency = 1
	TweenService:Create(window, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
end

return DesktopUI
