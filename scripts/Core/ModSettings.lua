-- FS25_Enhanced / Core/ModSettings.lua
-- Prepare client modSettings path: Documents/.../modSettings/FS25_Enhanced/
-- Structure/stub only — no heavy persistence in Phase 1.

FS25E_ModSettings = {}

local MOD_SETTINGS_FOLDER = "FS25_Enhanced"
local relativePath = nil
local absolutePath = nil
local ready = false

--- Resolve modSettings directory using getUserProfileAppPath when available.
function FS25E_ModSettings.init()
    ready = false
    relativePath = "modSettings/" .. MOD_SETTINGS_FOLDER .. "/"
    absolutePath = nil

    local ok, err = pcall(function()
        if getUserProfileAppPath ~= nil then
            local base = getUserProfileAppPath()
            if base ~= nil and base ~= "" then
                absolutePath = base .. "modSettings/" .. MOD_SETTINGS_FOLDER .. "/"
            end
        end
    end)
    if not ok then
        FS25E_Debug.warning("ModSettings", "getUserProfileAppPath failed: " .. tostring(err))
    end

    -- Soft ensure directory exists (createFolder if present). No-op if APIs missing.
    if absolutePath ~= nil and createFolder ~= nil then
        pcall(function()
            -- Ensure parent modSettings then our folder (best-effort)
            local parent = absolutePath:match("^(.*[/\\])")
            if parent ~= nil then
                -- createFolder is typically recursive-safe enough for one level; ignore errors
            end
            createFolder(absolutePath)
        end)
    end

    ready = true
    FS25E_Debug.info("ModSettings", string.format(
        "path prepared relative=%s absolute=%s",
        tostring(relativePath),
        tostring(absolutePath or "(deferred until profile path available)")
    ))
end

function FS25E_ModSettings.isReady()
    return ready
end

function FS25E_ModSettings.getRelativePath()
    return relativePath
end

function FS25E_ModSettings.getAbsolutePath()
    return absolutePath
end

function FS25E_ModSettings.getFilePath(filename)
    local name = filename or "settings.xml"
    if absolutePath ~= nil then
        return absolutePath .. name
    end
    return relativePath .. name
end

--- Phase 1 stub: do not load/save heavy settings yet.
function FS25E_ModSettings.loadStub()
    FS25E_Debug.info("ModSettings", "loadStub (no-op; persist deferred)")
    return true
end

function FS25E_ModSettings.saveStub()
    FS25E_Debug.info("ModSettings", "saveStub (no-op; persist deferred)")
    return true
end
