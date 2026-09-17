-- FS25_Enhanced / Core/Debug.lua
-- Prefixed logging helpers. Never use Logging.fatal for optional missing nodes.

FS25E_Debug = {}

local PREFIX = "[FS25_Enhanced]"
local LEVELS={ERROR=1,WARNING=2,INFO=3,DEBUG=4,TRACE=5}
local level=LEVELS.INFO
function FS25E_Debug.setLevel(name) level=LEVELS[tostring(name):upper()] or LEVELS.INFO end
function FS25E_Debug.getLevel() for name,value in pairs(LEVELS) do if value==level then return name end end end

local function formatMsg(subsystem, message)
    if subsystem ~= nil and subsystem ~= "" then
        return string.format("%s[%s] %s", PREFIX, tostring(subsystem), tostring(message))
    end
    return string.format("%s %s", PREFIX, tostring(message))
end

function FS25E_Debug.info(subsystem, message)
    if level<LEVELS.INFO then return end
    if Logging ~= nil and Logging.info ~= nil then
        Logging.info(formatMsg(subsystem, message))
    end
end

function FS25E_Debug.warning(subsystem, message)
    if level<LEVELS.WARNING then return end
    if Logging ~= nil and Logging.warning ~= nil then
        Logging.warning(formatMsg(subsystem, message))
    end
end

function FS25E_Debug.debug(subsystem,message)
    if level>=LEVELS.DEBUG then FS25E_Debug.info(subsystem,message) end
end
function FS25E_Debug.trace(subsystem,message)
    if level>=LEVELS.TRACE then FS25E_Debug.info(subsystem,message) end
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


--- Mission update(dt): Giants typically passes milliseconds.
--- If a caller ever passes seconds (dt < 1), convert. Never blind-multiply.
function FS25E_Debug.dtToMs(dt)
    if dt == nil then
        return 0
    end
    local n = tonumber(dt)
    if n == nil then
        return 0
    end
    if n~=n or n<0 or n==math.huge then return 0 end
    return n -- GIANTS mission update dt is already milliseconds, even below 1 ms.
end
