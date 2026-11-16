-- Cabinets are session assignments, not saved property or a new economic system.
local Players = game:GetService("Players")
local office = require(script.Parent:WaitForChild("OfficeScene")).Build()
if not office then warn("NUMBER RUSH: office scene is missing"); return end
local cabins, owners, connections = {}, {}, {}
for _, cabin in ipairs(office:GetChildren()) do
	local index = cabin:GetAttribute("OfficeIndex")
	if type(index) == "number" then cabins[index] = cabin end
end
local function text(part, value)
	local surface = part and part:FindFirstChild("Display")
	local label = surface and surface:FindFirstChild("Text")
	if label then label.Text = value end
end
local function refresh(index)
	local cabin, owner = cabins[index], owners[index]
	if not cabin then return end
	text(cabin:FindFirstChild("OwnerSign"), owner and ("КАБИНЕТ " .. index .. "\n" .. owner.DisplayName) or ("КАБИНЕТ " .. index .. "\nСВОБОДЕН"))
	local book = owner and owner:FindFirstChild("IncomeSlots")
	for i = 1, 5 do
		local record = book and book:FindFirstChild(tostring(i))
		local number = record and record:GetAttribute("DisplayNumber")
		local unlocked = owner and i <= (owner:GetAttribute("IncomeSlotCount") or 3)
		text(cabin:FindFirstChild("Phone" .. i), number and (number .. "\n" .. tostring(record:GetAttribute("IncomePerHour") or 0) .. " ₽/ч") or (unlocked and "ЛИНИЯ " .. i .. "\nНет номера" or "ЛИНИЯ " .. i .. "\nНе открыта"))
	end
end
local function assign(player)
	if player:GetAttribute("OfficeIndex") then return end
	for i = 1, 6 do
		if cabins[i] and not owners[i] then
			owners[i] = player; player:SetAttribute("OfficeIndex", i)
			local cabin = cabins[i]
			cabin:SetAttribute("OwnerUserId", player.UserId)
			local function teleport(character)
				local root = character:WaitForChild("HumanoidRootPart", 10)
				local arrival = cabin:FindFirstChild("Arrival")
				if root and arrival and owners[i] == player then character:PivotTo(arrival.CFrame + Vector3.new(0, 3, 0)) end
			end
			local list = {}
			connections[player] = list
			table.insert(list, player.CharacterAdded:Connect(teleport))
			table.insert(list, player:GetAttributeChangedSignal("SlotRevision"):Connect(function() refresh(i) end))
			table.insert(list, player:GetAttributeChangedSignal("IncomeSlotCount"):Connect(function() refresh(i) end))
			table.insert(list, player.ChildAdded:Connect(function(child) if child.Name == "IncomeSlots" then task.defer(refresh, i) end end))
			if player.Character then task.spawn(teleport, player.Character) end
			refresh(i); return
		end
	end
	warn("NUMBER RUSH: no free cabinet for " .. player.Name)
end
Players.PlayerRemoving:Connect(function(player)
	for _, c in ipairs(connections[player] or {}) do c:Disconnect() end
	connections[player] = nil
	local index = player:GetAttribute("OfficeIndex")
	if index and owners[index] == player then owners[index] = nil; cabins[index]:SetAttribute("OwnerUserId", nil); refresh(index) end
end)
Players.PlayerAdded:Connect(assign)
for i in pairs(cabins) do refresh(i) end
for _, player in ipairs(Players:GetPlayers()) do assign(player) end
