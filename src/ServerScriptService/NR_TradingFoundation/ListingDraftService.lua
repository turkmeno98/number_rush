-- NUMBER RUSH: ListingDraftService v0.4
-- Drafts only. No marketplace, escrow, payments, or transfers.
local HttpService = game:GetService("HttpService")
local Eligibility = require(script.Parent:WaitForChild("TradeEligibilityService"))
local Reservation = require(script.Parent:WaitForChild("ReservationService"))
local Config = require(script.Parent:WaitForChild("MarketConfig"))
local Drafts = {}
local records = {}
local byOwnerItem = {}
local TTL = 120

local function itemKey(userId, issuanceId)
    return tostring(userId) .. ":" .. issuanceId
end

local function expire()
    local now = os.time()
    for id, draft in pairs(records) do
        if draft.ExpiresAt <= now then
            -- Reservation expires on its own after 120s.
            records[id] = nil
            byOwnerItem[itemKey(draft.OwnerId, draft.IssuanceId)] = nil
        end
    end
end

function Drafts.Create(session, issuanceId, askingPrice)
    expire()
    if Config.Enabled then return nil, "UnsafeConfiguration" end
    if type(session) ~= "table" or type(session.UserId) ~= "number" then
        return nil, "InvalidSession"
    end
    local eligible, reason = Eligibility.CheckListing(session, issuanceId, askingPrice)
    if not eligible then return nil, reason end
    local key = itemKey(session.UserId, issuanceId)
    if byOwnerItem[key] then return nil, "DraftAlreadyExists" end
    local lock, lockReason = Reservation.Acquire(session, issuanceId, "Listing", TTL)
    if not lock then return nil, lockReason end
    local id = HttpService:GenerateGUID(false)
    local record = {
        DraftId = id, OwnerId = session.UserId,
        IssuanceId = issuanceId, AskingPrice = askingPrice,
        CreatedAt = os.time(), ExpiresAt = lock.ExpiresAt,
        ReservationToken = lock.Token
    }
    records[id] = record
    byOwnerItem[key] = id
    return {DraftId = id, IssuanceId = issuanceId,
        AskingPrice = askingPrice, ExpiresAt = lock.ExpiresAt,
        Status = "DraftOnly"}
end

function Drafts.Cancel(session, draftId)
    expire()
    if type(session) ~= "table" or type(session.UserId) ~= "number"
        or type(draftId) ~= "string" then return nil, "InvalidArguments" end
    local draft = records[draftId]
    if not draft then return nil, "NotFound" end
    if draft.OwnerId ~= session.UserId then return nil, "NotOwner" end
    -- Remove draft regardless of whether reservation expired.
    records[draftId] = nil
    byOwnerItem[itemKey(draft.OwnerId, draft.IssuanceId)] = nil
    Reservation.Release(session, draft.ReservationToken)
    return true
end

function Drafts.GetMine(session)
    expire()
    if type(session) ~= "table" or type(session.UserId) ~= "number" then
        return nil, "InvalidSession"
    end
    local result = {}
    for _, draft in pairs(records) do
        if draft.OwnerId == session.UserId then
            table.insert(result, {
                DraftId = draft.DraftId, IssuanceId = draft.IssuanceId,
                AskingPrice = draft.AskingPrice, ExpiresAt = draft.ExpiresAt,
                Status = "DraftOnly"
            })
        end
    end
    return result
end

function Drafts.Status()
    return {TradingEnabled = false, Persistent = false,
        PublicListingsEnabled = false, DraftTTLSeconds = TTL}
end
return Drafts
