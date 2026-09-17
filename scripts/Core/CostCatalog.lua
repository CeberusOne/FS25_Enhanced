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

function FS25E_CostCatalog.load(modDirectory)
    entries = {}
    seedFallback()
    local path = (modDirectory or "") .. "config/costCatalog.xml"
    local loaded = 0
    pcall(function()
        if type(loadXMLFile)~="function" or type(getXMLString)~="function" or type(delete)~="function" then return end
        if type(fileExists)=="function" and not fileExists(path) then return end
        local xml=loadXMLFile("FS25E_costCatalog",path)
        if not xml or xml==0 then return end
        local ok,err=pcall(function()
            for i=0,1023 do
                local key="costCatalog.cap("..i..")"
                local id=getXMLString(xml,key.."#id")
                if id==nil then break end
                entries[id]={id=id,cost=getXMLString(xml,key.."#cost") or "med",
                    warn=getXMLString(xml,key.."#warn")=="true",notes=getXMLString(xml,key.."#notes")}
                loaded=loaded+1
            end
        end)
        delete(xml)
        if not ok then error(err) end
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
