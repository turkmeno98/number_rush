-- Edit-only: exact OfficeService, cloned scene and fake Players; no DataStore.
return function(source, scene)
	local function signal()
		local callbacks={}
		return {Connect=function(_,fn) local c={Active=true};function c:Disconnect() self.Active=false end;table.insert(callbacks,{c,fn});return c end,
			Fire=function(_,...) for _,v in ipairs(callbacks) do if v[1].Active then v[2](...) end end end}
	end
	local function player(id)
		local attrs,signals={},{}
		local p={UserId=id,Name="Test"..id,DisplayName="Test"..id,CharacterAdded=signal(),ChildAdded=signal()}
		function p:GetAttribute(k) return attrs[k] end
		function p:SetAttribute(k,v) attrs[k]=v;if signals[k] then signals[k]:Fire() end end
		function p:GetAttributeChangedSignal(k) signals[k]=signals[k] or signal();return signals[k] end
		function p:FindFirstChild() return nil end
		return p
	end
	local list={};for i=1,6 do list[i]=player(i) end
	local service={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function() return list end}
	local copy=scene:Clone()
	local fn=assert(loadstring(source))
	setfenv(fn,setmetatable({game={GetService=function() return service end},script={Parent={WaitForChild=function(_,n) return n end}},require=function() return {Build=function() return copy end} end},{__index=getfenv()}))
	local ok,err=pcall(function()
		fn()
		local used={};for _,p in ipairs(list) do local i=p:GetAttribute("OfficeIndex");assert(i and not used[i]);used[i]=true;assert(copy["Cabinet"..i]:GetAttribute("OwnerUserId")==p.UserId) end
		service.PlayerRemoving:Fire(list[3]);assert(copy.Cabinet3:GetAttribute("OwnerUserId")==nil)
		local newcomer=player(10);service.PlayerAdded:Fire(newcomer);assert(newcomer:GetAttribute("OfficeIndex")==3)
		service.PlayerAdded:Fire(newcomer);assert(newcomer:GetAttribute("OfficeIndex")==3)
	end)
	copy:Destroy();assert(ok,err)
	return {uniqueAssignments=6,release=true,reuse=true,repeatJoin=true}
end
