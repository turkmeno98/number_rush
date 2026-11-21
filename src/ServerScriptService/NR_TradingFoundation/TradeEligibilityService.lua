-- NUMBER RUSH / TradeEligibilityService v0.3
-- Server-only validation; never moves items or money.
local Guard = require(script.Parent:WaitForChild("InventoryGuard"))
local Reservations = require(script.Parent:WaitForChild("ReservationService"))
local Config = require(script.Parent:WaitForChild("MarketConfig"))
local Eligibility = {}

local function integer(n)
    return type(n) == "number" and n % 1 == 0
end

function Eligibility.CheckItem(session, issuanceId)
    if type(session) ~= "table" or type(session.Data) ~= "table" then
        return nil, "InvalidSession"
    end
    if session.Closed or session.Closing or session.NeedsRecovery
        or session.Busy or session.SpinBusy or session.SlotBusy
        or session.RequestBusy or session.Data.PendingSpin then
        return nil, "SessionBusy"
    end
    if type(session.LeaseUntil) ~= "number"
        or session.LeaseUntil <= os.time() + 10 then
        return nil, "SessionUnavailable"
    end
    local item, reason = Guard.Check(session, issuanceId)
    if not item then return nil, reason end
    for _, slot in pairs(session.Data.IncomeSlots or {}) do
        if type(slot) == "table" and slot.IssuanceId == issuanceId then
            return nil, "IncomeSlotAssigned"
        end
    end
    local lock, lockError = Reservations.Check(session, issuanceId)
    if not lock then return nil, lockError end
    if lock.Reserved then return nil, "AlreadyReserved" end
    return {
        IssuanceId = issuanceId,
        FullNumber = item.FullNumber,
        DisplayNumber = item.DisplayNumber,
        BasePrice = item.BasePrice or item.Price,
        RarityName = item.RarityName
    }
end

function Eligibility.CheckListing(session, issuanceId, askingPrice)
    local item, reason = Eligibility.CheckItem(session, issuanceId)
    if not item then return nil, reason end
    local basePrice = item.BasePrice
    if not integer(basePrice) or basePrice < 1 then
        return nil, "BasePriceUnavailable"
    end
    if not integer(askingPrice) or askingPrice < basePrice * Config.MinPriceMultiplier
        or askingPrice > basePrice * Config.MaxPriceMultiplier then
        return nil, "InvalidPrice"
    end
    return {Allowed = true, IssuanceId = issuanceId, Price = askingPrice,
        CommissionPercent = Config.ListingFeePercent,
        TradingEnabled = Config.Enabled == true}
end

function Eligibility.CheckOffer(session, issuanceIds)
    if type(issuanceIds) ~= "table" or #issuanceIds < 1
        or #issuanceIds > Config.TradeMaximumItemsPerSide then
        return nil, "InvalidOfferSize"
    end
    local seen, checked = {}, {}
    for _, issuanceId in ipairs(issuanceIds) do
        if seen[issuanceId] then return nil, "DuplicateItem" end
        seen[issuanceId] = true
        local item, reason = Eligibility.CheckItem(session, issuanceId)
        if not item then return nil, reason end
        table.insert(checked, item)
    end
    return {Allowed = true, Items = checked, TradingEnabled = Config.Enabled == true}
end

function Eligibility.Status()
    return {Ready = true, TradingEnabled = false,
        Description = "Validation only; no remotes or transfers"}
end
return Eligibility
