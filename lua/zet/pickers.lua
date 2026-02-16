local M = {}

local config = require("zet.config")
local utils = require("zet.utils")

local function get_telescope()
    local has_telescope, _ = pcall(require, "telescope")
    if not has_telescope then
        vim.notify("Telescope is required for zet pickers", vim.log.levels.ERROR)
        return nil
    end
    return {
        pickers = require("telescope.pickers"),
        finders = require("telescope.finders"),
        conf = require("telescope.config").values,
        actions = require("telescope.actions"),
        action_state = require("telescope.actions.state"),
        themes = require("telescope.themes"),
    }
end

local function open_note(filepath)
    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
end

--- Find notes by filename using Telescope
function M.find_notes()
    local tel = get_telescope()
    if not tel then return end
    local cfg = config.get()

    local files = utils.collect_md_files(cfg.scan_dirs)

    -- Sort by modification time (newest first)
    table.sort(files, function(a, b)
        return vim.fn.getftime(a) > vim.fn.getftime(b)
    end)

    local entries = {}
    for _, f in ipairs(files) do
        table.insert(entries, {
            path = f,
            display_name = utils.basename(f),
        })
    end

    tel.pickers.new({}, {
        prompt_title = "Find Notes",
        finder = tel.finders.new_table({
            results = entries,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.display_name,
                    ordinal = entry.display_name,
                    filename = entry.path,
                }
            end,
        }),
        sorter = tel.conf.generic_sorter({}),
        previewer = tel.conf.file_previewer({}),
        attach_mappings = function(prompt_bufnr)
            tel.actions.select_default:replace(function()
                local selection = tel.action_state.get_selected_entry()
                tel.actions.close(prompt_bufnr)
                if selection then
                    open_note(selection.value.path)
                end
            end)
            return true
        end,
    }):find()
end

--- Find daily notes only
function M.find_daily_notes()
    local tel = get_telescope()
    if not tel then return end
    local cfg = config.get()

    local files = utils.collect_md_files(cfg.scan_dirs)

    -- Filter to daily notes only
    local dailies = {}
    for _, f in ipairs(files) do
        local basename = utils.basename(f)
        if basename:match("^%d%d%d%d%-%d%d%-%d%d%.md$") then
            table.insert(dailies, {
                path = f,
                display_name = basename,
            })
        end
    end

    -- Sort descending (newest first)
    table.sort(dailies, function(a, b)
        return a.display_name > b.display_name
    end)

    tel.pickers.new({}, {
        prompt_title = "Daily Notes",
        finder = tel.finders.new_table({
            results = dailies,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.display_name,
                    ordinal = entry.display_name,
                    filename = entry.path,
                }
            end,
        }),
        sorter = tel.conf.generic_sorter({}),
        previewer = tel.conf.file_previewer({}),
        attach_mappings = function(prompt_bufnr)
            tel.actions.select_default:replace(function()
                local selection = tel.action_state.get_selected_entry()
                tel.actions.close(prompt_bufnr)
                if selection then
                    open_note(selection.value.path)
                end
            end)
            return true
        end,
    }):find()
end

--- Live grep across all notes
function M.search_notes()
    local has_telescope, _ = pcall(require, "telescope")
    if not has_telescope then
        vim.notify("Telescope is required", vim.log.levels.ERROR)
        return
    end

    local cfg = config.get()
    local builtin = require("telescope.builtin")

    builtin.live_grep({
        prompt_title = "Search Notes",
        search_dirs = cfg.scan_dirs,
        glob_pattern = "*.md",
    })
end

--- Command palette showing all available commands
function M.panel()
    local tel = get_telescope()
    if not tel then return end
    local cfg = config.get()

    local commands = require("zet").command_list()
    local command_descriptions = {
        panel = "Command palette",
        find_notes = "Browse notes by filename",
        find_daily_notes = "Browse daily notes only",
        search_notes = "Live grep across all notes",
        new_note = "Create note with uuid-title filename",
        new_templated_note = "Pick a template, then create note",
        rename_note = "Rename + update all [[backlinks]]",
        follow_link = "Follow [[link]] under cursor",
        insert_link = "Pick a note, insert [[link]] at cursor",
        goto_today = "Open/create today's daily note",
        show_tags = "Browse all #tags via Telescope",
        show_calendar = "Open calendar-vim",
        reminder_scan = "Show due reminders",
        reminder_scan_upcoming = "Show reminders due within N hours",
        reminder_scan_all = "Show all reminders",
        reminder_edit = "Snooze/edit reminder on current line",
        reminder_recent_done = "Recently completed reminders (48h)",
        line_history = "Git history for line under cursor",
    }

    local entries = {}
    for _, cmd in ipairs(commands) do
        table.insert(entries, {
            name = cmd,
            description = command_descriptions[cmd] or "",
        })
    end

    local theme_opts = {}
    if cfg.command_palette_theme == "ivy" then
        theme_opts = tel.themes.get_ivy()
    elseif cfg.command_palette_theme == "dropdown" then
        theme_opts = tel.themes.get_dropdown()
    end

    tel.pickers.new(theme_opts, {
        prompt_title = "Zet",
        finder = tel.finders.new_table({
            results = entries,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.name .. " — " .. entry.description,
                    ordinal = entry.name .. " " .. entry.description,
                }
            end,
        }),
        sorter = tel.conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            tel.actions.select_default:replace(function()
                local selection = tel.action_state.get_selected_entry()
                tel.actions.close(prompt_bufnr)
                if selection then
                    local zk = require("zet")
                    if zk[selection.value.name] then
                        vim.schedule(function()
                            zk[selection.value.name]()
                        end)
                    end
                end
            end)
            return true
        end,
    }):find()
end

return M
