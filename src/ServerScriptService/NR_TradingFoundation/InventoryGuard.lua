-- Read-only ownership and availability checks. No client-supplied item attributes are trusted.
local Guard = {}
local blocked = {IncomeSlot=true, MarketEscrow=true, AuctionEscrow=true, TradeEscrow=true, Craft=true}
function Guard.Check(session, issuanceId)
 if type(session) ~= "table" or type(session.Data) ~= "table" or type(session.Data.Inventory) ~= "table" then return nil,"InvalidSession" end
 if type(issuanceId) ~= "string" or #issuanceId < 1 or #issuanceId > 128 then return nil,"InvalidIssuanceId" end
 local item = session.Data.Inventory[issuanceId]
 if type(item) ~= "table" then return nil,"NotOwned" end
 if item.IssuanceId ~= issuanceId then return nil,"InventoryCorrupt" end
 if blocked[item.Location] then return nil,"ItemLocked" end
 if item.Location ~= nil and item.Location ~= "Inventory" then return nil,"UnknownLocation" end
 if type(item.FullNumber) ~= "string" or not item.FullNumber:match("^79%d%d%d%d%d%d%d%d%d$") then return nil,"InvalidNumber" end
 return item
end
function Guard.Count(session)
 local n=0
 for _ in pairs(session.Data.Inventory) do n+=1 end
 return n
end
return Guard
