local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local storeName = "NR_Numbers_LIVE_v1"
if RunService:IsStudio() then storeName = "NR_Numbers_DEV_v1" end
local store = DataStoreService:GetDataStore(storeName)
local NumberRegistry = {}

local function validateArguments(fullNumber, userId, operationId)
	assert(type(fullNumber) == "string" and #fullNumber == 11 and fullNumber:match("^79%d+$"), "Некорректный полный номер")
	assert(type(userId) == "number" and userId % 1 == 0, "Некорректный UserId")
	assert(type(operationId) == "string" and #operationId > 0 and #operationId <= 64, "Некорректный идентификатор операции")
end

local function validRecord(record)
	if type(record) ~= "table" or record.SchemaVersion ~= 1 or type(record.Generation) ~= "number" or record.Generation < 1 or record.Generation % 1 ~= 0 then return false end
	if record.State == "Free" then return true end
	if record.State ~= "Reserved" and record.State ~= "Owned" then return false end
	return type(record.OwnerId) == "number" and type(record.OperationId) == "string" and type(record.IssuanceId) == "string"
end

local function updateRecord(fullNumber, transform)
	local rejectionReason = "Rejected"
	local success, result = pcall(function()
		return store:UpdateAsync(fullNumber, function(oldRecord)
			if oldRecord ~= nil and not validRecord(oldRecord) then rejectionReason = "InvalidRecord"; return nil end
			local updated, reason = transform(oldRecord)
			if updated == nil then rejectionReason = reason or "Rejected" end
			return updated
		end)
	end)
	if not success then return nil, "StorageError", tostring(result) end
	if result == nil then return nil, rejectionReason end
	return result
end

function NumberRegistry.Reserve(fullNumber, userId, operationId)
	validateArguments(fullNumber, userId, operationId)
	local issuanceId = HttpService:GenerateGUID(false)
	return updateRecord(fullNumber, function(oldRecord)
		if oldRecord and oldRecord.State ~= "Free" then
			if oldRecord.OwnerId == userId and oldRecord.OperationId == operationId then return oldRecord end
			return nil, "Occupied"
		end
		local generation = 1
		if oldRecord then generation = oldRecord.Generation + 1 end
		return {SchemaVersion = 1, State = "Reserved", OwnerId = userId, OperationId = operationId, IssuanceId = issuanceId, Generation = generation, UpdatedAt = os.time()}
	end)
end

function NumberRegistry.Confirm(fullNumber, userId, operationId)
	validateArguments(fullNumber, userId, operationId)
	return updateRecord(fullNumber, function(record)
		if not record or record.State == "Free" then return nil, "NotReserved" end
		if record.OwnerId ~= userId or record.OperationId ~= operationId then return nil, "OwnerMismatch" end
		if record.State == "Owned" then return record end
		record.State = "Owned"
		record.UpdatedAt = os.time()
		return record
	end)
end

function NumberRegistry.Cancel(fullNumber, userId, operationId)
	validateArguments(fullNumber, userId, operationId)
	return updateRecord(fullNumber, function(record)
		if not record then return nil, "NotReserved" end
		if record.State == "Free" and record.OperationId == operationId and record.LastOwnerId == userId then return record end
		if record.OwnerId ~= userId or record.OperationId ~= operationId then return nil, "OwnerMismatch" end
		if record.State == "Owned" then return nil, "AlreadyOwned" end
		if record.State ~= "Reserved" then return nil, "NotReserved" end
		record.State = "Free"
		record.LastOwnerId = userId
		record.OwnerId = nil
		record.UpdatedAt = os.time()
		return record
	end)
end

-- Generation advancing proves the old issuance was released; never free a newer owner.
function NumberRegistry.ReleaseOwned(fullNumber, userId, issuanceId, generation)
	validateArguments(fullNumber, userId, issuanceId)
	assert(type(generation) == "number" and generation % 1 == 0 and generation >= 1, "Invalid generation")
	return updateRecord(fullNumber, function(record)
		if not record then return nil, "MissingIssuance" end
		if record.Generation > generation then return record end
		if record.Generation ~= generation or record.IssuanceId ~= issuanceId then return nil, "IssuanceMismatch" end
		if record.State == "Free" and record.LastOwnerId == userId then return record end
		if record.State ~= "Owned" or record.OwnerId ~= userId then return nil, "OwnerMismatch" end
		record.State = "Free"; record.LastOwnerId = userId; record.OwnerId = nil; record.UpdatedAt = os.time()
		return record
	end)
end

return NumberRegistry
