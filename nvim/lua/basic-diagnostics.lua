-- ~/.config/nvim/lua/loclist-diagnostics/init.lua
-- Or any other location in your runtime path

-- Core Neovim APIs
local api = vim.api
local fn = vim.fn
local diagnostic = vim.diagnostic

-- Module definition
local M = {}

-- =============================================================================
-- Configuration
-- =============================================================================
local config = {
    severity_sort = true, -- Sort diagnostics by severity first, then line number
    auto_open_list = true, -- Automatically open loclist window after populating
    loclist_win_cmd = "lwindow", -- Command to open loclist window ('lwindow', 'lopen')
    loclist_title = "Buffer Diagnostics", -- Title for the location list

    -- Icons for different diagnostic severities (requires Nerd Font or similar)
    signs = {
        Error = "", -- Error icon
        Warn = "",  -- Warning icon
        Info = "",  -- Info icon
        Hint = "",  -- Hint icon
    },
    -- Mapping from diagnostic severity to loclist item type ('E', 'W', 'I', 'N')
    -- Note: 'N' (NOTE) might not be highlighted in all themes, 'I' is safer.
    severity_type_map = {
        Error = 'E',
        Warn = 'W',
        Info = 'I',
        Hint = 'I', -- Map Hint to Info type for broader compatibility
    },
}

-- =============================================================================
-- Plugin State
-- =============================================================================
-- Internal state of the plugin
local state = {
    augroup_id = nil, -- Autocommand group ID
    last_updated_bufnr = nil, -- Track the last buffer for which loclist was populated by toggle/open
}

-- =============================================================================
-- Helper Functions
-- =============================================================================

-- Get the string name for a diagnostic severity level
-- @param severity (number) The severity level (vim.diagnostic.severity.*)
-- @return (string) The capitalized name ("Error", "Warn", "Info", "Hint")
local function get_severity_name(severity)
    for name, val in pairs(diagnostic.severity) do
        if val == severity then
            return name:gsub("^%l", string.upper) -- Capitalize first letter
        end
    end
    return "Unknown"
end

-- Check if the location list window is currently open
-- @return (boolean) True if the loclist window is open, false otherwise
local function is_loclist_open()
    for _, wininfo in ipairs(fn.getwininfo()) do
        if wininfo.loclist == 1 then
            return true
        end
    end
    return false
end

-- Format diagnostics into a list suitable for setloclist()
-- @param bufnr (number) The buffer number to get diagnostics for
-- @return (table) List of loclist item dictionaries, or empty table if none
local function format_diagnostics_for_loclist(bufnr)
    -- Ensure bufnr is valid before getting diagnostics
    if not bufnr or type(bufnr) ~= "number" or not api.nvim_buf_is_valid(bufnr) then
        return {} -- Return empty list if buffer is invalid
    end

    local diagnostics_list = diagnostic.get(bufnr)
    local loclist_items = {}

    -- Sort diagnostics if configured
    if config.severity_sort then
        table.sort(diagnostics_list, function(a, b)
            if a.severity ~= b.severity then
                return a.severity < b.severity -- Lower severity number is higher priority
            end
            return a.lnum < b.lnum -- Then sort by line number
        end)
    end

    -- Format each diagnostic
    for _, diag in ipairs(diagnostics_list) do
        local severity_name = get_severity_name(diag.severity)
        local icon = config.signs[severity_name] or "?"
        local item_type = config.severity_type_map[severity_name] or 'I' -- Default to Info type

        -- Format text: Icon Severity Line:Col Message
        local text = string.format(
            "%s %-4s %4d:%-3d %s",
            icon,
            severity_name,
            diag.lnum + 1, -- lnum is 0-indexed
            diag.col + 1,  -- col is 0-indexed
            diag.message:gsub("[\n\r]+", " ") -- Replace newlines/carriage returns
        )

        table.insert(loclist_items, {
            bufnr = diag.bufnr,
            lnum = diag.lnum + 1, -- loclist uses 1-based line numbers
            col = diag.col + 1,    -- loclist uses 1-based column numbers
            text = text,
            type = item_type,
        })
    end

    return loclist_items
end

-- =============================================================================
-- Core Plugin Functions
-- =============================================================================

-- Populate the location list for the current window with diagnostics
-- @param bufnr_override (number, optional) Use this buffer instead of current
function M.populate(bufnr_override)
    local target_bufnr = bufnr_override or api.nvim_get_current_buf()
    state.last_updated_bufnr = target_bufnr -- Track which buffer we just populated for

    local items = format_diagnostics_for_loclist(target_bufnr)

    -- Set the location list for the *current* window (winid 0)
    -- 'r' replaces the list; ' ' would also work to replace/create
    -- Use pcall for safety, in case window 0 is invalid during startup/shutdown
    local ok, err = pcall(fn.setloclist, 0, items, 'r', config.loclist_title)
    if not ok then
        vim.notify("Error setting location list: " .. tostring(err), vim.log.levels.ERROR)
        return -- Stop if setting loclist failed
    end


    -- Optionally open the location list window if configured and items exist
    if config.auto_open_list and #items > 0 then
        -- Check if it's already open before trying to open again
        if not is_loclist_open() then
            vim.cmd(config.loclist_win_cmd)
        end
    elseif #items == 0 then
        -- If there are no items, maybe close the loclist window if it's open?
        if is_loclist_open() then
            vim.cmd('lclose')
        end
    end
end

-- Close the location list window
function M.close()
    if is_loclist_open() then
        vim.cmd('lclose')
    end
end

-- Toggle the location list: populate and open if closed, close if open
function M.toggle()
    if is_loclist_open() then
        M.close()
    else
        -- Populate for the current buffer and open (if auto_open_list is true)
        M.populate()
        -- Explicitly open if auto_open is false but we still want toggle to open it
        -- Or if populate didn't open it because there were no items initially
        if not is_loclist_open() then
            -- Only open if there are items in the list now
            -- Use pcall for safety when getting list
            local ok, list_items = pcall(fn.getloclist, 0)
            if ok and list_items and #list_items > 0 then
                vim.cmd(config.loclist_win_cmd)
            else
                vim.notify("No diagnostics to show in location list.", vim.log.levels.INFO)
            end
        end
    end
end

-- Update the location list for the window associated with the changed buffer
-- This is intended to be called by autocommands
-- @param changed_bufnr (number) The buffer number where diagnostics changed
function M.update(changed_bufnr)
    -- *** FIX: Add check for valid buffer number ***
    if not changed_bufnr or type(changed_bufnr) ~= "number" then
        vim.notify("LoclistDiagnostics: Invalid buffer number received in update: " .. tostring(changed_bufnr), vim.log.levels.DEBUG)
        return -- Exit early if buffer number is invalid
    end

    -- Ensure buffer is still valid before proceeding
    if not api.nvim_buf_is_valid(changed_bufnr) then
        vim.notify("LoclistDiagnostics: Buffer " .. changed_bufnr .. " no longer valid in update.", vim.log.levels.DEBUG)
        return -- Exit if buffer is gone
    end

    -- Find the window ID currently displaying the buffer where diagnostics changed
    -- Use pcall for safety as bufwinid can error in edge cases
    local ok, target_winid = pcall(fn.bufwinid, changed_bufnr)

    if not ok or target_winid == -1 or target_winid == 0 then
        -- vim.notify("LoclistDiagnostics: No window found for buffer " .. changed_bufnr .. " in update.", vim.log.levels.DEBUG)
        -- Buffer not visible in any window, or error occurred. No loclist to update for it.
        return
    end

    local items = format_diagnostics_for_loclist(changed_bufnr)
    local loclist_open = is_loclist_open()

    -- Update the location list for that specific window
    -- Use pcall for safety
    local update_ok, update_err = pcall(fn.setloclist, target_winid, items, 'r', config.loclist_title)
    if not update_ok then
        vim.notify("Error updating location list for win " .. target_winid .. ": " .. tostring(update_err), vim.log.levels.WARN)
    end

    if config.auto_open_list then
        if #items > 0 and not loclist_open then
            vim.cmd(config.loclist_win_cmd)
        elseif #items == 0 and loclist_open then
            vim.cmd('lclose')
        end
    end
end

-- =============================================================================
-- Autocommands
-- =============================================================================
-- Function to setup autocommands for automatic updates
function M.setup_autocommands()
    -- Create a dedicated augroup
    state.augroup_id = api.nvim_create_augroup("LoclistDiagnosticsAu", { clear = true })

    -- Update diagnostics when they change in *any* buffer
    api.nvim_create_autocmd("DiagnosticChanged", {
        group = state.augroup_id,
        pattern = "*",
        callback = function(args)
            -- args contains { bufnr, namespace, severity, diagnostics }
            -- Schedule the update to run safely in the main loop
            vim.schedule(function()
                -- Pass the buffer number directly from args
                M.update(args.bufnr)
            end)
        end,
        desc = "Update location list diagnostics on diagnostic change",
    })
end

-- =============================================================================
-- Public API / Setup
-- =============================================================================

-- Placeholder for a potential setup function
-- function M.setup(user_config)
--  config = vim.tbl_deep_extend("force", config, user_config or {})
--  -- Add validation or post-processing for config if needed
-- end

-- Initialize autocommands when the module is loaded
M.setup_autocommands()

-- Return the public functions
return M

