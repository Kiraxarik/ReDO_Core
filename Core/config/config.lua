--[[
    Framework Configuration - Authorization

    Configure player authorization, permissions, and groups
]]

-- Initialize Config table
Config = Config or {}

Config.Authorization = {
    -- Whitelist Settings
    UseWhitelist = false, -- Set to true to enable whitelist
    
    -- Default spawn location for new players
    DefaultSpawn = vector4(-1035.71, -2730.88, 12.86, 0.0), -- Valentine
    
    -- Connection Messages
    Messages = {
        NoLicense = "Connection refused: No license identifier found",
        Banned = "You are banned from this server",
        NotWhitelisted = "You are not whitelisted on this server. Please apply at our website.",
        ServerFull = "Server is full. Please try again later."
    },
    
    -- Super Admins (always whitelisted, bypass all checks)
    -- Add license identifiers here
    SuperAdmins = {
        -- "license:1234567890abcdef",
        -- "license:fedcba0987654321"
    },
    
    -- Permission Groups
    Groups = {
        ["user"] = {
            label = "User",
            priority = 0,
            permissions = {}
        },
        
        ["vip"] = {
            label = "VIP",
            priority = 1,
            permissions = {
                "vip.priority", -- Priority queue
                "vip.chat" -- VIP chat color
            }
        },
        
        ["moderator"] = {
            label = "Moderator",
            priority = 5,
            permissions = {
                "mod.kick",
                "mod.warn",
                "mod.mute",
                "mod.spectate",
                "mod.tp",
                "mod.freeze"
            }
        },
        
        ["admin"] = {
            label = "Admin",
            priority = 10,
            permissions = {
                "mod.*", -- All moderator permissions
                "admin.ban",
                "admin.unban",
                "admin.whitelist",
                "admin.setgroup",
                "admin.givemoney",
                "admin.giveitem",
                "admin.vehicle",
                "admin.weapon",
                "admin.noclip",
                "admin.god",
                "admin.revive"
            }
        },
        
        ["superadmin"] = {
            label = "Super Admin",
            priority = 100,
            permissions = {
                "*" -- All permissions
            }
        }
    },
    
    -- Default values for new players
    DefaultPlayerData = {
        group = "user",
        job = {
            name = "unemployed",
            label = "Unemployed",
            grade = 0
        },
        money = {
            cash = 500,
            bank = 0,
            gold = 0
        },
        metadata = {}
    }
}

-- Logging Configuration
Config.Logging = {
    Level = "DEBUG", -- TRACE, DEBUG, INFO, WARN, ERROR
    
    -- Log specific events
    LogPlayerConnections = true,
    LogPlayerDisconnections = true,
    LogAuthorizationAttempts = true,
    LogPermissionChecks = false, -- Can be spammy
    LogMoneyTransactions = true,
    LogAdminCommands = true
}

-- Database Configuration
Config.Database = {
    -- Orphaned Table Management
    AutoScanOrphans = true,        -- Scan for orphaned tables on startup
    AutoCleanup = true,            -- Automatically delete orphaned tables (USE WITH CAUTION!)
    CleanupGracePeriodDays = 0,    -- Days before an orphaned table is deleted
    
    -- Periodic Scanning
    PeriodicScan = true,           -- Scan for orphans periodically
    ScanIntervalHours = 24,        -- How often to scan (in hours)
    
    -- Manual Commands Available:
    -- db:scan - Check for orphaned tables
    -- db:cleanup [days] - Delete tables orphaned for X days (default 7)
}

print("^2[ReDOCore]^7 Authorization config loaded")
