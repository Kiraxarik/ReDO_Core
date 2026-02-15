ReDOCore = ReDOCore or {}
ReDOCore.LogLevels = {
    TRACE = 0,
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4
}

ReDOCore.Math = ReDOCore.Math or {}
ReDOCore.String = ReDOCore.String or {}
ReDOCore.Table = ReDOCore.Table or {}

local function getLogLevel()
    if not Config or not Config.Logging or not Config.Logging.Level then
        return ReDOCore.LogLevels.INFO
    end
    return ReDOCore.LogLevels[Config.Logging.Level] or ReDOCore.LogLevels.INFO
end

local function isDebugEnabled()
    if not Config or not Config.Logging then return false end
    return Config.Logging.Debug == true
end

local function isDebugFlagEnabled(flag)
    if not isDebugEnabled() then return false end
    if not Config.Logging.DebugFlags then return true end -- No flags defined = show all
    if Config.Logging.DebugFlags[flag] == nil then return true end -- Unknown flag = show
    return Config.Logging.DebugFlags[flag] == true
end

function ReDOCore.Trace(msg, ...)
    if ReDOCore.LogLevels.TRACE >= getLogLevel() then
        print(string.format("^8[TRACE]^7 " .. msg, ...))
    end
end

function ReDOCore.Debug(msg, ...)
    if not isDebugEnabled() then return end
    if ReDOCore.LogLevels.DEBUG >= getLogLevel() then
        print(string.format("^5[DEBUG]^7 " .. msg, ...))
    end
end

-- Debug with a specific flag - only prints if that flag is enabled
function ReDOCore.DebugFlag(flag, msg, ...)
    if not isDebugFlagEnabled(flag) then return end
    if ReDOCore.LogLevels.DEBUG >= getLogLevel() then
        print(string.format("^5[DEBUG]^7 " .. msg, ...))
    end
end

function ReDOCore.Info(msg, ...)
    if ReDOCore.LogLevels.INFO >= getLogLevel() then
        print(string.format("^2[INFO]^7 " .. msg, ...))
    end
end

function ReDOCore.Warn(msg, ...)
    if ReDOCore.LogLevels.WARN >= getLogLevel() then
        print(string.format("^3[WARN]^7 " .. msg, ...))
    end
end

function ReDOCore.Error(msg, ...)
    if ReDOCore.LogLevels.ERROR >= getLogLevel() then
        print(string.format("^1[ERROR]^7 " .. msg, ...))
    end
end

function ReDOCore.Math.Round(value, numDecimalPlaces)
    if not numDecimalPlaces then
        return math.floor(value + 0.5)
    end
    local power = 10 ^ numDecimalPlaces
    return math.floor((value * power) + 0.5) / power
end

function ReDOCore.Math.GroupDigits(value)
    local formatted = tostring(value)
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then
            break
        end
    end
    return formatted
end

function ReDOCore.String.Trim(value)
    if not value then
        return nil
    end
    return (string.gsub(value, '^%s*(.-)%s*$', '%1'))
end

function ReDOCore.String.StartsWith(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

function ReDOCore.Table.SizeOf(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function ReDOCore.Table.Clone(tbl)
    if type(tbl) ~= 'table' then
        return tbl
    end
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = ReDOCore.Table.Clone(v)
    end
    return copy
end

print("^2[ReDOCore]^7 Utility functions loaded")
