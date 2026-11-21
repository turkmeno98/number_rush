-- Exact services with in-memory I/O. Pass tests/core_progression.lua as Cases.
return function(Cases)
local source={}
for _,name in ipairs({"UpgradeConfig","UpgradeService","SaleService","NumberRegistry"}) do
 local obj=game.ReplicatedStorage:FindFirstChild(name) or game.ServerScriptService:FindFirstChild(name)
 source[name]=game:GetService("ScriptEditorService"):GetEditorSource(obj)
end

local function copy(t) if type(t)~="table" then return t end local out={} for k,v in pairs(t) do out[k]=copy(v) end return out end
local IO={Copy=copy}
function IO.Reset() IO.Records={};IO.ProfileFailAt=nil;IO.RegistryFail=false end
IO.Reset()
local profile={}
function profile.Save(s)
 s.Writes=(s.Writes or 0)+1
 if s.Writes==IO.ProfileFailAt then if s.Writes==1 then s.Durable=copy(s.Data) end return false,"unknown write" end
 s.Durable=copy(s.Data);return true
end
local raw={}
function raw:UpdateAsync(key,callback)
 local updated=callback(copy(IO.Records[key]))
 if updated then IO.Records[key]=copy(updated) end
 if IO.RegistryFail then error("lost response after registry commit") end
 return copy(updated)
end
local modules={PlayerDataStore=profile}
local fakeGame={}
function fakeGame:GetService(name)
 if name=="ReplicatedStorage" then return {WaitForChild=function(_,n) return n end} end
 if name=="DataStoreService" then return {GetDataStore=function() return raw end} end
 if name=="RunService" then return {IsStudio=function() return true end} end
 return game:GetService(name)
end
local function module(name)
 local fn=assert(loadstring(source[name]))
 local env=setmetatable({game=fakeGame,script={Parent={WaitForChild=function(_,n) return n end}},require=function(n) return assert(modules[n],n) end},{__index=getfenv()})
 setfenv(fn,env);local value=fn();modules[name]=value;return value
end
local Rules=module("UpgradeConfig");local Registry=module("NumberRegistry")
local U=module("UpgradeService");local S=module("SaleService")
return Cases(U,S,Registry,Rules,IO)
end
