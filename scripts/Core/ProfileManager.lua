-- FS25_Enhanced / Core/ProfileManager.lua
-- Phase 2: Preset stubs Performance/Balanced/Quality/Cinematic from config/presets.xml.
-- Fills SettingsCache requested slots only. NO engine apply in Phase 2.

FS25E_ProfileManager = {}

local presets = {}
local activeName = "Balanced"
local loaded = false

local FALLBACK = {
    {
        name = "Performance",
        l10n = "FS25E_PRESET_PERFORMANCE",
        isDefault = false,
        note = "Favor frame-time; lowest visual budget.",
        targets = {
            viewDistanceCoeff = 0.7,
            lodDistanceCoeff = 0.7,
            foliageViewDistanceCoeff = 0.6,
            foliageLodDistanceCoeff = 0.6,
            terrainLodDistanceCoeff = 0.7,
            maxNumShadowLights = 2,
            allowFoliageShadows = false,
        },
    },
    {
        name = "Balanced",
        l10n = "FS25E_PRESET_BALANCED",
        isDefault = true,
        note = "Default compromise between visuals and performance.",
        targets = {
            viewDistanceCoeff = 1.0,
            lodDistanceCoeff = 1.0,
            foliageViewDistanceCoeff = 1.0,
            foliageLodDistanceCoeff = 1.0,
            terrainLodDistanceCoeff = 1.0,
            maxNumShadowLights = 4,
            allowFoliageShadows = true,
        },
    },
    {
        name = "Quality",
        l10n = "FS25E_PRESET_QUALITY",
        isDefault = false,
        note = "Higher visual budget; still respects target FPS when adaptive.",
        targets = {
            viewDistanceCoeff = 1.25,
            lodDistanceCoeff = 1.25,
            foliageViewDistanceCoeff = 1.2,
            foliageLodDistanceCoeff = 1.2,
            terrainLodDistanceCoeff = 1.2,
            maxNumShadowLights = 6,
            allowFoliageShadows = true,
        },
    },
    {
        name = "Cinematic",
        l10n = "FS25E_PRESET_CINEMATIC",
        isDefault = false,
        note = "Max visuals; may allow EXPERIMENTAL caps later. Not for competitive FPS.",
        targets = {
            viewDistanceCoeff = 1.5,
            lodDistanceCoeff = 1.5,
            foliageViewDistanceCoeff = 1.5,
            foliageLodDistanceCoeff = 1.5,
            terrainLodDistanceCoeff = 1.5,
            maxNumShadowLights = 8,
            allowFoliageShadows = true,
        },
    },
}

local function storePreset(entry)
    if entry == nil or entry.name == nil or entry.name == "" then
        return false
    end
    presets[entry.name] = {
        name = entry.name,
        l10n = entry.l10n,
        isDefault = entry.isDefault == true,
        note = entry.note,
        targets = entry.targets or {},
    }
    return true
end

local function seedFallback()
    presets = {}
    for i = 1, #FALLBACK do
        storePreset(FALLBACK[i])
    end
    activeName = "Balanced"
    FS25E_Debug.info("ProfileManager", string.format("seeded Lua fallback presets count=%d", #FALLBACK))
end

local function parseTargetsFromXml(xmlId, basePath)
    local targets = {}
    if getXMLString == nil then
        return targets
    end
    local i = 0
    while true do
        local keyPath = string.format("%s.target(%d)#key", basePath, i)
        local key = getXMLString(xmlId, keyPath)
        if key == nil or key == "" then
            break
        end
        local valPath = string.format("%s.target(%d)#value", basePath, i)
        local raw = getXMLString(xmlId, valPath)
        local num = tonumber(raw)
        if num ~= nil then
            targets[key] = num
        elseif raw == "true" or raw == "false" then
            targets[key] = (raw == "true")
        else
            targets[key] = raw
        end
        i = i + 1
    end
    return targets
end

local function tryParseXml(path)
    if loadXMLFile == nil or getXMLString == nil then
        return false, "XML APIs unavailable"
    end
    local xmlId = loadXMLFile("FS25E_presets", path)
    if xmlId == nil or xmlId == 0 then
        return false, "loadXMLFile failed"
    end
    local count = 0
    local ok, err = pcall(function()
        local i = 0
        while true do
            local base = string.format("presets.preset(%d)", i)
            local name = getXMLString(xmlId, base .. "#name")
            if name == nil or name == "" then
                break
            end
            local defaultAttr = getXMLString(xmlId, base .. "#default")
            local note = getXMLString(xmlId, base .. ".note")
            local targets = parseTargetsFromXml(xmlId, base)
            if next(targets) == nil then
                for _, fb in ipairs(FALLBACK) do
                    if fb.name == name then
                        targets = fb.targets
                        break
                    end
                end
            end
            if storePreset({
                name = name,
                l10n = getXMLString(xmlId, base .. "#l10n"),
                isDefault = defaultAttr == "true",
                note = note,
                targets = targets,
            }) then
                count = count + 1
                if defaultAttr == "true" then
                    activeName = name
                end
            end
            i = i + 1
        end
    end)
    if deleteXMLFile ~= nil then
        pcall(deleteXMLFile, xmlId)
    end
    if not ok then
        return false, err
    end
    if count == 0 then
        return false, "no preset nodes"
    end
    return true, count
end

function FS25E_ProfileManager.load(modDirectory)
    presets = {}
    loaded = false
    local path = (modDirectory or "") .. "config/presets.xml"
    FS25E_Debug.info("ProfileManager", "load from " .. path)
    local success, info = tryParseXml(path)
    if success then
        loaded = true
        FS25E_Debug.info("ProfileManager", string.format("XML loaded count=%s active=%s", tostring(info), tostring(activeName)))
    else
        FS25E_Debug.warning("ProfileManager", "XML soft-fail: " .. tostring(info) .. "; using Lua fallback")
        seedFallback()
        loaded = true
    end
    if next(presets) == nil then
        seedFallback()
        loaded = true
    end
    if presets[activeName] == nil then
        activeName = "Balanced"
    end
end

function FS25E_ProfileManager.init(modDirectory)
    FS25E_ProfileManager.load(modDirectory)
    FS25E_Debug.info("ProfileManager", "init (stubs only; no engine apply)")
end

function FS25E_ProfileManager.getActiveName()
    return activeName
end

function FS25E_ProfileManager.getPreset(name)
    return presets[name]
end

function FS25E_ProfileManager.listNames()
    local names = {}
    for name, _ in pairs(presets) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function FS25E_ProfileManager.all()
    return presets
end

function FS25E_ProfileManager.selectPreset(name)
    local p = presets[name]
    if p == nil then
        FS25E_Debug.warning("ProfileManager", "unknown preset " .. tostring(name))
        return false
    end
    activeName = name
    if FS25E_SettingsSchema ~= nil then
        FS25E_SettingsSchema.set("preset", name)
    end
    if FS25E_SettingsCache ~= nil and p.targets ~= nil then
        for key, value in pairs(p.targets) do
            local e = FS25E_SettingsCache.get(key)
            if e == nil then
                FS25E_SettingsCache.ensure(key, value)
                e = FS25E_SettingsCache.get(key)
            end
            if e ~= nil and not e.locked then
                FS25E_SettingsCache.setRequested(key, value)
            else
                FS25E_Debug.info("ProfileManager", "skip locked/missing key=" .. tostring(key))
            end
        end
    end
    FS25E_Debug.info("ProfileManager", "selectPreset " .. tostring(name) .. " (cache requested only; no engine apply)")
    return true
end

function FS25E_ProfileManager.presetForMode(mode)
    if mode == "FAST" then
        return "Performance"
    elseif mode == "SLOW" then
        return "Quality"
    end
    return activeName ~= nil and activeName or "Balanced"
end

function FS25E_ProfileManager.reset()
    activeName = "Balanced"
end
