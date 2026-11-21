-- NUMBER RUSH v0.6: durable PREPARATION records only.
-- No live listings, ownership transfer, currency debit, or escrow.
local DSS = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local storeName = RunService:IsStudio() and "NR_ListingRecords_DEV_v1" or "NR_ListingRecords_LIVE_v1"
local store = DSS:GetDataStore(storeName)
local Records = {}
local PREFIX = "Listing_"
local MAX_PRICE = 1000000000000
local MAX_TTL = 300
local function validId(id)
    return type(id) == "string" and #id >= 8 and #id <= 100
        and id:match("^[%w%-]+$") ~= nil
end
local function copy(record)
    if type(record) ~= "table" then return nil end
    local result = {}
    for k, v in pairs(record) do
        if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
            result[k] = v
        end
    end
    return result
end
local function read(id)
    if not validId(id) then return nil, "InvalidId" end
    local ok, result = pcall(function() return store:GetAsync(PREFIX .. id) end)
    if not ok then return nil, "StorageError", tostring(result) end
    if result == nil then return nil, "NotFound" end
    if type(result) ~= "table" or result.SchemaVersion ~= 1
        or result.ListingId ~= id then return nil, "InvalidRecord" end
    return copy(result)
end
function Records.NewId()
    return HttpService:GenerateGUID(false)
end
function Records.Prepare(id, ownerId, issuanceId, fullNumber, price, ttlSeconds)
    if not validId(id) or type(ownerId) ~= "number" or ownerId < 1
        or ownerId % 1 ~= 0 or type(issuanceId) ~= "string"
        or #issuanceId < 1 or #issuanceId > 128
        or type(fullNumber) ~= "string" or #fullNumber ~= 11
        or not fullNumber:match("^79%d+$")
        or type(price) ~= "number" or price % 1 ~= 0
        or price < 1 or price > MAX_PRICE
        or type(ttlSeconds) ~= "number" or ttlSeconds % 1 ~= 0
        or ttlSeconds < 1 or ttlSeconds > MAX_TTL then
        return nil, "InvalidArguments"
    end
    local now = os.time()
    local proposed = {SchemaVersion = 1, ListingId = id, State = "Prepared",
        OwnerId = ownerId, IssuanceId = issuanceId,
        FullNumber = fullNumber, Price = price,
        CreatedAt = now, ExpiresAt = now + ttlSeconds, UpdatedAt = now}
    local ok, result = pcall(function()
        return store:UpdateAsync(PREFIX .. id, function(old)
            if old ~= nil then return old end
            return proposed
        end)
    end)
    if not ok then return nil, "StorageError", tostring(result) end
    if type(result) ~= "table" or result.SchemaVersion ~= 1
        or result.ListingId ~= id then return nil, "InvalidRecord" end
    if result.OwnerId ~= ownerId or result.IssuanceId ~= issuanceId
        or result.FullNumber ~= fullNumber or result.Price ~= price then
        return nil, "IdConflict"
    end
    if result.State ~= "Prepared" then return nil, "AlreadyFinalized" end
    return copy(result)
end
function Records.Get(id)
    local record, err, detail = read(id)
    if not record then return nil, err, detail end
    record.IsExpired = record.ExpiresAt <= os.time()
    return record
end
function Records.Cancel(id, ownerId)
    if not validId(id) or type(ownerId) ~= "number" or ownerId % 1 ~= 0 then
        return nil, "InvalidArguments"
    end
    local reason = "Rejected"
    local ok, result = pcall(function()
        return store:UpdateAsync(PREFIX .. id, function(old)
            if old == nil then reason = "NotFound"; return nil end
            if type(old) ~= "table" or old.SchemaVersion ~= 1
                or old.ListingId ~= id then reason = "InvalidRecord"; return nil end
            if old.OwnerId ~= ownerId then reason = "NotOwner"; return nil end
            if old.State == "Cancelled" then return old end
            if old.State ~= "Prepared" then reason = "InvalidState"; return nil end
            local nextRecord = table.clone(old)
            nextRecord.State = "Cancelled"
            nextRecord.UpdatedAt = os.time()
            return nextRecord
        end)
    end)
    if not ok then return nil, "StorageError", tostring(result) end
    if result == nil then return nil, reason end
    if type(result) ~= "table" or result.State ~= "Cancelled"
        or result.OwnerId ~= ownerId then return nil, "InvalidRecord" end
    return copy(result)
end
function Records.Status()
    return {Ready = true, Durable = true, TradingEnabled = false,
        PublicListingsEnabled = false, SettlementEnabled = false,
        Store = storeName}
end
return Records
