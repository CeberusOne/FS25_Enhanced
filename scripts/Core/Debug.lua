-- FS25_Enhanced / Core/Debug.lua
-- Prefixed logging helpers. Never use Logging.fatal for optional missing nodes.

FS25E_Debug = {}

local PREFIX = "[FS25_Enhanced]"

local function formatMsg(subsystem, message)
    if subsystem ~= nil and subsystem ~= "" then
        return string.format("%s[%s] %s", PREFIX, tostring(subsystem), tostring(message))
    end
    return string.format("%s %s", PREFIX, tostring(message))
end

function FS25E_Debug.info(subsystem, message)
    if Logging ~= nil and Logging.info ~= nil then
        Logging.info(formatMsg(subsystem, message))
    end
end

function FS25E_Debug.warning(subsystem, message)
    if Logging ~= nil and Logging.warning ~= nil then
        Logging.warning(formatMsg(subsystem, message))
    end
end

function FS25E_Debug.error(subsystem, message)
    if Logging ~= nil and Logging.error ~= nil then
        Logging.error(formatMsg(subsystem, message))
    end
end

--- Safe pcall wrapper at module boundaries. Logs warning on failure; never fatal.
function FS25E_Debug.pcall(subsystem, label, fn, ...)
    if type(fn) ~= "function" then
        return false, "not a function"
    end
    local ok, result = pcall(fn, ...)
    if not ok then
        FS25E_Debug.warning(subsystem, string.format("%s failed: %s", tostring(label), tostring(result)))
    end
    return ok, result
end
