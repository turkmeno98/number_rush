-- NUMBER RUSH v0.7 / PersistentListingClaim
-- Per-item claim coordinator ONLY. Not escrow or a trading engine.
local DSS = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local name = RunService:IsStudio() and "NR_ListingClaims_DEV_v1" or "NR_ListingClaims_LIVE_v1"
local store = DSS:GetDataStore(name)
local Claim = {}
local MAX_TTL = 300
local function validGuid(s)
    return type(s) == "string" and #s >= 8 and #s <= 100
        and s:match("^[%w%-]+$") ~= nil
end
local function validUser(n)
    return type(n) == "number" and n > 0 and n % 1 == 0
end
local function key(issuanceId)
    return "Item_" .. issuanceId
end
local function readCopy(r)
    if type(r) ~= "table" then return nil end
    return {
        SchemaVersion = r.SchemaVersion, IssuanceId = r.IssuanceId,
        ListingId = r.ListingId, OwnerId = r.OwnerId,
        ExpiresAt = r.ExpiresAt, UpdatedAt = r.UpdatedAt,
        State = r.State
    }
end
function Claim.Acquire(issuanceId, listingId, ownerId, ttl)
    if not validGuid(issuanceId) or not validGuid(listingId)
        or not validUser(ownerId) or type(ttl) ~= "number"
        or ttl % 1 ~= 0 or ttl < 1 or ttl > MAX_TTL then
        return nil, "InvalidArguments"
    end
    local now = os.time()
    local desired = {SchemaVersion=1, IssuanceId=issuanceId,
        ListingId=listingId, OwnerId=ownerId, State="Claimed",
        ExpiresAt=now+ttl, UpdatedAt=now}
    local ok, result = pcall(function()
        return store:UpdateAsync(key(issuanceId), function(old)
            if old == nil then return desired end
            if type(old) ~= "table" or old.SchemaVersion ~= 1
                or old.IssuanceId ~= issuanceId then return nil end
            if old.State == "Claimed" and old.ExpiresAt > now then
                return old
            end
            -- Expired or released claims can be replaced; does NOT prove the
            -- number is still owned by this seller. Caller must revalidate.
            return desired
        end)
    end)
    if not ok then return nil, "StorageError", tostring(result) end
    if type(result) ~= "table" or result.SchemaVersion ~= 1
        or result.IssuanceId ~= issuanceId then return nil, "InvalidRecord" end
    if result.ListingId ~= listingId or result.OwnerId ~= ownerId then
        return nil, "AlreadyClaimed"
    end
    if result.State ~= "Claimed" or result.ExpiresAt <= os.time() then
        return nil, "Expired"
    end
    return readCopy(result)
end
function Claim.Get(issuanceId)
    if not validGuid(issuanceId) then return nil, "InvalidArguments" end
    local ok, result = pcall(function()
        return store:GetAsync(key(issuanceId))
    end)
    if not ok then return nil, "StorageError", tostring(result) end
    if result == nil then return {State="Free"} end
    if type(result) ~= "table" or result.SchemaVersion ~= 1
        or result.IssuanceId ~= issuanceId then return nil, "InvalidRecord" end
    local copy = readCopy(result)
    if copy.State == "Claimed" and copy.ExpiresAt <= os.time() then
        copy.State = "Expired"
    end
    return copy
end
function Claim.Release(issuanceId, listingId, ownerId)
    if not validGuid(issuanceId) or not validGuid(listingId)
        or not validUser(ownerId) then return nil, "InvalidArguments" end
    local now = os.time()
    local ok, result = pcall(function()
        return store:UpdateAsync(key(issuanceId), function(old)
            if type(old) ~= "table" or old.SchemaVersion ~= 1
                or old.IssuanceId ~= issuanceId then return nil end
            if old.ListingId ~= listingId or old.OwnerId ~= ownerId then
                return nil
            end
            if old.State == "Released" then return old end
            if old.State ~= "Claimed" then return nil end
            local updated = table.clone(old)
            updated.State = "Released"
            updated.UpdatedAt = now
            return updated
        end)
    end)
    if not ok then return nil, "StorageError", tostring(result) end
    if type(result) ~= "table" or result.ListingId ~= listingId
        or result.OwnerId ~= ownerId or result.State ~= "Released" then
        return nil, "NotOwnerOrNotFound"
    end
    return readCopy(result)
end
function Claim.Status()
    return {Ready=true, Persistent=true, TradingEnabled=false,
        EscrowEnabled=false, Store=name}
end
return Claim
