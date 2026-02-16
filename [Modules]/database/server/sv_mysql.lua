--[[
    Custom MySQL Connection Handler
    
    Auto-detects and uses any MySQL resource (oxmysql, mysql-async, or ghmattimysql)
    NO MANUAL CONFIGURATION NEEDED!
    
    CROSS-RESOURCE SHARING:
    With lua54, each resource has its own Lua state. Tables passed via
    exports are proxied — mutations in one resource don't always show
    in another. So instead of trying to attach MySQL/DB to Core's table,
    we export them directly from THIS resource.
    
    Other resources access MySQL via:
        exports['database']:GetMySQL()
    And the query builder via:
        exports['database']:GetDB()
]]

-- Get the framework object from Core (for logging functions and Config).
ReDOCore = exports['Core']:GetCoreObject()

-- Make Config available as a global for other files in this resource.
Config = ReDOCore.Config

-- Build the MySQL object. This stays in THIS resource's Lua state.
-- Other files in this resource access it as the global ReDOCore.MySQL
-- (we set that at the bottom). Other RESOURCES access it via export.
local MySQL = {}

-- Connection configuration
local connectionString = GetConvar('mysql_connection_string', '')
local isConnected = false

-- Parse connection string
local function ParseConnectionString(connStr)
    -- Format: mysql://user:password@host:port/database
    local config = {}
    
    -- Extract parts using pattern matching
    local pattern = "mysql://([^:]+):?([^@]*)@([^:/]+):?(%d*)/([^%?]+)"
    local user, password, host, port, database = string.match(connStr, pattern)
    
    config.user = user or "root"
    config.password = password or ""
    config.host = host or "localhost"
    config.port = tonumber(port) or 3306
    config.database = database or ""
    
    return config
end

-- Initialize connection
function MySQL.Initialize()
    if connectionString == "" then
        ReDOCore.Error("MySQL connection string not set! Add this to server.cfg:")
        ReDOCore.Error("  set mysql_connection_string \"mysql://root@localhost/redm_framework\"")
        return false
    end
    
    local config = ParseConnectionString(connectionString)
    
    ReDOCore.Info("MySQL configured: %s@%s/%s", 
        config.user, config.host, config.database)
    
    -- Detect which MySQL resource is available
    local mysqlResource = nil
    if GetResourceState('oxmysql') == 'started' then
        mysqlResource = 'oxmysql'
    elseif GetResourceState('ghmattimysql') == 'started' then
        mysqlResource = 'ghmattimysql'
    elseif GetResourceState('mysql-async') == 'started' then
        mysqlResource = 'mysql-async'
    end
    
    if mysqlResource then
        ReDOCore.DebugFlag('SQL_Connection', "Detected MySQL resource: %s", mysqlResource)
        isConnected = true
        return true
    else
        ReDOCore.Error("No MySQL resource found! Please install one of:")
        ReDOCore.Error("  - oxmysql (recommended)")
        ReDOCore.Error("  - ghmattimysql")
        ReDOCore.Error("  - mysql-async")
        return false
    end
end

-- Check if connected
function MySQL.IsConnected()
    return isConnected
end

-- Execute a query (INSERT, UPDATE, DELETE) using built-in natives
-- IMPORTANT: oxmysql does NOT call the callback when a query errors.
-- We use a timeout to detect this and invoke the callback with nil,
-- so the rest of the system doesn't hang waiting forever.
--
-- NOTE: oxmysql may return the affected count as either a plain number
-- or a table like { affectedRows = N }. We normalize to always pass
-- a plain number to the callback.
function MySQL.Execute(query, parameters, callback)
    if not query then
        ReDOCore.Error("MySQL.Execute: query is required")
        if callback then callback(nil) end
        return
    end
    
    parameters = parameters or {}
    
    -- Normalize result: oxmysql returns either a number or { affectedRows = N }
    local function normalizeResult(result)
        if result == nil then return nil end
        if type(result) == "number" then return result end
        if type(result) == "table" then
            if result.affectedRows then return result.affectedRows end
            -- Some drivers return { [1] = { affectedRows = N } }
            if result[1] and result[1].affectedRows then return result[1].affectedRows end
            -- If it's a table but we can't extract a number, return 0
            return 0
        end
        return 0
    end
    
    -- Wrap callback with a timeout safety net.
    -- If oxmysql doesn't call back within 5 seconds, we assume it failed.
    local cbFired = false
    local safeCallback = function(result)
        if cbFired then return end
        cbFired = true
        if callback then callback(normalizeResult(result)) end
    end
    
    -- Start timeout watcher
    if callback then
        SetTimeout(5000, function()
            if not cbFired then
                ReDOCore.Warn("MySQL.Execute: Query callback timed out (oxmysql may have errored)")
                ReDOCore.DebugFlag('SQL_Queries', "Timed out query: %s", query)
                safeCallback(nil)
            end
        end)
    end
    
    -- Try oxmysql first (most common)
    if GetResourceState('oxmysql') == 'started' then
        exports.oxmysql:execute(query, parameters, function(result)
            safeCallback(result)
        end)
        return
    end
    
    -- Try ghmattimysql
    if GetResourceState('ghmattimysql') == 'started' then
        exports.ghmattimysql:execute(query, parameters, function(result)
            safeCallback(result)
        end)
        return
    end
    
    -- Try mysql-async
    if GetResourceState('mysql-async') == 'started' then
        exports['mysql-async']:mysql_execute(query, parameters, function(result)
            safeCallback(result)
        end)
        return
    end
    
    ReDOCore.Error("No MySQL resource available!")
    safeCallback(nil)
end

-- Fetch multiple rows (SELECT)
function MySQL.Fetch(query, parameters, callback)
    if not query then
        ReDOCore.Error("MySQL.Fetch: query is required")
        if callback then callback(nil) end
        return
    end
    
    parameters = parameters or {}
    
    local cbFired = false
    local safeCallback = function(result)
        if cbFired then return end
        cbFired = true
        if callback then callback(result) end
    end
    
    if callback then
        SetTimeout(5000, function()
            if not cbFired then
                ReDOCore.Warn("MySQL.Fetch: Query callback timed out")
                safeCallback({})
            end
        end)
    end
    
    -- Try oxmysql
    if GetResourceState('oxmysql') == 'started' then
        exports.oxmysql:execute(query, parameters, function(result)
            safeCallback(result or {})
        end)
        return
    end
    
    -- Try ghmattimysql
    if GetResourceState('ghmattimysql') == 'started' then
        exports.ghmattimysql:execute(query, parameters, function(result)
            safeCallback(result or {})
        end)
        return
    end
    
    -- Try mysql-async
    if GetResourceState('mysql-async') == 'started' then
        exports['mysql-async']:mysql_fetch_all(query, parameters, function(result)
            safeCallback(result or {})
        end)
        return
    end
    
    ReDOCore.Error("No MySQL resource available!")
    safeCallback({})
end

-- Fetch single row
function MySQL.FetchOne(query, parameters, callback)
    MySQL.Fetch(query, parameters, function(results)
        if callback then
            callback(results and results[1] or nil)
        end
    end)
end

-- Fetch a single value
function MySQL.FetchScalar(query, parameters, callback)
    if not query then
        ReDOCore.Error("MySQL.FetchScalar: query is required")
        if callback then callback(nil) end
        return
    end
    
    parameters = parameters or {}
    
    -- Try oxmysql
    if GetResourceState('oxmysql') == 'started' then
        exports.oxmysql:scalar(query, parameters, function(result)
            if callback then callback(result) end
        end)
        return
    end
    
    -- Try ghmattimysql
    if GetResourceState('ghmattimysql') == 'started' then
        exports.ghmattimysql:scalar(query, parameters, function(result)
            if callback then callback(result) end
        end)
        return
    end
    
    -- Try mysql-async
    if GetResourceState('mysql-async') == 'started' then
        exports['mysql-async']:mysql_fetch_scalar(query, parameters, function(result)
            if callback then callback(result) end
        end)
        return
    end
    
    ReDOCore.Error("No MySQL resource available!")
    if callback then callback(nil) end
end

-- Insert and return the inserted ID
function MySQL.Insert(query, parameters, callback)
    if not query then
        ReDOCore.Error("MySQL.Insert: query is required")
        if callback then callback(nil) end
        return
    end
    
    parameters = parameters or {}
    
    -- Try oxmysql
    if GetResourceState('oxmysql') == 'started' then
        exports.oxmysql:insert(query, parameters, function(insertId)
            if callback then callback(insertId) end
        end)
        return
    end
    
    -- Try ghmattimysql  
    if GetResourceState('ghmattimysql') == 'started' then
        exports.ghmattimysql:execute(query, parameters, function(result)
            if callback then
                callback(result and result.insertId or result)
            end
        end)
        return
    end
    
    -- Try mysql-async
    if GetResourceState('mysql-async') == 'started' then
        exports['mysql-async']:mysql_insert(query, parameters, function(insertId)
            if callback then callback(insertId) end
        end)
        return
    end
    
    ReDOCore.Error("No MySQL resource available!")
    if callback then callback(nil) end
end

-- Transaction support
function MySQL.Transaction(queries, callback)
    if not queries or #queries == 0 then
        ReDOCore.Error("MySQL.Transaction: queries array is required")
        if callback then callback(false) end
        return
    end
    
    -- Try oxmysql
    if GetResourceState('oxmysql') == 'started' then
        exports.oxmysql:transaction(queries, function(success)
            if callback then callback(success) end
        end)
        return
    end
    
    -- Try ghmattimysql
    if GetResourceState('ghmattimysql') == 'started' then
        exports.ghmattimysql:transaction(queries, function(success)
            if callback then callback(success) end
        end)
        return
    end
    
    -- Try mysql-async
    if GetResourceState('mysql-async') == 'started' then
        exports['mysql-async']:mysql_transaction(queries, function(success)
            if callback then callback(success) end
        end)
        return
    end
    
    ReDOCore.Error("No MySQL resource available!")
    if callback then callback(false) end
end

-- Prepare a value for SQL (escape and quote)
function MySQL.Escape(value)
    if value == nil then
        return "NULL"
    elseif type(value) == "string" then
        return "'" .. value:gsub("'", "''") .. "'"
    elseif type(value) == "boolean" then
        return value and "1" or "0"
    else
        return tostring(value)
    end
end

ReDOCore.Info("MySQL handler loaded (multi-compatible)")

-- Make MySQL available within this resource.
-- Other files (sv_querybuilder, sv_database) run in the SAME Lua state,
-- so they can see this global.
ReDOCore.MySQL = MySQL

-- Export so OTHER resources can access MySQL directly.
exports('GetMySQL', function()
    return MySQL
end)
