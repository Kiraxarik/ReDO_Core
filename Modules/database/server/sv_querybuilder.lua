--[[
    Database Query Builder & ORM
    
    Auto-generates SQL queries and manages tables automatically.
    Makes it SUPER easy to work with databases!
    
    Example usage:
        DB.Table('players')
          :Create()  -- Auto-creates table
          :Insert({ name = "John", cash = 500 })
          :Where('name', 'John')
          :Get()
]]

ReDOCore.DB = ReDOCore.DB or {}
ReDOCore.DB.Tables = {}
ReDOCore.DB.Schema = {}
ReDOCore.DB.CoreSchemas = {} -- Tracks which schemas belong to the core

-- NOTE: Table schemas are defined in their respective modules
-- Example: modules/player defines the players table
--          modules/inventory defines the inventory table

--[[
    ============================================================================
    AUTO TABLE CREATION
    ============================================================================
]]

-- Generate CREATE TABLE SQL from schema
local function GenerateCreateTableSQL(tableName, schema)
    local columns = {}
    local primaryKeys = {}
    local uniqueKeys = {}
    
    -- Build column definitions
    for columnName, def in pairs(schema) do
        local col = "`" .. columnName .. "` "
        
        -- Data type
        if def.length then
            col = col .. def.type .. "(" .. def.length .. ")"
        else
            col = col .. def.type
        end
        
        -- Auto increment
        if def.auto_increment then
            col = col .. " AUTO_INCREMENT"
        end
        
        -- Not null
        if def.not_null then
            col = col .. " NOT NULL"
        end
        
        -- Default value
        if def.default then
            if def.default == "CURRENT_TIMESTAMP" then
                col = col .. " DEFAULT CURRENT_TIMESTAMP"
            else
                col = col .. " DEFAULT '" .. def.default .. "'"
            end
        end
        
        -- On update
        if def.on_update then
            col = col .. " ON UPDATE " .. def.on_update
        end
        
        table.insert(columns, col)
        
        -- Track primary and unique keys
        if def.primary then
            table.insert(primaryKeys, "`" .. columnName .. "`")
        end
        if def.unique and not def.primary then
            table.insert(uniqueKeys, "`" .. columnName .. "`")
        end
    end
    
    -- Add primary key
    if #primaryKeys > 0 then
        local pkLine = "PRIMARY KEY (" .. table.concat(primaryKeys, ", ") .. ")"
        table.insert(columns, pkLine)
    end
    
    -- Add unique keys
    for _, key in ipairs(uniqueKeys) do
        local ukLine = "UNIQUE KEY (" .. key .. ")"
        table.insert(columns, ukLine)
    end
    
    -- Build final SQL
    local sql = "CREATE TABLE IF NOT EXISTS `" .. tableName .. "` (\n  "
    sql = sql .. table.concat(columns, ",\n  ")
    sql = sql .. "\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
    
    return sql
end

-- Check if table exists
function ReDOCore.DB.TableExists(tableName, callback)
    local query = "SELECT COUNT(*) as count FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?"
    
    ReDOCore.MySQL.FetchOne(query, {tableName}, function(result)
        callback(result and result.count > 0)
    end)
end

-- Create table from schema
function ReDOCore.DB.CreateTable(tableName, callback)
    local schema = ReDOCore.DB.Schema[tableName]
    
    if not schema then
        ReDOCore.Error("No schema defined for table: %s", tableName)
        if callback then callback(false) end
        return
    end
    
    -- Check if table already exists
    ReDOCore.DB.TableExists(tableName, function(exists)
        if exists then
            ReDOCore.DebugFlag('SQL_TableExists', "Table '%s' already exists, skipping creation", tableName)
            if callback then callback(true) end
            return
        end
        
        -- Generate and execute CREATE TABLE
        local sql = GenerateCreateTableSQL(tableName, schema)
        
        ReDOCore.Info("Creating table: %s", tableName)
        ReDOCore.DebugFlag('SQL_Queries', "SQL: %s", sql)
        
        ReDOCore.MySQL.Execute(sql, {}, function(result)
            if result ~= nil then
                ReDOCore.Info("Table '%s' created successfully!", tableName)
                if callback then callback(true) end
            else
                ReDOCore.Error("Failed to create table: %s", tableName)
                if callback then callback(false) end
            end
        end)
    end)
end

-- Drop (delete) a table
function ReDOCore.DB.DropTable(tableName, callback)
    ReDOCore.Warn("Dropping table: %s", tableName)
    
    local sql = "DROP TABLE IF EXISTS `" .. tableName .. "`"
    
    ReDOCore.MySQL.Execute(sql, {}, function(result)
        if result ~= nil then
            ReDOCore.Info("Table '%s' dropped successfully!", tableName)
            if callback then callback(true) end
        else
            ReDOCore.Error("Failed to drop table: %s", tableName)
            if callback then callback(false) end
        end
    end)
end

-- Create all defined CORE tables only
function ReDOCore.DB.CreateAllTables(callback)
    ReDOCore.Info("Creating all defined tables...")
    
    local tables = {}
    for tableName, _ in pairs(ReDOCore.DB.CoreSchemas) do
        table.insert(tables, tableName)
    end
    
    local completed = 0
    local total = #tables
    
    if total == 0 then
        ReDOCore.Warn("No tables defined in schema!")
        if callback then callback(true) end
        return
    end
    
    for _, tableName in ipairs(tables) do
        ReDOCore.DB.CreateTable(tableName, function(success)
            completed = completed + 1
            
            if completed == total then
                ReDOCore.Info("All tables processed!")
                if callback then callback(true) end
            end
        end)
    end
end

--[[
    ============================================================================
    QUERY BUILDER
    ============================================================================
]]

-- Create a new query builder instance
function ReDOCore.DB.Table(tableName)
    local query = {
        table = tableName,
        whereConditions = {},
        selectColumns = "*",
        limitCount = nil,
        offsetCount = nil,
        orderByColumn = nil,
        orderByDirection = "ASC"
    }
    
    -- SELECT columns
    function query:Select(columns)
        if type(columns) == "table" then
            self.selectColumns = "`" .. table.concat(columns, "`, `") .. "`"
        else
            self.selectColumns = columns
        end
        return self
    end
    
    -- WHERE condition
    function query:Where(column, operator, value)
        -- Support both :Where('col', 'value') and :Where('col', '=', 'value')
        if value == nil then
            value = operator
            operator = "="
        end
        
        table.insert(self.whereConditions, {
            column = column,
            operator = operator,
            value = value
        })
        return self
    end
    
    -- ORDER BY
    function query:OrderBy(column, direction)
        self.orderByColumn = column
        self.orderByDirection = direction or "ASC"
        return self
    end
    
    -- LIMIT
    function query:Limit(count)
        self.limitCount = count
        return self
    end
    
    -- OFFSET
    function query:Offset(count)
        self.offsetCount = count
        return self
    end
    
    -- Build WHERE clause
    local function BuildWhereClause(conditions)
        if #conditions == 0 then
            return "", {}
        end
        
        local clauses = {}
        local params = {}
        
        for _, condition in ipairs(conditions) do
            table.insert(clauses, "`" .. condition.column .. "` " .. condition.operator .. " ?")
            table.insert(params, condition.value)
        end
        
        return " WHERE " .. table.concat(clauses, " AND "), params
    end
    
    -- GET (SELECT)
    function query:Get(callback)
        local sql = "SELECT " .. self.selectColumns .. " FROM `" .. self.table .. "`"
        local whereClause, params = BuildWhereClause(self.whereConditions)
        sql = sql .. whereClause
        
        if self.orderByColumn then
            sql = sql .. " ORDER BY `" .. self.orderByColumn .. "` " .. self.orderByDirection
        end
        
        if self.limitCount then
            sql = sql .. " LIMIT " .. self.limitCount
        end
        
        if self.offsetCount then
            sql = sql .. " OFFSET " .. self.offsetCount
        end
        
        ReDOCore.MySQL.Fetch(sql, params, callback)
    end
    
    -- FIRST (SELECT single row)
    function query:First(callback)
        self:Limit(1)
        self:Get(function(results)
            callback(results and results[1] or nil)
        end)
    end
    
    -- INSERT
    function query:Insert(data, callback)
        local columns = {}
        local placeholders = {}
        local values = {}
        
        for column, value in pairs(data) do
            table.insert(columns, "`" .. column .. "`")
            table.insert(placeholders, "?")
            table.insert(values, value)
        end
        
        local sql = "INSERT INTO `" .. self.table .. "` (" 
        sql = sql .. table.concat(columns, ", ") .. ") VALUES (" 
        sql = sql .. table.concat(placeholders, ", ") .. ")"
        
        ReDOCore.MySQL.Insert(sql, values, callback)
    end
    
    -- UPDATE
    function query:Update(data, callback)
        local setClauses = {}
        local params = {}
        
        for column, value in pairs(data) do
            table.insert(setClauses, "`" .. column .. "` = ?")
            table.insert(params, value)
        end
        
        local sql = "UPDATE `" .. self.table .. "` SET " .. table.concat(setClauses, ", ")
        local whereClause, whereParams = BuildWhereClause(self.whereConditions)
        sql = sql .. whereClause
        
        -- Add where params after set params
        for _, param in ipairs(whereParams) do
            table.insert(params, param)
        end
        
        ReDOCore.MySQL.Execute(sql, params, callback)
    end
    
    -- DELETE
    function query:Delete(callback)
        local sql = "DELETE FROM `" .. self.table .. "`"
        local whereClause, params = BuildWhereClause(self.whereConditions)
        sql = sql .. whereClause
        
        if #self.whereConditions == 0 then
            ReDOCore.Warn("DELETE without WHERE clause! This will delete ALL rows!")
        end
        
        ReDOCore.MySQL.Execute(sql, params, callback)
    end
    
    -- COUNT
    function query:Count(callback)
        local sql = "SELECT COUNT(*) as count FROM `" .. self.table .. "`"
        local whereClause, params = BuildWhereClause(self.whereConditions)
        sql = sql .. whereClause
        
        ReDOCore.MySQL.FetchScalar(sql, params, callback)
    end
    
    return query
end

--[[
    ============================================================================
    HELPER FUNCTIONS FOR EASY ACCESS
    ============================================================================
]]

-- Quick insert
function ReDOCore.DB.Insert(tableName, data, callback)
    ReDOCore.DB.Table(tableName):Insert(data, callback)
end

-- Quick select all
function ReDOCore.DB.GetAll(tableName, callback)
    ReDOCore.DB.Table(tableName):Get(callback)
end

-- Quick find by ID
function ReDOCore.DB.Find(tableName, id, callback)
    ReDOCore.DB.Table(tableName):Where('id', id):First(callback)
end

ReDOCore.Info("Query Builder & ORM loaded")
