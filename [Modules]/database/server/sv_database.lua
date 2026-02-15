--[[
    Framework Database Functions
    
    Simple wrapper around the query builder for common operations.
    Uses the auto-table creation system.
]]

-- Track whether database is ready
local dbReady = false
local pendingSchemas = {}

-- Initialize database and create tables on server start
CreateThread(function()
    Wait(1000) -- Wait for MySQL to be ready
    
    ReDOCore.Info("Initializing database system...")
    ReDOCore.MySQL.Initialize()
    Wait(500)
    
    -- Create core tables only
    local coreTablesReady = false
    ReDOCore.DB.CreateAllTables(function(success)
        if not success then
            ReDOCore.Error("Database initialization failed!")
            return
        end
        ReDOCore.Info("Core tables ready!")
        coreTablesReady = true
    end)
    
    -- Wait for core tables to finish
    local timeout = 0
    while not coreTablesReady do
        Wait(100)
        timeout = timeout + 100
        if timeout > 10000 then
            ReDOCore.Error("Timed out waiting for core tables!")
            return
        end
    end
    
    -- Mark database as ready immediately
    dbReady = true
    ReDOCore.Info("Database ready! Accepting schema registrations.")
    TriggerEvent('framework:database:ready')
    
    -- Process anything already queued
    if #pendingSchemas > 0 then
        ReDOCore.Info("Creating %d queued table(s)...", #pendingSchemas)
        for _, tableName in ipairs(pendingSchemas) do
            ReDOCore.DB.CreateTable(tableName)
        end
        pendingSchemas = {}
    end
end)

-- Register a schema and auto-create the table
-- Works at ANY time - before or after database is ready
function ReDOCore.DB.RegisterSchema(tableName, schema)
    if not tableName or not schema then
        ReDOCore.Error("RegisterSchema: tableName and schema required")
        return
    end
    
    ReDOCore.DB.Schema[tableName] = schema
    ReDOCore.DebugFlag('SQL_SchemaRegister', "Schema registered: %s | dbReady: %s", tableName, tostring(dbReady))
    
    -- Skip if this is a core schema (already handled by CreateAllTables)
    if ReDOCore.DB.CoreSchemas[tableName] then
        return
    end
    
    if dbReady then
        ReDOCore.Info("Creating table from schema: %s", tableName)
        ReDOCore.DB.CreateTable(tableName)
    else
        ReDOCore.DebugFlag('SQL_SchemaRegister', "Queuing table: %s", tableName)
        table.insert(pendingSchemas, tableName)
    end
end

--[[
    ============================================================================
    PLAYER DATABASE FUNCTIONS (Using Query Builder)
    ============================================================================
]]

-- Load a player from database
function ReDOCore.LoadPlayerData(identifier, callback)
    if not identifier then
        ReDOCore.Error("LoadPlayerData: identifier is required")
        callback(nil)
        return
    end

    ReDOCore.Debug("Loading player from database: %s", identifier)

    ReDOCore.DB.Table('players')
        :Where('identifier', identifier)
        :First(function(player)
            if player then
                ReDOCore.Debug("Player found: %s (ID: %d)", player.name, player.id)
                
                -- Parse position from JSON
                local position = Config.Authorization.DefaultSpawn
                if player.position then
                    local success, pos = pcall(json.decode, player.position)
                    if success and pos and pos.x then
                        position = vector4(pos.x, pos.y, pos.z, pos.w or 0.0)
                    end
                end
                
                -- Parse metadata from JSON
                local metadata = {}
                if player.metadata then
                    local success, meta = pcall(json.decode, player.metadata)
                    if success and meta then
                        metadata = meta
                    end
                end
                
                -- Format data
                local data = {
                    dbId = player.id,
                    identifier = player.identifier,
                    license = player.license,
                    name = player.name,
                    group = player['group'] or "user",
                    money = {
                        cash = player.cash or 0,
                        bank = player.bank or 0,
                        gold = player.gold or 0
                    },
                    position = position,
                    metadata = metadata,
                    job = {
                        name = "unemployed",
                        label = "Unemployed",
                        grade = 0
                    }
                }
                
                callback(data)
            else
                ReDOCore.Debug("Player not found: %s", identifier)
                callback(nil)
            end
        end)
end

-- Save player to database
function ReDOCore.SavePlayerData(identifier, data)
    if not identifier or not data then
        ReDOCore.Error("SavePlayerData: identifier and data required")
        return
    end

    ReDOCore.Debug("Saving player: %s", identifier)

    -- Convert position to JSON
    local positionJson = nil
    if data.position then
        positionJson = json.encode({
            x = data.position.x,
            y = data.position.y,
            z = data.position.z,
            w = data.position.w or 0.0
        })
    end
    
    -- Convert metadata to JSON
    local metadataJson = nil
    if data.metadata then
        metadataJson = json.encode(data.metadata)
    end

    -- Build update data
    local updateData = {
        name = data.name,
        ['group'] = data.group,
        cash = data.money.cash,
        bank = data.money.bank,
        gold = data.money.gold,
        position = positionJson,
        metadata = metadataJson
    }

    -- Update player
    ReDOCore.DB.Table('players')
        :Where('identifier', identifier)
        :Update(updateData, function(affected)
            if affected and affected > 0 then
                ReDOCore.Debug("Player saved: %s", identifier)
            else
                ReDOCore.Warn("No rows updated for: %s", identifier)
            end
        end)
end

-- Create new player
function ReDOCore.CreatePlayerData(identifier, license, name, callback)
    if not identifier or not license or not name then
        ReDOCore.Error("CreatePlayerData: identifier, license, name required")
        if callback then callback(false) end
        return
    end

    ReDOCore.Info("Creating new player: %s (%s)", name, identifier)

    -- Get defaults
    local defaults = Config.Authorization.DefaultPlayerData
    local spawn = Config.Authorization.DefaultSpawn

    -- Convert position to JSON
    local positionJson = json.encode({
        x = spawn.x,
        y = spawn.y,
        z = spawn.z,
        w = spawn.w or 0.0
    })

    -- Build insert data
    local insertData = {
        identifier = identifier,
        license = license,
        name = name,
        ['group'] = defaults.group,
        cash = defaults.money.cash,
        bank = defaults.money.bank,
        gold = defaults.money.gold,
        position = positionJson,
        metadata = json.encode({})
    }

    -- Insert player
    ReDOCore.DB.Table('players')
        :Insert(insertData, function(insertId)
            if insertId then
                ReDOCore.Info("Player created with ID: %d", insertId)
                if callback then callback(true, insertId) end
            else
                ReDOCore.Error("Failed to create player!")
                if callback then callback(false) end
            end
        end)
end

--[[
    ============================================================================
    EXAMPLE USAGE (for other resources)
    ============================================================================
]]

--[[

-- Get all players with more than $1000 cash
ReDOCore.DB.Table('players')
    :Where('cash', '>', 1000)
    :OrderBy('cash', 'DESC')
    :Get(function(players)
        for _, player in ipairs(players) do
            print(player.name .. " has $" .. player.cash)
        end
    end)

-- Find player by ID
ReDOCore.DB.Find('players', 5, function(player)
    if player then
        print("Found: " .. player.name)
    end
end)

-- Update player money
ReDOCore.DB.Table('players')
    :Where('identifier', 'license:abc123')
    :Update({ cash = 5000 }, function(affected)
        print("Updated " .. affected .. " rows")
    end)

-- Delete inactive players
ReDOCore.DB.Table('players')
    :Where('last_seen', '<', '2024-01-01')
    :Delete(function(affected)
        print("Deleted " .. affected .. " inactive players")
    end)

-- Count total players
ReDOCore.DB.Table('players'):Count(function(count)
    print("Total players: " .. count)
end)

]]

ReDOCore.Info("Database wrapper functions loaded")
