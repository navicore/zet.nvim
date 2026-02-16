local M = {}

local config = require("zet.config")
local utils = require("zet.utils")
local notes = require("zet.notes")

--- Extract [[link_text]] under the cursor
function M.link_under_cursor()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-indexed

    -- Find all [[...]] in the line and check which one the cursor is in
    local start = 1
    while true do
        local s, e = line:find("%[%[.-%]%]", start)
        if not s then
            break
        end
        if col >= s and col <= e then
            -- Extract the link text (without [[ and ]])
            local link = line:sub(s + 2, e - 2)
            -- Handle aliases: [[target|alias]] -> target
            local target = link:match("^([^|]+)|") or link
            -- Handle headings: [[target#heading]] -> target
            local base = target:match("^([^#]+)#") or target
            return base, s, e
        end
        start = e + 1
    end
    return nil
end

--- Resolve a link title to a filepath, searching all scan dirs
function M.resolve_link(link_title)
    local cfg = config.get()
    local ext = cfg.extension

    for _, dir in ipairs(cfg.scan_dirs) do
        -- Try exact match
        local filepath = dir .. "/" .. link_title .. ext
        if utils.file_exists(filepath) then
            return filepath
        end

        -- Try with underscores for spaces
        local safe_title = link_title:gsub(" ", "_")
        filepath = dir .. "/" .. safe_title .. ext
        if utils.file_exists(filepath) then
            return filepath
        end

        -- Search recursively for a matching filename
        local files = vim.fn.globpath(dir, "**/" .. link_title .. ext, false, true)
        if #files > 0 then
            return files[1]
        end

        files = vim.fn.globpath(dir, "**/" .. safe_title .. ext, false, true)
        if #files > 0 then
            return files[1]
        end

        -- Try matching by stem (for uuid-prefixed files)
        files = vim.fn.globpath(dir, "**/*" .. link_title .. ext, false, true)
        for _, f in ipairs(files) do
            local stem = utils.stem(f)
            -- Check if the title matches the part after uuid prefix
            local title_part = stem:match("^%d%d%d%d%-%d%d%-%d%d%-%d%d%d%d%-(.+)$")
            if title_part then
                local normalized = title_part:gsub("_", " ")
                if normalized == link_title or title_part == link_title then
                    return f
                end
            end
        end
    end

    return nil
end

--- Follow the [[link]] under the cursor
function M.follow_link()
    local cfg = config.get()
    local link_title = M.link_under_cursor()

    if not link_title then
        vim.notify("No [[link]] under cursor", vim.log.levels.INFO)
        return
    end

    local filepath = M.resolve_link(link_title)

    if filepath then
        vim.cmd("edit " .. vim.fn.fnameescape(filepath))
        return
    end

    -- Create if configured
    if cfg.follow_creates_nonexisting then
        notes.new_note(link_title)
    else
        vim.notify("Note not found: " .. link_title, vim.log.levels.WARN)
    end
end

--- Insert a [[link]] at the cursor position by picking a note via Telescope
function M.insert_link()
    local cfg = config.get()

    local has_telescope, _ = pcall(require, "telescope")
    if not has_telescope then
        vim.notify("Telescope is required", vim.log.levels.ERROR)
        return
    end

    local pickers_mod = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    local files = utils.collect_md_files(cfg.scan_dirs)
    local entries = {}
    for _, f in ipairs(files) do
        table.insert(entries, {
            path = f,
            display_name = utils.stem(f),
            title = utils.title_from_filename(utils.basename(f)),
        })
    end

    pickers_mod.new({}, {
        prompt_title = "Insert Link",
        finder = finders.new_table({
            results = entries,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.display_name,
                    ordinal = entry.display_name .. " " .. entry.title,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if selection then
                    local link_text = "[[" .. selection.value.display_name .. "]]"
                    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
                    local line = vim.api.nvim_get_current_line()
                    local new_line = line:sub(1, col) .. link_text .. line:sub(col + 1)
                    vim.api.nvim_set_current_line(new_line)
                    vim.api.nvim_win_set_cursor(0, { row, col + #link_text })
                end
            end)
            return true
        end,
    }):find()
end

return M
