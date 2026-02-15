--[[
    Auto Table Cleanup System
    
    Tracks which tables are defined in schemas and can automatically
    remove tables that are no longer defined after a grace period.
]]

ReDOCore.DB.TableRegistry = {}
ReDOCore.DB.OrphanedTables = {}

-- Track when tables were last seen
local function LoadTableRegistry()
    -- Load from a tracking file or database
    -- For now, we'll use a simple table in memory
    -- In production, this should persist to a file or database table
    
    ReDOCore.DB.TableRegistry = {
        -- Format: 
        -- ['table_name'] = { last_seen = timestamp, status = 'active' }
    }
end

-- Save table registry (should persist to file/database)
local function SaveTableRegistry()
    -- TODO: Save to file or database for persistence
    -- For now it's in-memory only
end

-- Scan database for all tables
function ReDOCore.DB.GetAllDatabaseTables(callback)
    local query = [[
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = DATABASE() 
        AND table_type = 'BASE TABLE'
    ]]
    
    ReDOCore.MySQL.Fetch(query, {}, function(results)
        local tables = {}
        if results then
            for _, row in ipairs(results) do
                table.insert(tables, row.table_name or row.TABLE_NAME)
            end
        end
        callback(tables)
    end)
end

-- Check for orphaned tables
function ReDOCore.DB.ScanForOrphanedTables(callback)
    ReDOCore.Info("Scanning for orphaned tables...")
    
    ReDOCore.DB.GetAllDatabaseTables(function(dbTables)
        local orphaned = {}
        local currentTime = os.time()
        
        for _, tableName in ipairs(dbTables) do
            -- Check if this table is in our schema
            local inSchema = ReDOCore.DB.Schema[tableName] ~= nil
            
            if inSchema then
                -- Table is defined - mark as active
                ReDOCore.DB.TableRegistry[tableName] = {
                    last_seen = currentTime,
                    status = 'active'
                }
            else
                -- Table exists but not in schema - potential orphan
                if not ReDOCore.DB.TableRegistry[tableName] then
                    -- First time seeing this orphan
                    ReDOCore.DB.TableRegistry[tableName] = {
                        last_seen = currentTime,
                        first_orphaned = currentTime,
                        status = 'orphaned'
                    }
                    ReDOCore.Warn("Detected orphaned table: %s", tableName)
                else
                    -- Update existing orphan
                    ReDOCore.DB.TableRegistry[tableName].status = 'orphaned'
                end
                
                table.insert(orphaned, {
                    name = tableName,
                    orphaned_since = ReDOCore.DB.TableRegistry[tableName].first_orphaned,
                    days_orphaned = math.floor((currentTime - ReDOCore.DB.TableRegistry[tableName].first_orphaned) / 86400)
                })
            end
        end
        
        ReDOCore.DB.OrphanedTables = orphaned
        
        if #orphaned > 0 then
            ReDOCore.Info("Found %d orphaned table(s)", #orphaned)
            for _, orphan in ipairs(orphaned) do
                ReDOCore.Info("  - %s (orphaned for %d days)", orphan.name, orphan.days_orphaned)
            end
        else
            ReDOCore.Info("No orphaned tables found")
        end
        
        SaveTableRegistry()
        
        if callback then callback(orphaned) end
    end)
end

-- Auto-cleanup orphaned tables after grace period
function ReDOCore.DB.CleanupOrphanedTables(gracePeriodDays, callback)
    gracePeriodDays = gracePeriodDays or 7 -- Default 7 days
    
    ReDOCore.Info("Cleaning up tables orphaned for more than %d days...", gracePeriodDays)
    
    ReDOCore.DB.ScanForOrphanedTables(function(orphaned)
        local deleted = 0
        local toDelete = {}
        
        -- Find tables past grace period
        for _, orphan in ipairs(orphaned) do
            if orphan.days_orphaned >= gracePeriodDays then
                table.insert(toDelete, orphan.name)
            end
        end
        
        if #toDelete == 0 then
            ReDOCore.Info("No tables to clean up")
            if callback then callback(0) end
            return
        end
        
        -- Delete each table
        for _, tableName in ipairs(toDelete) do
            ReDOCore.Warn("Auto-deleting orphaned table: %s", tableName)
            ReDOCore.DB.DropTable(tableName, function(success)
                if success then
                    deleted = deleted + 1
                    ReDOCore.DB.TableRegistry[tableName] = nil
                    
                    if deleted == #toDelete then
                        ReDOCore.Info("Cleanup complete: %d table(s) removed", deleted)
                        SaveTableRegistry()
                        if callback then callback(deleted) end
                    end
                end
            end)
        end
    end)
end

-- Get list of orphaned tables
function ReDOCore.DB.GetOrphanedTables()
    return ReDOCore.DB.OrphanedTables
end

-- Manual command to check for orphans
RegisterCommand('db:scan', function(source)
    if source ~= 0 then return end -- Console only
    
    ReDOCore.DB.ScanForOrphanedTables()
end)

-- Manual command to cleanup orphans
RegisterCommand('db:cleanup', function(source, args)
    if source ~= 0 then return end -- Console only
    
    local days = tonumber(args[1]) or 7
    
    print("^3Starting cleanup with " .. days .. " day grace period...^7")
    ReDOCore.DB.CleanupOrphanedTables(days, function(count)
        print("^2Cleanup complete: " .. count .. " table(s) removed^7")
    end)
end)

-- Initialize - wait for database to be fully ready first
AddEventHandler('framework:database:ready', function()
    LoadTableRegistry()
    
    -- Single scan after everything is loaded
    if Config.Database and Config.Database.AutoScanOrphans then
        -- Give all resources extra time to finish registering schemas
        Wait(1000)
        ReDOCore.DB.ScanForOrphanedTables(function(orphaned)
            -- Auto-cleanup if enabled
            if Config.Database.AutoCleanup and #orphaned > 0 then
                local gracePeriod = Config.Database.CleanupGracePeriodDays or 7
                ReDOCore.DB.CleanupOrphanedTables(gracePeriod)
            end
        end)
    end
    
    -- Schedule periodic scans if enabled
    if Config.Database and Config.Database.PeriodicScan then
        local interval = (Config.Database.ScanIntervalHours or 24) * 60 * 60 * 1000
        
        CreateThread(function()
            while true do
                Wait(interval)
                ReDOCore.DB.ScanForOrphanedTables(function(orphaned)
                    if Config.Database.AutoCleanup and #orphaned > 0 then
                        local gracePeriod = Config.Database.CleanupGracePeriodDays or 7
                        ReDOCore.DB.CleanupOrphanedTables(gracePeriod)
                    end
                end)
            end
        end)
    end
end)

ReDOCore.Info("Table cleanup system loaded")
