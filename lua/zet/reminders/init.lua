-- Reminder subsystem orchestration and commands
local M = {}

local scanner = require("zet.reminders.scanner")
local snooze = require("zet.reminders.snooze")
local time_parser = require("zet.reminders.time_parser")

--- Check if a line contains a reminder
function M.is_reminder(line)
    return line:match("#reminder") ~= nil
end

--- Scan and show due reminders via Telescope
function M.scan(upcoming, threshold_hours)
    local cfg = require("zet.config").get()
    local paths = cfg.scan_dirs or { cfg.home }

    if upcoming then
        threshold_hours = threshold_hours or (cfg.reminders and cfg.reminders.default_threshold_hours) or 48
        scanner.scan_paths_upcoming(paths, threshold_hours)
    else
        scanner.scan_paths(paths)
    end

    local telescope_reminders = require("zet.reminders.telescope")
    telescope_reminders.reminder_picker({
        paths = paths,
        scan_type = upcoming and "upcoming" or "due",
        prompt_title = upcoming and "Upcoming Reminders" or "Due Reminders",
        threshold_hours = threshold_hours,
    })
end

--- Scan and show all reminders
function M.scan_all()
    local cfg = require("zet.config").get()
    local paths = cfg.scan_dirs or { cfg.home }

    scanner.scan_paths_all(paths)

    local telescope_reminders = require("zet.reminders.telescope")
    telescope_reminders.reminder_picker({
        paths = paths,
        scan_type = "all",
        prompt_title = "All Reminders",
    })
end

--- Scan and show recently completed reminders
function M.scan_recent_done(lookback_hours)
    local cfg = require("zet.config").get()
    local paths = cfg.scan_dirs or { cfg.home }
    lookback_hours = lookback_hours or (cfg.reminders and cfg.reminders.default_threshold_hours) or 48

    scanner.scan_paths_recent_done(paths, lookback_hours)

    local telescope_reminders = require("zet.reminders.telescope")
    telescope_reminders.reminder_picker({
        paths = paths,
        scan_type = "recent_done",
        prompt_title = "Recently Done (" .. lookback_hours .. "h)",
        threshold_hours = lookback_hours,
    })
end

--- Edit/snooze the reminder on the current line
function M.edit()
    local line = vim.api.nvim_get_current_line()
    if not M.is_reminder(line) then
        vim.notify("Not a reminder line", vim.log.levels.INFO)
        return
    end

    local line_nr = vim.api.nvim_win_get_cursor(0)[1]

    -- Build choices from shared module, add "quit" option
    local choices = vim.list_extend(vim.deepcopy(snooze.choices), { "quit" })

    local pickers_mod = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers_mod.new({}, {
        prompt_title = "Select a time interval",
        finder = finders.new_table({
            results = choices,
        }),
        sorter = conf.generic_sorter({}),
        layout_config = {
            width = 0.3,
        },
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if selection and selection[1] ~= "quit" then
                    M.save_datetime(line_nr, selection[1])
                end
            end)
            return true
        end,
    }):find()
end

--- Save a new datetime to a reminder line
function M.save_datetime(line_nr, choice)
    if not choice then
        vim.notify("Invalid choice. Not updating.", vim.log.levels.WARN)
        return
    end

    local line = vim.api.nvim_buf_get_lines(0, line_nr - 1, line_nr, false)[1]

    if not M.is_reminder(line) then
        vim.notify("Not a reminder line. Not updating.", vim.log.levels.WARN)
        return
    end

    local new_datetime = snooze.calculate_new_datetime(choice)

    if not new_datetime then
        vim.notify("Failed to calculate new datetime.", vim.log.levels.ERROR)
        return
    end

    local new_line = line:gsub("(%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ)", new_datetime)
    vim.api.nvim_buf_set_lines(0, line_nr - 1, line_nr, false, { new_line })
end

--- Setup reminder commands and autocmds
function M.setup()
    local cfg = require("zet.config").get()
    if not cfg.reminders or not cfg.reminders.enabled then
        return
    end

    -- Set up autocmds for auto-conversion and virtual text
    require("zet.reminders.autocmds").setup_autocmds()
end

return M
