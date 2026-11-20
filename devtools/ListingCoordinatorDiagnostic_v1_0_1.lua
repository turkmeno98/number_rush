-- NUMBER RUSH: ListingCoordinator diagnostic v1.0.1
-- Run in Roblox Studio Command Bar while NOT in Play mode.
local folder = game:GetService("ServerScriptService"):FindFirstChild("NR_TradingFoundation")
assert(folder, "Missing NR_TradingFoundation")
local names = {"TradeEligibilityService","ReservationService","ListingRecordStore","PersistentListingClaim"}
for _, name in ipairs(names) do
    local obj = folder:FindFirstChild(name)
    if not obj or not obj:IsA("ModuleScript") then
        warn("MISSING DEPENDENCY:", name)
    else
        local ok, result = xpcall(function() return require(obj) end,
            function(err) return debug.traceback(tostring(err), 2) end)
        print("DEPENDENCY", name, "OK =", ok, "RESULT =", tostring(result))
    end
end
local module = folder:FindFirstChild("ListingCoordinator")
assert(module and module:IsA("ModuleScript"), "ListingCoordinator missing or wrong class")
local source = module.Source
print("COORDINATOR SOURCE LENGTH:", #source)
print("COORDINATOR SOURCE FIRST LINE:", source:match("^[^\\n]*") or "<empty>")
print("COORDINATOR SOURCE LAST 250 CHARS:", source:sub(-250))
local ok, result = xpcall(function() return require(module) end,
    function(err) return debug.traceback(tostring(err), 2) end)
print("COORDINATOR REQUIRE OK =", ok)
print("COORDINATOR REQUIRE DETAIL =", tostring(result))
if ok and type(result) == "table" then
    print("HAS Create:", type(result.Create) == "function")
    print("HAS Cancel:", type(result.Cancel) == "function")
    print("HAS GetStatus:", type(result.GetStatus) == "function")
    local statusOk, status = pcall(result.GetStatus)
    print("STATUS CALL:", statusOk, statusOk and status.Ready or tostring(status))
end
