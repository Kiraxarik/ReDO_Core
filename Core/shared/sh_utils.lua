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
    -- Safety check - if Config doesn't exist yet, default to INFO
    if not Config or not Config.Logging or not Config.Logging.Level then
        return ReDOCore.LogLevels.INFO
    end
    
    local configLevel = Config.Logging.Level or "INFO"
    return ReDOCore.LogLevels[configLevel] or ReDOCore.LogLevels.INFO
end

function ReDOCore.Trace(msg, ...)
    if ReDOCore.LogLevels.TRACE >= getLogLevel() then
        print(string.format("^8[TRACE]^7 " .. msg, ...))
    end
end

function ReDOCore.Debug(msg, ...)
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
