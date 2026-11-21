-- Durable transaction journal foundation. Not a cross-key atomic commit engine.
local DataStoreService=game:GetService("DataStoreService")
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local name=RunService:IsStudio() and "NR_Transactions_DEV_v1" or "NR_Transactions_LIVE_v1"
local store=DataStoreService:GetDataStore(name)
local Journal={}
local function validId(id)
 return type(id)=="string" and #id>=8 and #id<=100 and id:match("^[%w%-]+$")~=nil
end
function Journal.NewId() return HttpService:GenerateGUID(false) end
function Journal.Get(id)
 if not validId(id) then return nil,"InvalidId" end
 local ok,res=pcall(function() return store:GetAsync("Tx_"..id) end)
 if not ok then return nil,"StorageError",tostring(res) end
 return res
end
function Journal.Create(id,kind,metadata)
 if not validId(id) or (kind~="Listing" and kind~="Auction" and kind~="Trade") then return nil,"InvalidArguments" end
 if type(metadata)~="table" then return nil,"InvalidMetadata" end
 -- Avoid serializing untrusted nested data in this preliminary module.
 local allowed={SellerId=true,BuyerId=true,IssuanceId=true,FullNumber=true,Price=true}
 local data={}
 for k,v in pairs(metadata) do
  if not allowed[k] or (type(v)~="string" and type(v)~="number") then return nil,"InvalidMetadata" end
  data[k]=v
 end
 local now=os.time()
 local ok,res=pcall(function()
  return store:UpdateAsync("Tx_"..id,function(old)
   if old~=nil then return old end
   return {SchemaVersion=1,Id=id,Kind=kind,State="Created",Data=data,CreatedAt=now,UpdatedAt=now}
  end)
 end)
 if not ok then return nil,"StorageError",tostring(res) end
 if res.Kind~=kind then return nil,"Conflict" end
 return res
end
function Journal.GetStatus()
 return {Ready=true,TradingEnabled=false,Message="Foundation installed; settlement not enabled"}
end
return Journal
