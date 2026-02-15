--[[ =========================================================================
    FILE: shared/sh_schemas.lua
    LOAD ORDER: First file in the player module (shared)
    RUNS ON: Both server and client

    PURPOSE:
    Defines the database table structures (schemas) for the player system.
    We moved from a single "players" table to three tables:

        accounts    - WHO the player is (Steam ID, license, login info)
        characters  - WHO they play as (name, money, position) 
        bans        - Ban records checked on connect

    WHY THREE TABLES?
    One account can have multiple characters (like WoW/GTA Online).
    If we stored everything in one table, you'd need a new row per
    character AND duplicate all the account info (Steam ID, group, etc).
    That's messy and wastes space. Splitting them means:
    - Account info is stored ONCE
    - Each character just references the account via account_id
    - Bans are tracked separately with full history

    WHY SHARED?
    The client doesn't talk to the database, but it might need to know
    the structure for validation or UI purposes later. It's also just
    good practice to keep schema definitions in one place.
========================================================================= ]]

-- Get the framework object from the Core resource.
-- exports['Core'] calls into the Core resource.
-- :GetCoreObject() runs the function we defined in sv_main.lua.
-- This gives us access to ReDOCore.DB.RegisterSchema and everything else.
local ReDOCore = exports['Core']:GetCoreObject()

-- Schema registration only runs on the SERVER.
-- The client doesn't have access to the database module.
-- IsDuplicityVersion() returns true on server, false on client.
if not IsDuplicityVersion() then
    return
end

-- Wait briefly for the database module to initialize.
-- The database resource sets up ReDOCore.DB when it starts.
-- Since we depend on 'database' in our fxmanifest, it should
-- already be loaded, but we check just in case.
if not ReDOCore.DB then
    ReDOCore.Error("Player module: ReDOCore.DB not available! Is the database module running?")
    return
end

--[[ =========================================================================
    ACCOUNTS TABLE
    
    One row per real person. This is the "login" - it identifies the human
    behind the keyboard, not the character they play.
    
    A player connects -> we find/create their account -> they pick a character.
========================================================================= ]]
ReDOCore.DB.RegisterSchema('accounts', {
    -- Primary key: auto-incrementing integer.
    -- Every account gets a unique number (1, 2, 3...).
    -- "primary = true" makes this the PRIMARY KEY in MySQL.
    -- "auto_increment = true" means MySQL assigns the next number automatically.
    id = {
        type = "INT",
        auto_increment = true,
        primary = true
    },

    -- Steam identifier. Format: "steam:110000xxxxxxxx"
    -- This is the DEFAULT primary lookup method.
    -- "unique = true" means no two accounts can have the same Steam ID.
    -- This prevents duplicate accounts.
    steam = {
        type = "VARCHAR",
        length = 50,
        unique = true
    },

    -- Rockstar license. Format: "license:xxxxxxxxxxxxxxx"
    -- Always collected on connect as a secondary identifier.
    license = {
        type = "VARCHAR",
        length = 50,
        unique = true
    },

    -- Discord identifier. Format: "discord:xxxxxxxxxxxxxxxxxx"
    -- Optional — only populated if the player has Discord linked.
    discord = {
        type = "VARCHAR",
        length = 50
    },

    -- Custom auth: username (optional, for players who choose this method)
    -- NULL if they use Steam auth instead.
    username = {
        type = "VARCHAR",
        length = 50
    },

    -- Custom auth: hashed password.
    -- NEVER store plain text passwords. We'll hash them with a salt.
    -- NULL if they use Steam auth.
    -- Length 255 to fit bcrypt/argon2 hashes.
    password_hash = {
        type = "VARCHAR",
        length = 255
    },

    -- Permission group: "user", "admin", "superadmin", etc.
    -- This is on the ACCOUNT level, not character level.
    -- If you're an admin, you're an admin on all your characters.
    ['group'] = {
        type = "VARCHAR",
        length = 50,
        default = "user"
    },

    -- How many characters this account is allowed to have.
    -- You could sell extra character slots or give them to VIPs.
    max_characters = {
        type = "INT",
        default = "3"
    },

    -- When this account was first created.
    -- CURRENT_TIMESTAMP is a MySQL function that inserts the current date/time.
    created_at = {
        type = "TIMESTAMP",
        default = "CURRENT_TIMESTAMP"
    },

    -- Updates automatically every time any column in this row changes.
    -- Useful for seeing "when was this player last active?"
    last_seen = {
        type = "TIMESTAMP",
        default = "CURRENT_TIMESTAMP",
        on_update = "CURRENT_TIMESTAMP"
    }
})

--[[ =========================================================================
    CHARACTERS TABLE
    
    One row per character. An account can have multiple characters.
    Each character has their own name, money, position, and inventory.
    
    The "account_id" column links back to the accounts table.
    This is a FOREIGN KEY relationship:
        accounts.id (1) ──── (many) characters.account_id
========================================================================= ]]
ReDOCore.DB.RegisterSchema('characters', {
    id = {
        type = "INT",
        auto_increment = true,
        primary = true
    },

    -- Links this character to an account.
    -- If account #5 has 3 characters, all 3 rows will have account_id = 5.
    -- "not_null = true" means every character MUST belong to an account.
    account_id = {
        type = "INT",
        not_null = true
    },

    -- Character name split into two fields for flexibility.
    -- This lets you display "John" or "John Smith" or search by last name.
    first_name = {
        type = "VARCHAR",
        length = 50,
        not_null = true
    },

    last_name = {
        type = "VARCHAR",
        length = 50,
        not_null = true
    },

    -- Money is per-character, not per-account.
    -- Character A can be rich, Character B can be broke.
    cash = {
        type = "INT",
        default = "500"
    },

    bank = {
        type = "INT",
        default = "0"
    },

    gold = {
        type = "INT",
        default = "0"
    },

    -- Job system. Stored as simple strings for now.
    -- Later you might make a jobs table, but this works to start.
    job_name = {
        type = "VARCHAR",
        length = 50,
        default = "unemployed"
    },

    job_label = {
        type = "VARCHAR",
        length = 100,
        default = "Unemployed"
    },

    job_grade = {
        type = "INT",
        default = "0"
    },

    -- Position stored as JSON: {"x": -1035.71, "y": -2730.88, "z": 12.86, "w": 0.0}
    -- TEXT type can hold long strings. We JSON encode/decode it in Lua.
    position = {
        type = "TEXT"
    },

    -- Metadata is a catch-all JSON field for anything you want to store
    -- that doesn't deserve its own column. Examples:
    -- { "hunger": 80, "thirst": 65, "jailTime": 0, "licenses": ["hunting", "fishing"] }
    -- This keeps the schema flexible without adding columns for every feature.
    metadata = {
        type = "TEXT"
    },

    -- Track when characters were created and last used.
    -- "last_played" helps show "last played 3 days ago" in character select.
    created_at = {
        type = "TIMESTAMP",
        default = "CURRENT_TIMESTAMP"
    },

    last_played = {
        type = "TIMESTAMP",
        default = "CURRENT_TIMESTAMP",
        on_update = "CURRENT_TIMESTAMP"
    }
})

--[[ =========================================================================
    BANS TABLE
    
    Tracks all bans, past and present.
    
    WHY A SEPARATE TABLE?
    - You can ban by ANY identifier (steam, license, discord, IP)
    - You keep a history (who banned them, when, why)
    - Temp bans: check expires_at to see if it's still active
    - Unbanning doesn't delete the record, just sets active = false
    
    When a player connects, we check: "does any ACTIVE ban exist
    where the identifier matches any of this player's identifiers?"
========================================================================= ]]
ReDOCore.DB.RegisterSchema('bans', {
    id = {
        type = "INT",
        auto_increment = true,
        primary = true
    },

    -- Which account was banned (can be NULL if banning by identifier
    -- before we even have an account, like IP bans).
    account_id = {
        type = "INT"
    },

    -- The specific identifier that was banned.
    -- Could be "steam:xxxx", "license:xxxx", "discord:xxxx", or even an IP.
    -- We check ALL of the connecting player's identifiers against this.
    identifier = {
        type = "VARCHAR",
        length = 100,
        not_null = true
    },

    -- Human-readable reason shown to the player when they try to connect.
    reason = {
        type = "VARCHAR",
        length = 255,
        default = "No reason provided"
    },

    -- Who issued the ban. Could be an admin's name or "SYSTEM" for auto-bans.
    banned_by = {
        type = "VARCHAR",
        length = 100,
        default = "SYSTEM"
    },

    -- When the ban expires. NULL = permanent ban.
    -- For temp bans, you'd set this to a future date.
    -- On connect, check: expires_at IS NULL OR expires_at > NOW()
    expires_at = {
        type = "TIMESTAMP"
    },

    -- Is this ban currently active?
    -- When an admin unbans someone, set this to 0 instead of deleting.
    -- That way you keep the history.
    -- "TINYINT" is MySQL's boolean — 0 = false, 1 = true.
    active = {
        type = "TINYINT",
        length = 1,
        default = "1",
        not_null = true
    },

    -- When the ban was created.
    created_at = {
        type = "TIMESTAMP",
        default = "CURRENT_TIMESTAMP"
    }
})

ReDOCore.Info("Player module schemas registered (accounts, characters, bans)")
