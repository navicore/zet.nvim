local M = {}

local config = require("zet.config")
local dates = require("zet.dates")
local utils = require("zet.utils")

--- Open calendar-vim
function M.show_calendar()
    local cfg = config.get()

    -- Set calendar-vim options
    if cfg.calendar_opts then
        if cfg.calendar_opts.weeknm then
            vim.g.calendar_weeknm = cfg.calendar_opts.weeknm
        end
        if cfg.calendar_opts.calendar_monday then
            vim.g.calendar_monday = cfg.calendar_opts.calendar_monday
        end
        if cfg.calendar_opts.calendar_mark then
            vim.g.calendar_mark = cfg.calendar_opts.calendar_mark
        end
    end

    vim.cmd("Calendar")
end

--- Calendar action callback: when a date is clicked, open/create that day's note
function M.calendar_action(day, month, year, week, dir)
    local cfg = config.get()
    local date_str = string.format("%04d-%02d-%02d", year, month, day)
    local filepath = cfg.home .. "/" .. date_str .. cfg.extension

    if utils.file_exists(filepath) then
        vim.cmd("edit " .. vim.fn.fnameescape(filepath))
    elseif cfg.dailies_create_nonexisting then
        local time = os.time({ year = year, month = month, day = day })
        local vars = dates.template_vars(time)
        vars.title = date_str

        local template_path = cfg.template_new_daily
        local templates = require("zet.templates")
        local lines = templates.apply(template_path, vars)
        if lines then
            utils.write_lines(filepath, lines)
        else
            utils.write_lines(filepath, {
                "---",
                "title: " .. date_str,
                "date: " .. date_str,
                "---",
                "",
            })
        end
        vim.cmd("edit " .. vim.fn.fnameescape(filepath))
    end
end

--- Calendar sign callback: mark days that have notes
function M.calendar_sign(day, month, year)
    local cfg = config.get()
    local date_str = string.format("%04d-%02d-%02d", year, month, day)
    local filepath = cfg.home .. "/" .. date_str .. cfg.extension

    if utils.file_exists(filepath) then
        return 1
    end
    return 0
end

--- Setup calendar-vim integration
function M.setup()
    local cfg = config.get()
    if not cfg.plug_into_calendar then
        return
    end

    -- Point calendar-vim at the autoload bridge functions
    vim.g.calendar_action = "zet#calendar_action"
    vim.g.calendar_sign = "zet#calendar_sign"
end

return M
