-- UI-only test source builder. Install the result temporarily as a ModuleScript in Edit;
-- require it on Client and call Start(). Never save/publish the temporary fixture.
return function(desktopSource)
local prefix = [====[
-- TEMPORARY UI-only test. All remote calls and balances are fake.
local realGame=game
local realPlayer=game.Players.LocalPlayer
local changed=Instance.new("BindableEvent")
local spinEvent=Instance.new("BindableEvent")
local slotEvent=Instance.new("BindableEvent")
local progressEvent=Instance.new("BindableEvent")
local log={Requests={},Counts={},Outstanding=0,MaxOutstanding=0,Mock=true}
local inv,attrs
local remotes={SpinResult={OnClientEvent=spinEvent.Event},SlotResult={OnClientEvent=slotEvent.Event},ProgressResult={OnClientEvent=progressEvent.Event}}
remotes.SlotRequest={FireServer=function() slotEvent:Fire({Status="Ready",State={Revision=0,Slots={},SlotCount=3,ActiveCount=0,TotalBaseIncomePerHour=0}}) end}
remotes.ProgressRequest={FireServer=function() error("Mock purchase disabled") end}
remotes.SpinRequest={FireServer=function(_,op,region,seq,batchCount)
 batchCount=batchCount or 1
 table.insert(log.Requests,seq);table.insert(log.Counts,batchCount);log.Outstanding+=1;log.MaxOutstanding=math.max(log.MaxOutstanding,log.Outstanding)
 spinEvent:Fire({Status="Started",Sequence=seq,Duration=0.2})
 task.delay(0.25,function()
  log.Outstanding-=1
  if #log.Requests>=3 then spinEvent:Fire({Status="Error",Sequence=seq,ErrorCode="NotEnoughMoney",Message="Тестовая остановка без списания"})
  else
   local items={}
   for i=1,batchCount do
    local item={IssuanceId="mock-"..seq.."-"..i,FullNumber="7903123456"..i,DisplayNumber="+7 (903) 123-45-6"..i,RarityIndex=i,RarityName=({"Обычный","Необычный","Редкий"})[i],SalePrice=1500*i,IncomePerHour=10000*i,OperatorId="beelink",OperatorName="БиЛайнк",Region="Тест",Location="Inventory"}
    local entry=Instance.new("Folder");entry.Name=item.IssuanceId;for k,v in pairs(item) do entry:SetAttribute(k,v) end;entry.Parent=inv;table.insert(items,item)
   end
   attrs.NextSpinSequence=seq+1;attrs.InventoryCount+=batchCount
   spinEvent:Fire({Status="Success",Sequence=seq,NextSequence=seq+1,Item=items[#items],Items=batchCount>1 and items or nil})
  end
 end)
end}
local stats=Instance.new("Folder");stats.Name="leaderstats"
local cash=Instance.new("IntValue");cash.Name="Рубли";cash.Value=100000;cash.Parent=stats
inv=Instance.new("Folder");inv.Name="NumberInventory"
attrs={UpgradeAuto=1,UpgradeBatch=2,UpgradeSpeed=4,UpgradeLuck=5,DataReady=true,NextSpinSequence=1,InventoryCount=0,InventoryCapacity=50,IncomeEnabled=true,TotalBaseIncomePerHour=30000}
local proxy=setmetatable({}, {__index=function(_,key)
 if key=="GetAttribute" then return function(_,name) if attrs[name]~=nil then return attrs[name] end return realPlayer:GetAttribute(name) end end
 if key=="GetAttributeChangedSignal" then return function() return changed.Event end end
 if key=="WaitForChild" or key=="FindFirstChild" then return function(_,name) if name=="leaderstats" then return stats elseif name=="NumberInventory" then return inv else return realPlayer:FindFirstChild(name) end end end
 if key=="ChildAdded" then return changed.Event end
 return realPlayer[key]
end})
local players={LocalPlayer=proxy,PlayerAdded=changed.Event,PlayerRemoving=changed.Event,GetPlayers=function() return {} end}
local rs={WaitForChild=function(_,name) if name=="NumberRushRemotes" then return {WaitForChild=function(_,n) return remotes[n] end} end return realGame.ReplicatedStorage:WaitForChild(name) end}
local game={GetService=function(_,name) if name=="Players" then return players elseif name=="ReplicatedStorage" then return rs else return realGame:GetService(name) end end}
]====]
return prefix .. desktopSource:gsub("return DesktopUI", "DesktopUI.AutomationLog = log\nreturn DesktopUI")
end
