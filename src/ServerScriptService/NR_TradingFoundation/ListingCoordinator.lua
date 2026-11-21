-- NUMBER RUSH v0.9.1 / ListingCoordinator
-- Preparation only. No public listings, payments, or ownership transfers.
local HttpService = game:GetService("HttpService")
local Eligibility = require(script.Parent:WaitForChild("TradeEligibilityService"))
local Reservations = require(script.Parent:WaitForChild("ReservationService"))
local Records = require(script.Parent:WaitForChild("ListingRecordStore"))
local Claims = require(script.Parent:WaitForChild("PersistentListingClaim"))

local Coordinator = {}
local MAX_TTL = 300
local MAX_PRICE = 1000000000000

local function validSession(s)
	return type(s) == "table"
		and type(s.UserId) == "number" and s.UserId > 0 and s.UserId % 1 == 0
		and type(s.Data) == "table"
		and not s.Closed and not s.Closing and not s.NeedsRecovery
		and type(s.LeaseUntil) == "number" and s.LeaseUntil > os.time() + 10
		and not s.Busy and not s.SpinBusy and not s.SlotBusy
		and not s.RequestBusy and s.Data.PendingSpin == nil
end

function Coordinator.Create(session, issuanceId, askingPrice, ttlSeconds)
	if not validSession(session) then return nil, "SessionUnavailable" end
	if type(ttlSeconds) ~= "number" or ttlSeconds % 1 ~= 0
		or ttlSeconds < 1 or ttlSeconds > MAX_TTL then return nil, "InvalidTTL" end
	if type(askingPrice) ~= "number" or askingPrice % 1 ~= 0
		or askingPrice < 1 or askingPrice > MAX_PRICE then return nil, "InvalidPrice" end

	local eligible, reason = Eligibility.CheckListing(session, issuanceId, askingPrice)
	if not eligible then return nil, reason end
	local item = session.Data.Inventory and session.Data.Inventory[issuanceId]
	if type(item) ~= "table" or item.IssuanceId ~= issuanceId
		or type(item.FullNumber) ~= "string" then return nil, "InvalidInventoryItem" end

	local listingId = HttpService:GenerateGUID(false)
	local claim, claimError = Claims.Acquire(issuanceId, listingId, session.UserId, ttlSeconds)
	if not claim then return nil, claimError end

	local localLock, lockError = Reservations.Acquire(session, issuanceId, "Listing", ttlSeconds)
	if not localLock then
		local released, releaseError = Claims.Release(issuanceId, listingId, session.UserId)
		if not released then return nil, "RecoveryRequired", tostring(releaseError) end
		return nil, lockError
	end

	local record, recordError, details = Records.Prepare(
		listingId, session.UserId, issuanceId, item.FullNumber, askingPrice, ttlSeconds
	)
	if not record then
		if recordError == "StorageError" then
			return nil, "RecoveryRequired", tostring(details)
		end
		Reservations.Release(session, localLock.Token)
		local released, releaseError = Claims.Release(issuanceId, listingId, session.UserId)
		if not released then return nil, "RecoveryRequired", tostring(releaseError) end
		return nil, recordError
	end

	if record.State ~= "Prepared" or record.ListingId ~= listingId then
		return nil, "RecoveryRequired", "UnexpectedRecordState"
	end
	return {
		ListingId = listingId, IssuanceId = issuanceId, AskingPrice = askingPrice,
		ExpiresAt = record.ExpiresAt, State = "Prepared",
		Public = false, TradingEnabled = false
	}
end

function Coordinator.Cancel(session, listingId)
	if not validSession(session) then return nil, "SessionUnavailable" end
	if type(listingId) ~= "string" then return nil, "InvalidListingId" end
	local record, readError, details = Records.Get(listingId)
	if not record then return nil, readError, details end
	if record.OwnerId ~= session.UserId then return nil, "NotOwner" end
	if record.State ~= "Prepared" and record.State ~= "Cancelled" then
		return nil, "InvalidState"
	end
	if record.State == "Prepared" then
		local cancelled, cancelError, cancelDetails = Records.Cancel(listingId, session.UserId)
		if not cancelled then return nil, cancelError, cancelDetails end
	end
	local released, releaseError = Claims.Release(record.IssuanceId, listingId, session.UserId)
	if not released then return nil, "RecoveryRequired", tostring(releaseError) end
	return {ListingId = listingId, IssuanceId = record.IssuanceId, State = "Cancelled"}
end

function Coordinator.GetStatus()
	return {
		Ready = true, PersistentPreparation = true,
		PublicListings = false, Payments = false,
		OwnershipTransfers = false, TradingEnabled = false
	}
end

return Coordinator
