-- Reproducible, asset-free scene. Build in Edit or at startup if the scene is absent.
local Scene = {}
function Scene.Build()
	if workspace:FindFirstChild("NumberRushOffice") then return workspace.NumberRushOffice end
	local root = Instance.new("Model"); root.Name = "NumberRushOffice"
	local C = {cream=Color3.fromRGB(224,219,195), blue=Color3.fromRGB(32,79,133), green=Color3.fromRGB(68,109,86), wood=Color3.fromRGB(158,113,72), dark=Color3.fromRGB(42,49,57), white=Color3.fromRGB(240,237,214), metal=Color3.fromRGB(111,121,128)}
	local function part(parent,name,size,pos,color,material)
		local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=CFrame.new(pos);p.Anchored=true;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
	end
	local function sign(p,value,face)
		local gui=Instance.new("SurfaceGui");gui.Name="Display";gui.Face=face or Enum.NormalId.Front;gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=40;gui.Parent=p
		local t=Instance.new("TextLabel");t.Name="Text";t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Text=value;t.TextColor3=C.white;t.Font=Enum.Font.ArialBold;t.TextScaled=true;t.TextWrapped=true;t.Parent=gui
		local pad=Instance.new("UIPadding");pad.PaddingTop=UDim.new(0,7);pad.PaddingBottom=UDim.new(0,7);pad.PaddingLeft=UDim.new(0,9);pad.PaddingRight=UDim.new(0,9);pad.Parent=t
	end
	local function prompt(p,page,index)
		p:SetAttribute("OfficePage",page);p:SetAttribute("OfficeIndex",index)
		local q=Instance.new("ProximityPrompt");q.Name="OfficePrompt";q.ActionText=page=="terminal" and "Включить ПК" or page=="collection" and "Открыть SIM-бокс" or "Доходные линии";q.ObjectText="Кабинет "..index;q.MaxActivationDistance=8;q.RequiresLineOfSight=false;q.HoldDuration=0
		q.KeyboardKeyCode=page=="terminal" and Enum.KeyCode.E or page=="collection" and Enum.KeyCode.F or Enum.KeyCode.G;q.Parent=p
	end
	local shell=Instance.new("Model");shell.Name="Building";shell.Parent=root
	part(shell,"Foundation",Vector3.new(76,1,92),Vector3.new(0,-0.5,0),C.dark,Enum.Material.Concrete)
	part(shell,"HallFloor",Vector3.new(16,0.5,88),Vector3.new(0,0.25,0),C.cream,Enum.Material.Marble)
	for z=-42,42,3 do
		part(shell,"FloorInlay",Vector3.new(0.14,0.02,2.8),Vector3.new(-6,0.51,z),C.blue)
		part(shell,"FloorInlay",Vector3.new(0.14,0.02,2.8),Vector3.new(6,0.51,z),C.blue)
	end
	part(shell,"BackWall",Vector3.new(74,11,0.5),Vector3.new(0,5.5,44),C.cream)
	for _,x in ipairs({-24,24}) do part(shell,"EntranceWall",Vector3.new(24,11,0.5),Vector3.new(x,5.5,-44),C.cream) end
	part(shell,"EntranceLintel",Vector3.new(24,2,0.5),Vector3.new(0,10,-44),C.blue)
	part(shell,"Ceiling",Vector3.new(74,0.4,88),Vector3.new(0,11.2,0),C.white)
	for _,x in ipairs({-6,6}) do
		local door=part(shell,"EntranceDoor",Vector3.new(11.8,9,0.45),Vector3.new(x,4.5,-44),Color3.fromRGB(153,193,207),Enum.Material.Glass);door.Transparency=0.3
		part(shell,"DoorBottom",Vector3.new(11.8,1.5,0.55),Vector3.new(x,0.75,-44),C.blue)
		part(shell,"DoorHandle",Vector3.new(0.2,1.5,0.3),Vector3.new(x>0 and 1 or -1,4,-43.6),C.metal,Enum.Material.Metal)
	end
	for _,x in ipairs({-12,0,12}) do part(shell,"EntranceFrame",Vector3.new(0.3,9,0.6),Vector3.new(x,4.5,-44),C.blue) end
	local outside=Instance.new("Model");outside.Name="Grounds";outside.Parent=root
	part(outside,"Lawn",Vector3.new(108,0.3,120),Vector3.new(0,-0.6,0),Color3.fromRGB(74,124,58),Enum.Material.Grass)
	part(outside,"EntryPath",Vector3.new(18,0.2,16),Vector3.new(0,-0.3,-52),C.cream,Enum.Material.Pavement)
	for _,x in ipairs({-53,53}) do
		for z=-60,60,8 do part(outside,"FencePost",Vector3.new(0.35,4,0.35),Vector3.new(x,1.5,z),C.dark,Enum.Material.Metal) end
		for _,y in ipairs({0.8,2.8}) do part(outside,"FenceRail",Vector3.new(0.2,0.2,120),Vector3.new(x,y,0),C.dark,Enum.Material.Metal) end
	end
	for _,z in ipairs({-60,60}) do
		for x=-52,52,8 do part(outside,"FencePost",Vector3.new(0.35,4,0.35),Vector3.new(x,1.5,z),C.dark,Enum.Material.Metal) end
		for _,y in ipairs({0.8,2.8}) do part(outside,"FenceRail",Vector3.new(106,0.2,0.2),Vector3.new(0,y,z),C.dark,Enum.Material.Metal) end
	end
	local petals={Color3.fromRGB(236,157,46),Color3.fromRGB(204,78,118),Color3.fromRGB(144,113,199),C.white}
	for _,x in ipairs({-43,43}) do for _,z in ipairs({-24,0,24}) do
		part(outside,"FlowerBed",Vector3.new(6,0.8,13),Vector3.new(x,0,z),C.wood,Enum.Material.Wood)
		part(outside,"Soil",Vector3.new(5.6,0.1,12.6),Vector3.new(x,0.45,z),Color3.fromRGB(75,54,34),Enum.Material.Ground)
		for k=1,10 do
			local pos=Vector3.new(x+(k%2==0 and 1.4 or -1.4),0.9,z-5+math.floor((k-1)/2)*2.5)
			part(outside,"Stem",Vector3.new(0.1,0.8,0.1),pos,C.green)
			local f=part(outside,"Flower",Vector3.new(0.9,0.5,0.9),pos+Vector3.new(0,0.5,0),petals[(k%4)+1]);f.Shape=Enum.PartType.Ball
		end
	end end
	local title=part(shell,"FacadeSign",Vector3.new(35,3,0.3),Vector3.new(0,8,-44.4),C.blue)
	sign(title,"NUMBER RUSH\nГОРОДСКОЙ УЗЕЛ СВЯЗИ")
	local welcome=part(shell,"HallSign",Vector3.new(12,3,0.4),Vector3.new(0,7.5,43.5),C.blue)
	sign(welcome,"АБОНЕНТСКИЙ ОТДЕЛ\n6 кабинетов · ваш номер — ваша история")
	for z=-36,36,12 do
		local lamp=part(shell,"HallLight",Vector3.new(5,0.15,1.5),Vector3.new(0,10.5,z),C.white,Enum.Material.Neon)
		local light=Instance.new("PointLight");light.Brightness=0.8;light.Range=20;light.Color=C.white;light.Parent=lamp
	end
	shell.Parent=root;root.Parent=workspace
	for i=1,6 do
		local side=i<=3 and -1 or 1;local row=(i-1)%3;local x=side*22;local z=-24+row*24
		local room=Instance.new("Model");room.Name="Cabinet"..i;room:SetAttribute("OfficeIndex",i)
		local function p(name,size,offset,color,material) return part(room,name,size,Vector3.new(x,0,z)+offset,color,material) end
		p("Floor",Vector3.new(28,0.5,23.5),Vector3.new(0,0.25,0),i%2==0 and C.green or C.blue,Enum.Material.Fabric)
		for _,dz in ipairs({-12,12}) do
			p("Partition",Vector3.new(28,10.5,0.35),Vector3.new(0,5.5,dz),C.cream)
			p("Skirting",Vector3.new(28,0.35,0.45),Vector3.new(0,0.7,dz),C.blue)
			p("WallBand",Vector3.new(28,0.2,0.4),Vector3.new(0,3.5,dz),C.green)
		end
		for _,dz in ipairs({-7.5,7.5}) do p("DoorWall",Vector3.new(0.4,10.5,9),Vector3.new(-side*14,5.5,dz),C.cream) end
		p("DoorLintel",Vector3.new(0.5,2.5,6),Vector3.new(-side*14,9.5,0),C.blue)
		for _,dz in ipairs({-3,3}) do p("DoorFrame",Vector3.new(0.7,8,0.25),Vector3.new(-side*14,4.5,dz),C.blue) end
		p("WindowLowerWall",Vector3.new(0.5,3,24),Vector3.new(side*14,2,0),C.cream)
		p("WindowUpperWall",Vector3.new(0.5,2.5,24),Vector3.new(side*14,9.75,0),C.cream)
		local glass=p("WindowGlass",Vector3.new(0.18,5,23),Vector3.new(side*14,6,0),Color3.fromRGB(155,201,219),Enum.Material.Glass);glass.Transparency=0.65
		for dz=-11,11,5.5 do p("WindowFrame",Vector3.new(0.6,5.4,0.2),Vector3.new(side*14,6,dz),C.white) end
		local name=p("OwnerSign",Vector3.new(0.3,1.5,5),Vector3.new(-side*14.4,9.7,0),C.blue);name.CanCollide=false;sign(name,"КАБИНЕТ "..i.."\nСВОБОДЕН",side<0 and Enum.NormalId.Right or Enum.NormalId.Left)
		local arrival=p("Arrival",Vector3.new(2,0.1,2),Vector3.new(-side*9,0.6,-2),C.blue);arrival.Transparency=1;arrival.CanCollide=false
		arrival.CFrame=CFrame.lookAt(arrival.Position,Vector3.new(x,arrival.Position.Y,z+2))
		p("DeskTop",Vector3.new(12,0.35,4),Vector3.new(0,3,2),C.wood,Enum.Material.Wood)
		for _,dx in ipairs({-5,5}) do for _,dz in ipairs({0.5,3.5}) do p("DeskLeg",Vector3.new(0.3,2.5,0.3),Vector3.new(dx,1.65,dz),C.metal,Enum.Material.Metal) end end
		p("Drawer",Vector3.new(2.4,2.2,3.2),Vector3.new(-4.4,1.8,2),C.cream)
		for dy=1.3,2.5,0.6 do p("DrawerHandle",Vector3.new(1,0.12,0.15),Vector3.new(-4.4,dy,0.32),C.metal) end
		p("Monitor",Vector3.new(3.2,2.7,2.4),Vector3.new(0,4.75,2.8),C.cream)
		local pc=p("PC",Vector3.new(2.7,1.9,0.08),Vector3.new(0,4.9,1.55),C.blue,Enum.Material.Neon);sign(pc,"NUMBER RUSH\nТерминал выдачи\n[ E ]");prompt(pc,"terminal",i)
		p("MonitorStand",Vector3.new(1.4,0.35,1.5),Vector3.new(0,3.4,2.6),C.cream)
		p("Keyboard",Vector3.new(3.7,0.18,1),Vector3.new(-0.4,3.28,0.55),C.cream)
		for key=1,24 do p("Key",Vector3.new(0.2,0.04,0.18),Vector3.new(-2+(key%12)*0.28,3.39,0.3+math.floor((key-1)/12)*0.3),C.white) end
		p("MousePad",Vector3.new(1.4,0.03,1.2),Vector3.new(2.7,3.2,0.7),C.blue)
		p("Mouse",Vector3.new(0.5,0.25,0.8),Vector3.new(2.7,3.35,0.7),C.cream)
		p("Tower",Vector3.new(1.5,3,2.5),Vector3.new(7,2,2.5),C.cream)
		local box=p("SIMBox",Vector3.new(2,0.65,1.6),Vector3.new(-4.6,3.55,2.5),C.green);sign(box,"SIM\nКОЛЛЕКЦИЯ");prompt(box,"collection",i)
		local seat=Instance.new("Seat");seat.Name="Chair";seat.Size=Vector3.new(2.6,0.35,2.4);seat.CFrame=CFrame.new(x,2,z-2);seat.Anchored=true;seat.Color=C.dark;seat.Material=Enum.Material.Fabric;seat.Parent=room
		p("ChairBack",Vector3.new(2.6,2.5,0.4),Vector3.new(0,3,-3.1),C.dark,Enum.Material.Fabric)
		p("ChairStem",Vector3.new(0.35,1.5,0.35),Vector3.new(0,1.2,-2),C.metal)
		p("ChairFoot",Vector3.new(3,0.2,0.35),Vector3.new(0,0.6,-2),C.dark)
		p("ChairFoot",Vector3.new(0.35,0.2,3),Vector3.new(0,0.6,-2),C.dark)
		p("PhoneShelf",Vector3.new(23,0.3,2.4),Vector3.new(0,3.8,9),C.wood,Enum.Material.Wood)
		for line=1,5 do
			local dx=(3-line)*4.3
			local phone=p("Phone"..line,Vector3.new(3.6,1.25,1.4),Vector3.new(dx,4.55,9),C.dark);sign(phone,"ЛИНИЯ "..line.."\nНет номера");prompt(phone,"slots",i)
			p("Handset",Vector3.new(3.6,0.35,0.55),Vector3.new(dx,5.35,9.2),C.cream)
		end
		local lamp=p("CeilingLight",Vector3.new(7,0.2,2),Vector3.new(0,10.5,0),C.white,Enum.Material.Neon)
		local light=Instance.new("PointLight");light.Brightness=1;light.Range=23;light.Color=C.white;light.Parent=lamp
		p("CeilingBeam",Vector3.new(28,0.4,0.5),Vector3.new(0,10.8,0),C.white)
		room.Parent=root;task.wait()
	end
	local reception=Instance.new("Model");reception.Name="Reception";reception.Parent=root
	part(reception,"Desk",Vector3.new(11,0.4,4),Vector3.new(0,3,37),C.wood,Enum.Material.Wood)
	for _,x in ipairs({-4.5,4.5}) do part(reception,"DeskSide",Vector3.new(1,2.5,3.5),Vector3.new(x,1.6,37),C.cream) end
	local plaque=part(reception,"Nameplate",Vector3.new(5,0.8,0.3),Vector3.new(0,3.7,35),C.blue);sign(plaque,"СТАРШИЙ ОПЕРАТОР")
	part(reception,"Documents",Vector3.new(2,0.1,1.5),Vector3.new(-3,3.3,37),C.white)
	local chair=Instance.new("Seat");chair.Name="NPCSeat";chair.Size=Vector3.new(3,0.4,2.6);chair.CFrame=CFrame.new(0,2,40);chair.Anchored=true;chair.Color=C.dark;chair.Parent=reception
	part(reception,"ChairBack",Vector3.new(3,3,0.35),Vector3.new(0,3.2,41.3),C.dark)
	local description=Instance.new("HumanoidDescription");description.TorsoColor=C.blue;description.LeftLegColor=C.dark;description.RightLegColor=C.dark
	local ok,npc=pcall(function() return game:GetService("Players"):CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R6) end)
	description:Destroy()
	if ok then
		npc.Name="SeniorOperator";npc.Parent=reception;npc:PivotTo(CFrame.new(0,4,40))
		local humanoid=npc:FindFirstChildOfClass("Humanoid");humanoid.DisplayName="Старший оператор";humanoid.WalkSpeed=0;humanoid.JumpPower=0;humanoid.BreakJointsOnDeath=false
		for _,p in ipairs(npc:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end
		chair:Sit(humanoid)
	else warn("NUMBER RUSH: не удалось создать сотрудника: "..tostring(npc)) end
	local spawn=workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then spawn.CFrame=CFrame.new(0,1,-39);spawn.Size=Vector3.new(6,1,6);spawn.Transparency=1;spawn.CanCollide=false end
	return root
end
return Scene
