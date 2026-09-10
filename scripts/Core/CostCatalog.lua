-- FS25_Enhanced / Core/CostCatalog.lua
-- Loads config/costCatalog.xml for Live-Overlay hover warnings.

FS25E_CostCatalog = {}

local entries = {} -- id -> { id, cost, warn, notes }

local FALLBACK = {
    { id = "view-distance-coeff", cost = "high", warn = true, notes = "Draw distance; CPU risk when raised" },
    { id = "lod-distance-coeff", cost = "high", warn = true, notes = "LOD pull-in distance" },
    { id = "foliage-view-distance-coeff", cost = "high", warn = true, notes = "Foliage draw" },
    { id = "foliage-lod-distance-coeff", cost = "high", warn = true, notes = "Foliage LOD" },
    { id = "terrain-lod-distance-coeff", cost = "med", warn = false, notes = "Terrain LOD" },
    { id = "max-num-shadow-lights", cost = "extreme", warn = true, notes = "Shadow light budget" },
    { id = "shadow-quality", cost = "extreme", warn = true, notes = "Global shadow quality" },
    { id = "shadow-distance-quality", cost = "high", warn = true, notes = "Shadow distance" },
    { id = "shadow-filter-quality", cost = "high", warn = true, notes = "Soft filter quality" },
    { id = "allow-foliage-shadows", cost = "high", warn = true, notes = "Foliage shadows on" },
    { id = "light-soft-shadow-size", cost = "high", warn = true, notes = "Per-light soft size" },
    { id = "light-soft-shadow-distance", cost = "med", warn = false, notes = "Per-light soft distance" },
    { id = "merge-light-shadows", cost = "extreme", warn = true, notes = "Shadow merge" },
    { id = "shadow-focus-box", cost = "extreme", warn = true, notes = "EXPERIMENTAL focus box" },
    { id = "fast-shadow-update", cost = "extreme", warn = true, notes = "EXPERIMENTAL fast shadow update" },
    { id = "rain-shallow-water-simulation", cost = "extreme", warn = true, notes = "EXPERIMENTAL rain SWS" },
    { id = "ssr-quality", cost = "high", warn = true, notes = "GATED SSR" },
    { id = "atmosphere-quality", cost = "high", warn = true, notes = "GATED atmosphere" },
    { id = "drs-quality", cost = "med", warn = false, notes = "GATED DRS" },
}

local function seedFallback()
    for i = 1, #FALLBACK do
        local e = FALLBACK[i]
        entries[e.id] = {
            id = e.id,
            cost = e.cost,
            warn = e.warn == true,
            notes = e.notes,
        }
    end
end

local function parseXmlText(text)
    if text == nil or text == "" then
        return 0
    end
    local n = 0
    for tag in string.gmatch(text, "<cap%s+[^>]+/?>") do
        local id = string.match(tag, 'id%s*=%s*"([^"]+)"')
        if id ~= nil then
            local cost = string.match(tag, 'cost%s*=%s*"([^"]+)"') or "med"
            local warnStr = string.match(tag, 'warn%s*=%s*"([^"]+)"')
            local notes = string.match(tag, 'notes%s*=%s*"([^"]*)"')
            entries[id] = {
                id = id,
                cost = cost,
                warn = (warnStr == "true"),
                notes = notes,
            }
            n = n + 1
        end
    end
    return n
end

function FS25E_CostCatalog.load(modDirectory)
    entries = {}
    seedFallback()
    local path = (modDirectory or "") .. "config/costCatalog.xml"
    local loaded = 0
    pcall(function()
        if io == nil or io.open == nil then
            return
        end
        local f = io.open(path, "r")
        if f == nil then
            return
        end
        local content = f:read("*a")
        f:close()
        loaded = parseXmlText(content)
    end)
    FS25E_Debug.info("CostCatalog", string.format(
        "ready entries=%d xmlParsed=%d path=%s",
        FS25E_CostCatalog.count(),
        loaded,
        tostring(path)
    ))
end

function FS25E_CostCatalog.get(id)
    return entries[id]
end

function FS25E_CostCatalog.shouldWarn(id)
    local e = entries[id]
    return e ~= nil and e.warn == true
end

function FS25E_CostCatalog.getCost(id)
    local e = entries[id]
    return e ~= nil and e.cost or "med"
end

function FS25E_CostCatalog.all()
    return entries
end

function FS25E_CostCatalog.count()
    local n = 0
    for _ in pairs(entries) do
        n = n + 1
    end
    return n
end
