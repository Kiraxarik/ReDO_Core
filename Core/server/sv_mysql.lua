--[[
    Custom MySQL Connection Handler
    
    Auto-detects and uses any MySQL resource (oxmysql, mysql-async, or ghmattimysql)
    NO MANUAL CONFIGURATION NEEDED!
]]

ReDOCore.MySQL = {}

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
function ReDOCore.MySQL.Initialize()
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
        ReDOCore.Info("Detected MySQL resource: %s", mysqlResource)
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
function ReDOCore.MySQL.IsConnected()
    return isConnected
end

-- Execute a query (INSERT, UPDATE, DELETE) using built-in natives
function ReDOCore.MySQL.Execute(query, parameters, callback)
    if not query then
        ReDOCore.Error("MySQL.Execute: query is required")
        if callback then callback(nil) end
        return
    end
    
    parameters = parameters or {}
    
    -- Try oxmysql first (most common)
    if GetResourceState('oxmysql') == 'started' then
        exports.oxmysql:execute(query, parameters, function(result)
            if callback then callback(result) end
        end)
        return
    end
    
    -- Try ghmattimysql
    if GetResourceState('ghmattimysql') == 'started' then
        exports.ghmattimysql:execute(query, parameters, function(result)
            if callback then callback(result) end
        end)
        return
    end
    
    -- Try mysql-async
    if GetResourceState('mysql-async') == 'started' then
        exports['mysql-async']:mysql_execute(query, parameters, function(result)
            if callback then callback(result) end
        end)
        return
    end
    
    ReDOCore.Error("No MySQL resource available!")
    if callback then callback(nil) end
end

-- Fetch multiple rows (SELECT)
function ReDOCore.MySQL.Fetch(query, parameters, callback)
    if not query then
        ReDOCore.Error("MySQL.Fetch: query is required")
        if callback then callback(nil) end
        return
    end
    
    parameters = parameters or {}
    
    -- Try oxmysql
    if GetResourceState('oxmysql') == 'started' then
        exports.oxmysql:execute(query, parameters, function(result)
            if callback then callback(result or {}) end
        end)
        return
    end
    
    -- Try ghmattimysql
    if GetResourceState('ghmattimysql') == 'started' then
        exports.ghmattimysql:execute(query, parameters, function(result)
            if callback then callback(result or {}) end
        end)
        return
    end
    
    -- Try mysql-async
    if GetResourceState('mysql-async') == 'started' then
        exports['mysql-async']:mysql_fetch_all(query, parameters, function(result)
            if callback then callback(result or {}) end
        end)
        return
    end
    
    ReDOCore.Error("No MySQL resource available!")
    if callback then callback({}) end
end

-- Fetch single row
function ReDOCore.MySQL.FetchOne(query, parameters, callback)
    ReDOCore.MySQL.Fetch(query, parameters, function(results)
        if callback then
            callback(results and results[1] or nil)
        end
    end)
end

-- Fetch a single value
function ReDOCore.MySQL.FetchScalar(query, parameters, callback)
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
function ReDOCore.MySQL.Insert(query, parameters, callback)
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
function ReDOCore.MySQL.Transaction(queries, callback)
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
function ReDOCore.MySQL.Escape(value)
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
