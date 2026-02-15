--[[
    Player Module - Server
    
    Handles player data, schema definition, and player management.
]]

-- Define the players table
ReDOCore.DB.RegisterSchema('players', {
    id = { type = "INT", auto_increment = true, primary = true },
    identifier = { type = "VARCHAR", length = 50, unique = true, not_null = true },
    license = { type = "VARCHAR", length = 50, unique = true, not_null = true },
    name = { type = "VARCHAR", length = 100, not_null = true },
    ['group'] = { type = "VARCHAR", length = 50, default = "user" },
    cash = { type = "INT", default = 500 },
    bank = { type = "INT", default = 0 },
    gold = { type = "INT", default = 0 },
    position = { type = "TEXT" },
    metadata = { type = "TEXT" },
    last_seen = { type = "TIMESTAMP", default = "CURRENT_TIMESTAMP", on_update = "CURRENT_TIMESTAMP" }
})

ReDOCore.Info("Player module loaded")
