-- Edit-only runner: exact SpinService with controlled I/O, no real DataStore.
return function(Cases)
	local function copy(t) if type(t)~="table" then return t end local r={} for k,v in pairs(t) do r[k]=copy(v) end return r end
	local IO={Copy=copy,Records={},Serial=0}
	local Store={Save=function(s)
		s.Writes=(s.Writes or 0)+1
		if s.FailSave or s.FailAt==s.Writes then
			if s.FailMode=="after" then s.Durable=copy(s.Data) end
			return false,"unknown outcome"
		end
		s.Durable=copy(s.Data);return true
	end}
	local Generator={Rarity=1}
	function Generator.RollRarity(_,weights) Generator.LastWeights=weights;return Generator.Rarity end
	function Generator.GenerateDigits() IO.Serial+=1;return string.format("%07d",5831946+IO.Serial) end
	local Registry={Occupied=0}
	function Registry.Reserve(full,user,op)
		if Registry.Occupied>0 or IO.OccupySecond and op:match(":2$") then Registry.Occupied=math.max(0,Registry.Occupied-1);return nil,"Occupied" end
		local old=IO.Records[full]
		if old then if old.OperationId==op then return copy(old) end;return nil,"Occupied" end
		local r={IssuanceId=game:GetService("HttpService"):GenerateGUID(false),Generation=1,OperationId=op,OwnerId=user,State="Reserved"}
		IO.Records[full]=r
		if IO.LoseSecond and op:match(":2$") then IO.LoseSecond=false;return nil,"StorageError" end
		return copy(r)
	end
	function Registry.Confirm(full,user,op) local r=IO.Records[full];assert(r and r.OwnerId==user and r.OperationId==op);r.State="Owned";return copy(r) end
	local modules={PlayerDataStore=Store,NumberGenerator=Generator,NumberRegistry=Registry,RegionCatalog=require(game.ReplicatedStorage.RegionCatalog)}
	local fakeGame={GetService=function(_,name) if name=="ReplicatedStorage" then return {WaitForChild=function(_,n) return n end} end;return game:GetService(name) end}
	local function module(name,obj)
		local fn=assert(loadstring(game:GetService("ScriptEditorService"):GetEditorSource(obj)))
		setfenv(fn,setmetatable({game=fakeGame,script={Parent={WaitForChild=function(_,n) return n end}},require=function(n) return assert(modules[n],n) end},{__index=getfenv()}))
		modules[name]=fn();return modules[name]
	end
	local Config=module("GameConfig",game.ReplicatedStorage.GameConfig);Config.SpinDuration=0
	module("UpgradeConfig",game.ReplicatedStorage.UpgradeConfig)
	module("NumberRules",game.ServerScriptService.NumberRules)
	module("NumberEconomy",game.ServerScriptService.NumberEconomy)
	local Service=module("SpinService",game.ServerScriptService.SpinService)
	return Cases(Service,Config,Generator,Registry,IO)
end
