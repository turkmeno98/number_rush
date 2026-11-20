-- NUMBER RUSH v1.0: read-only trading foundation smoke test
-- Run in Roblox Studio Command Bar in EDIT mode, with Play stopped.
-- No DataStore writes, no inventory/balance changes, no real trades.
local folder = game:GetService("ServerScriptService"):FindFirstChild("NR_TradingFoundation")
assert(folder, "Missing NR_TradingFoundation")
local deps = {
    "MarketConfig", "InventoryGuard", "TransactionJournal",
    "ReservationService", "TradeEligibilityService",
    "ListingRecordStore", "PersistentListingClaim", "ListingCoordinator"
}
local loaded = {}
for _, name in ipairs(deps) do
    local obj = assert(folder:FindFirstChild(name), "Missing module: " .. name)
    assert(obj:IsA("ModuleScript"), name .. " is not a ModuleScript")
    local ok, result = pcall(require, obj)
    assert(ok, name .. " require failed: " .. tostring(result))
    assert(type(result) == "table", name .. " must return a table")
    loaded[name] = result
    print("PASS: loaded " .. name)
end
assert(loaded.MarketConfig.Enabled == false, "Trading must remain disabled")
print("PASS: trading disabled")
for _, spec in ipairs({
    {"ReservationService","Acquire"},{"ReservationService","Check"},{"ReservationService","Release"},
    {"ListingRecordStore","Prepare"},{"ListingRecordStore","Get"},{"ListingRecordStore","Cancel"},
    {"PersistentListingClaim","Acquire"},{"PersistentListingClaim","Get"},{"PersistentListingClaim","Release"},
    {"ListingCoordinator","Create"},{"ListingCoordinator","Cancel"},{"ListingCoordinator","GetStatus"},
}) do
    local moduleName, methodName = spec[1], spec[2]
    assert(type(loaded[moduleName][methodName]) == "function", moduleName .. "." .. methodName .. " missing")
    print("PASS: " .. moduleName .. "." .. methodName)
end
local status = loaded.ListingCoordinator.GetStatus()
assert(status.Ready == true)
assert(status.PersistentPreparation == true)
assert(status.PublicListings == false)
assert(status.Payments == false)
assert(status.OwnershipTransfers == false)
assert(status.TradingEnabled == false)
print("PASS: coordinator safety status")
local recordStatus = loaded.ListingRecordStore.Status()
assert(recordStatus.TradingEnabled == false)
print("PASS: record store status")
local claimStatus = loaded.PersistentListingClaim.Status()
assert(claimStatus.TradingEnabled == false)
assert(claimStatus.EscrowEnabled == false)
print("PASS: persistent claim status")
print("NUMBER RUSH v1.0: ALL READ-ONLY CHECKS PASSED")
print("NO DATASTORE WRITES; NO INVENTORY OR BALANCE CHANGES; NO REAL TRADES")
