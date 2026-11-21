-- Server-only, temporary locks. NOT a durable escrow or completed trade.
local HttpService = game:GetService("HttpService")
local Guard = require(script.Parent:WaitForChild("InventoryGuard"))
local Reservation = {}
local byItem, byToken = {}, {}
local MAX_SECONDS = 120

local function key(userId, issuanceId)
    return tostring(userId) .. ":" .. issuanceId
end

local function validSession(session)
    return type(session) == "table" and type(session.UserId) == "number"
        and type(session.Data) == "table" and not session.Closed
        and not session.Closing and not session.NeedsRecovery
        and type(session.LeaseUntil) == "number"
        and session.LeaseUntil > os.time() + 10
        and not session.Busy and not session.SpinBusy
        and not session.SlotBusy and not session.RequestBusy
        and session.Data.PendingSpin == nil
end

local function clearExpired(k)
    local lock = byItem[k]
    if lock and lock.ExpiresAt <= os.time() then
        byItem[k] = nil
        byToken[lock.Token] = nil
        return nil
    end
    return lock
end

function Reservation.Acquire(session, issuanceId, purpose, duration)
    if not validSession(session) then return nil, "SessionUnavailable" end
    if purpose ~= "Listing" and purpose ~= "Auction" and purpose ~= "Trade" then
        return nil, "InvalidPurpose"
    end
    if type(duration) ~= "number" or duration % 1 ~= 0
        or duration < 1 or duration > MAX_SECONDS then
        return nil, "InvalidDuration"
    end
    local item, reason = Guard.Check(session, issuanceId)
    if not item then return nil, reason end
    -- Check authoritative slot records too, not just the item's Location.
    for _, slot in pairs(session.Data.IncomeSlots or {}) do
        if type(slot) == "table" and slot.IssuanceId == issuanceId then
            return nil, "IncomeSlotAssigned"
        end
    end
    local k = key(session.UserId, issuanceId)
    if clearExpired(k) then return nil, "AlreadyReserved" end
    local token = HttpService:GenerateGUID(false)
    local lock = {
        Token = token, UserId = session.UserId, IssuanceId = issuanceId,
        Purpose = purpose, ExpiresAt = os.time() + duration
    }
    byItem[k], byToken[token] = lock, k
    return {Token = token, ExpiresAt = lock.ExpiresAt, Purpose = purpose}
end

function Reservation.Check(session, issuanceId)
    if type(session) ~= "table" or type(session.UserId) ~= "number"
        or type(issuanceId) ~= "string" then return nil, "InvalidArguments" end
    local k = key(session.UserId, issuanceId)
    local lock = clearExpired(k)
    if not lock then return {Reserved = false} end
    return {Reserved = true, Purpose = lock.Purpose, ExpiresAt = lock.ExpiresAt}
end

function Reservation.Release(session, token)
    if type(session) ~= "table" or type(session.UserId) ~= "number"
        or type(token) ~= "string" then return nil, "InvalidArguments" end
    local k = byToken[token]
    if not k then return nil, "NotFound" end
    local lock = clearExpired(k)
    if not lock then return nil, "Expired" end
    if lock.UserId ~= session.UserId or lock.Token ~= token then
        return nil, "NotOwner"
    end
    byItem[k], byToken[token] = nil, nil
    return true
end

function Reservation.ReleaseAll(userId)
    if type(userId) ~= "number" then return nil, "InvalidUserId" end
    local released = 0
    for k, lock in pairs(byItem) do
        if lock.UserId == userId then
            byItem[k], byToken[lock.Token] = nil, nil
            released += 1
        end
    end
    return released
end

function Reservation.GetStatus()
    return {Ready = true, Persistent = false, TradingEnabled = false,
        Message = "Temporary server locks only; no trades or money transfers"}
end
return Reservation
