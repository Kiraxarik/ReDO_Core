--[[
    Framework Database Functions
    
    Handles database initialization, schema registration, and 
    AUTOMATIC MIGRATION DETECTION.
    
    When a table already exists but the schema has changed, the system:
    1. Detects which columns were added, removed, or modified
    2. Logs the differences to the console
    3. Prompts the admin to accept or reject the changes
    4. Applies ALTER TABLE statements if accepted
    
    Commands:
    - db:yes  - Accept pending migrations
    - db:no   - Reject pending migrations (skip changes)
    - db:diff - Show pending migrations again
]]

-- Track whether database is ready
local dbReady = false
local pendingSchemas = {}

-- Migration system
local pendingMigrations = {}   -- { tableName = { diff = {}, statements = {} } }
local migrationWaiting = false -- Are we waiting for admin input?
local migrationResolved = false

--[[ =========================================================================
    COLUMN COMPARISON
    
    Fetches the actual columns from MySQL and compares them to the schema.
    Returns a diff describing what needs to change.
========================================================================= ]]

local function GetTableColumns(tableName, callback)
    local query = "SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? ORDER BY ORDINAL_POSITION"
    
    ReDOCore.MySQL.Fetch(query, {tableName}, function(results)
        local columns = {}
        if results then
            for _, row in ipairs(results) do
                -- MySQL might return uppercase or lowercase field names
                local name = row.COLUMN_NAME or row.column_name
                columns[name] = {
                    type = row.COLUMN_TYPE or row.column_type,
                    nullable = (row.IS_NULLABLE or row.is_nullable) == "YES",
                    default_val = row.COLUMN_DEFAULT or row.column_default,
                    extra = row.EXTRA or row.extra or ""
                }
            end
        end
        callback(columns)
    end)
end

local function CompareSchema(tableName, schema, actualColumns)
    local diff = {
        adds = {},      -- Columns in schema but not in database
        drops = {},     -- Columns in database but not in schema
        modifies = {},  -- Columns that exist but differ
        hasChanges = false
    }
    
    for colName, def in pairs(schema) do
        if not actualColumns[colName] then
            table.insert(diff.adds, colName)
            diff.hasChanges = true
        else
            local actual = actualColumns[colName]
            local expectedType = string.lower(def.type)
            local actualType = string.lower(actual.type)
            
            local changed = false
            
            if def.length then
                local expected = expectedType .. "(" .. tostring(def.length) .. ")"
                if actualType ~= expected then
                    changed = true
                end
            else
                -- Check base type (e.g., "int" should match "int(11)")
                if not string.find(actualType, expectedType, 1, true) then
                    changed = true
                end
            end
            
            -- Check NOT NULL mismatch
            if def.not_null and actual.nullable then
                changed = true
            end
            
            if changed then
                table.insert(diff.modifies, colName)
                diff.hasChanges = true
            end
        end
    end
    
    -- Columns in database but NOT in schema
    for colName, _ in pairs(actualColumns) do
        if not schema[colName] then
            table.insert(diff.drops, colName)
            diff.hasChanges = true
        end
    end
    
    return diff
end

--[[ =========================================================================
    GENERATE ALTER TABLE SQL
========================================================================= ]]

local function BuildColumnSQL(colName, def)
    local col = "`" .. colName .. "` "
    
    if def.length then
        col = col .. def.type .. "(" .. def.length .. ")"
    else
        col = col .. def.type
    end
    
    if def.auto_increment then
        col = col .. " AUTO_INCREMENT"
    end
    
    if def.not_null then
        col = col .. " NOT NULL"
    end
    
    if def.default then
        if def.default == "CURRENT_TIMESTAMP" then
            col = col .. " DEFAULT CURRENT_TIMESTAMP"
        elseif def.default == "NULL" then
            col = col .. " DEFAULT NULL"
        else
            col = col .. " DEFAULT '" .. def.default .. "'"
        end
    end
    
    if def.on_update then
        col = col .. " ON UPDATE " .. def.on_update
    end
    
    return col
end

local function GenerateAlterSQL(tableName, schema, diff)
    local statements = {}
    
    for _, colName in ipairs(diff.adds) do
        local def = schema[colName]
        local col = BuildColumnSQL(colName, def)
        table.insert(statements, string.format("ALTER TABLE `%s` ADD COLUMN %s", tableName, col))
        
        if def.unique and not def.primary then
            table.insert(statements, string.format("ALTER TABLE `%s` ADD UNIQUE KEY (`%s`)", tableName, colName))
        end
    end
    
    for _, colName in ipairs(diff.modifies) do
        local def = schema[colName]
        local col = BuildColumnSQL(colName, def)
        table.insert(statements, string.format("ALTER TABLE `%s` MODIFY COLUMN %s", tableName, col))
    end
    
    -- We do NOT auto-drop columns. That's destructive.
    -- We only warn about them.
    
    return statements
end

--[[ =========================================================================
    MIGRATION PROMPT
========================================================================= ]]

local function PrintMigrationSummary()
    print("")
    print("^3========================================^7")
    print("^3  DATABASE MIGRATIONS PENDING^7")
    print("^3========================================^7")
    
    for tableName, migration in pairs(pendingMigrations) do
        print(string.format("^3  Table: ^7%s", tableName))
        
        if #migration.diff.adds > 0 then
            print(string.format("^2    + Add columns:^7 %s", table.concat(migration.diff.adds, ", ")))
        end
        
        if #migration.diff.modifies > 0 then
            print(string.format("^3    ~ Modify columns:^7 %s", table.concat(migration.diff.modifies, ", ")))
        end
        
        if #migration.diff.drops > 0 then
            print(string.format("^1    - Extra columns (not in schema):^7 %s", table.concat(migration.diff.drops, ", ")))
            print("^8      (Will NOT be dropped. Remove manually if intended.)^7")
        end
        
        if migration.statements and #migration.statements > 0 then
            print("^5    SQL:^7")
            for _, sql in ipairs(migration.statements) do
                print(string.format("^5      %s^7", sql))
            end
        end
        
        print("")
    end
    
    print("^3========================================^7")
    print("^3  Type ^2db:yes^3 to apply changes^7")
    print("^3  Type ^1db:no^3  to skip^7")
    print("^3========================================^7")
    print("")
end

local function ApplyMigrations(callback)
    local allStatements = {}
    
    for tableName, migration in pairs(pendingMigrations) do
        for _, sql in ipairs(migration.statements) do
            table.insert(allStatements, sql)
        end
    end
    
    if #allStatements == 0 then
        ReDOCore.Info("No SQL statements to execute")
        pendingMigrations = {}
        if callback then callback() end
        return
    end
    
    local completed = 0
    local successCount = 0
    
    for _, sql in ipairs(allStatements) do
        ReDOCore.Info("Executing: %s", sql)
        ReDOCore.MySQL.Execute(sql, {}, function(result)
            completed = completed + 1
            if result ~= nil then
                successCount = successCount + 1
            else
                ReDOCore.Error("Migration failed: %s", sql)
            end
            
            if completed == #allStatements then
                ReDOCore.Info("Migrations complete: %d/%d succeeded", successCount, #allStatements)
                pendingMigrations = {}
                if callback then callback() end
            end
        end)
    end
end

-- Console commands
RegisterCommand('db:yes', function(source)
    if source ~= 0 then return end
    if not migrationWaiting then
        print("^3No pending migrations.^7")
        return
    end
    print("^2Applying migrations...^7")
    ApplyMigrations(function()
        print("^2Migrations applied!^7")
        migrationWaiting = false
        migrationResolved = true
    end)
end)

RegisterCommand('db:no', function(source)
    if source ~= 0 then return end
    if not migrationWaiting then
        print("^3No pending migrations.^7")
        return
    end
    print("^3Migrations skipped. Tables left unchanged.^7")
    pendingMigrations = {}
    migrationWaiting = false
    migrationResolved = true
end)

RegisterCommand('db:diff', function(source)
    if source ~= 0 then return end
    if not migrationWaiting or not next(pendingMigrations) then
        print("^3No pending migrations.^7")
        return
    end
    PrintMigrationSummary()
end)

--[[ =========================================================================
    SYNC TABLE
    
    Smart table creation/update:
    - If table doesn't exist → CREATE it
    - If table exists → compare schema, queue migrations if different
========================================================================= ]]

function ReDOCore.DB.SyncTable(tableName, callback)
    local schema = ReDOCore.DB.Schema[tableName]
    
    if not schema then
        ReDOCore.Error("No schema defined for table: %s", tableName)
        if callback then callback(false) end
        return
    end
    
    ReDOCore.DB.TableExists(tableName, function(exists)
        if not exists then
            -- Table doesn't exist — create it fresh
            ReDOCore.DB.CreateTable(tableName, callback)
        else
            -- Table exists — compare and detect changes
            GetTableColumns(tableName, function(actualColumns)
                local diff = CompareSchema(tableName, schema, actualColumns)
                
                if diff.hasChanges then
                    local statements = GenerateAlterSQL(tableName, schema, diff)
                    
                    pendingMigrations[tableName] = {
                        diff = diff,
                        statements = statements
                    }
                    
                    ReDOCore.Warn("Table '%s' has schema changes", tableName)
                else
                    ReDOCore.DebugFlag('SQL_TableExists', "Table '%s' is up to date", tableName)
                end
                
                if callback then callback(true) end
            end)
        end
    end)
end

--[[ =========================================================================
    INITIALIZATION
========================================================================= ]]

CreateThread(function()
    Wait(1000)
    
    ReDOCore.Info("Initializing database system...")
    ReDOCore.MySQL.Initialize()
    Wait(500)
    
    -- Process core tables
    local coreTablesReady = false
    ReDOCore.DB.CreateAllTables(function(success)
        if not success then
            ReDOCore.Error("Database initialization failed!")
            return
        end
        ReDOCore.Info("Core tables ready!")
        coreTablesReady = true
    end)
    
    local timeout = 0
    while not coreTablesReady do
        Wait(100)
        timeout = timeout + 100
        if timeout > 10000 then
            ReDOCore.Error("Timed out waiting for core tables!")
            return
        end
    end
    
    -- Mark database as ready so schemas can register
    dbReady = true
    ReDOCore.Info("Database ready! Accepting schema registrations.")
    TriggerEvent('framework:database:ready')
    
    -- Process queued schemas (from resources that loaded before DB was ready)
    if #pendingSchemas > 0 then
        ReDOCore.Info("Syncing %d queued table(s)...", #pendingSchemas)
        
        local syncCompleted = 0
        local syncTotal = #pendingSchemas
        
        for _, tableName in ipairs(pendingSchemas) do
            ReDOCore.DB.SyncTable(tableName, function()
                syncCompleted = syncCompleted + 1
            end)
        end
        
        -- Wait for all syncs to finish (30s allows for 5s MySQL timeouts)
        local syncTimeout = 0
        while syncCompleted < syncTotal do
            Wait(100)
            syncTimeout = syncTimeout + 100
            if syncTimeout > 30000 then
                ReDOCore.Error("Timed out syncing tables! (%d/%d completed)", syncCompleted, syncTotal)
                break
            end
        end
        
        pendingSchemas = {}
    end
    
    -- If migrations detected, prompt admin
    if next(pendingMigrations) then
        migrationWaiting = true
        PrintMigrationSummary()
        
        -- Wait for admin response
        while migrationWaiting do
            Wait(500)
        end
    else
        ReDOCore.Info("All tables up to date!")
    end
    
    ReDOCore.Info("Database initialization complete!")
end)

-- Register a schema and auto-sync the table
function ReDOCore.DB.RegisterSchema(tableName, schema)
    if not tableName or not schema then
        ReDOCore.Error("RegisterSchema: tableName and schema required")
        return
    end
    
    ReDOCore.DB.Schema[tableName] = schema
    ReDOCore.DebugFlag('SQL_SchemaRegister', "Schema registered: %s | dbReady: %s", tableName, tostring(dbReady))
    
    if ReDOCore.DB.CoreSchemas[tableName] then
        return
    end
    
    if dbReady then
        ReDOCore.Info("Syncing table from schema: %s", tableName)
        ReDOCore.DB.SyncTable(tableName)
    else
        ReDOCore.DebugFlag('SQL_SchemaRegister', "Queuing table: %s", tableName)
        table.insert(pendingSchemas, tableName)
    end
end

ReDOCore.Info("Database wrapper functions loaded")
