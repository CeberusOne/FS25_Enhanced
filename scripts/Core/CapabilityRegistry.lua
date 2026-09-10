-- FS25_Enhanced / Core/CapabilityRegistry.lua
-- Load config/capabilityProfiles.xml stub; query API only. NO setters in Phase 1.

FS25E_CapabilityRegistry = {}

FS25E_CapabilityRegistry.STATUS = {
    CONFIRMED = "CONFIRMED",
    GATED = "GATED",
    EXPERIMENTAL = "EXPERIMENTAL",
    ASSET_DEPENDENT = "ASSET_DEPENDENT",
    UNSUPPORTED = "UNSUPPORTED",
    REJECTED = "REJECTED",
}

local capabilities = {} -- id -> { id, status, apiName, notes }

local function parseStatus(raw)
    local s = tostring(raw or ""):upper()
    if FS25E_CapabilityRegistry.STATUS[s] ~= nil then
        return s
    end
    return FS25E_CapabilityRegistry.STATUS.UNSUPPORTED
end

--- Load capability profiles from XML. Safe no-op if file missing or XML unavailable.
function FS25E_CapabilityRegistry.load(modDirectory)
    capabilities = {}
    local path = (modDirectory or "") .. "config/capabilityProfiles.xml"
    FS25E_Debug.info("CapabilityRegistry", "load stub from " .. path)

    -- Phase 1: lightweight stub. Full XML parse filled by Research Freeze.
    -- If loadXMLFile exists, attempt a soft read; otherwise keep empty table.
    local ok, err = pcall(function()
        if loadXMLFile == nil then
            return
        end
        local xmlId = loadXMLFile("FS25E_capabilityProfiles", path)
        if xmlId == nil or xmlId == 0 then
            FS25E_Debug.info("CapabilityRegistry", "XML not loaded (ok in PoC); empty registry")
            return
        end
        -- Placeholder: no capabilities required for Phase 1
        if deleteXMLFile ~= nil then
            deleteXMLFile(xmlId)
        end
    end)
    if not ok then
        FS25E_Debug.warning("CapabilityRegistry", "load soft-failed: " .. tostring(err))
    end
end

function FS25E_CapabilityRegistry.register(id, status, apiName, notes)
    if id == nil or id == "" then
        return false
    end
    capabilities[id] = {
        id = id,
        status = parseStatus(status),
        apiName = apiName,
        notes = notes,
    }
    return true
end

function FS25E_CapabilityRegistry.get(id)
    return capabilities[id]
end

function FS25E_CapabilityRegistry.getStatus(id)
    local c = capabilities[id]
    if c == nil then
        return FS25E_CapabilityRegistry.STATUS.UNSUPPORTED
    end
    return c.status
end

function FS25E_CapabilityRegistry.isConfirmed(id)
    return FS25E_CapabilityRegistry.getStatus(id) == FS25E_CapabilityRegistry.STATUS.CONFIRMED
end

function FS25E_CapabilityRegistry.isUsable(id)
    local s = FS25E_CapabilityRegistry.getStatus(id)
    return s == FS25E_CapabilityRegistry.STATUS.CONFIRMED
        or s == FS25E_CapabilityRegistry.STATUS.GATED
        or s == FS25E_CapabilityRegistry.STATUS.EXPERIMENTAL
        or s == FS25E_CapabilityRegistry.STATUS.ASSET_DEPENDENT
end

--- Reject a capability after runtime failure (soft).
function FS25E_CapabilityRegistry.reject(id, reason)
    local c = capabilities[id]
    if c == nil then
        FS25E_CapabilityRegistry.register(id, "REJECTED", nil, reason)
        return
    end
    c.status = FS25E_CapabilityRegistry.STATUS.REJECTED
    c.notes = reason
    FS25E_Debug.warning("CapabilityRegistry", string.format("rejected %s: %s", tostring(id), tostring(reason)))
end

function FS25E_CapabilityRegistry.all()
    return capabilities
end
