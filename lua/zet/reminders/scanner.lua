-- Reminder scanner: discovers and filters reminders across vault directories
local M = {}

local time_parser = require("zet.reminders.time_parser")

-- A list to store reminders that are due or past
M.reminders = {}

-- Function to parse a line for a reminder and return reminder, datetime, is_checked
local function parse_reminder_line(line)
    -- Extract the datetime in ISO 8601 format
    local datetime = line:match("#reminder (%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ)")

    -- Check for both new and old style checkboxes, anywhere in the line
    local is_checked = line:match("%* %[%s?[xX]%s?%]") ~= nil or line:match(": ?%[x%]") ~= nil

    -- Extract the full reminder line including #reminder
    local reminder = line:match("%#reminder.*")

    return reminder, datetime, is_checked
end

-- Function to determine if a reminder is upcoming (within threshold_hours from now)
local function is_upcoming(datetime, threshold_hours)
    threshold_hours = threshold_hours or 48

    -- Parse the ISO 8601 datetime
    local year = tonumber(datetime:sub(1, 4))
    local month = tonumber(datetime:sub(6, 7))
    local day = tonumber(datetime:sub(9, 10))
    local hour = tonumber(datetime:sub(12, 13))
    local min = tonumber(datetime:sub(15, 16))
    local sec = tonumber(datetime:sub(18, 19))

    local reminder_time = os.time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min,
        sec = sec,
        isdst = false,
    })

    local now_utc = os.date("!*t")
    local now = os.time({
        year = now_utc.year,
        month = now_utc.month,
        day = now_utc.day,
        hour = now_utc.hour,
        min = now_utc.min,
        sec = now_utc.sec,
        isdst = false,
    })

    local diff_seconds = reminder_time - now
    local threshold_seconds = threshold_hours * 3600

    -- Upcoming means: in the future AND within the threshold
    return diff_seconds > 0 and diff_seconds <= threshold_seconds
end

-- Function to determine if a reminder is due or past
local function is_due_or_past(datetime)
    local time_diff = time_parser.time_until(datetime)
    return time_diff:find("now") or time_diff:find(" ago") or time_diff:find("in 0 minutes")
end

-- Function to handle adding reminders to the list based on conditions
local function add_reminder(file_path, i, line, datetime, upcoming, all_reminders, threshold_hours)
    if all_reminders then
        table.insert(M.reminders, {
            file = file_path,
            line_number = i,
            text = line,
            datetime = datetime,
        })
    elseif upcoming and is_upcoming(datetime, threshold_hours) then
        table.insert(M.reminders, {
            file = file_path,
            line_number = i,
            text = line,
            datetime = datetime,
        })
    elseif not upcoming and is_due_or_past(datetime) then
        table.insert(M.reminders, {
            file = file_path,
            line_number = i,
            text = line,
            datetime = datetime,
        })
    end
end

-- Function to scan a file for reminders and add them to the list based on the condition
local function scan_file(file_path, upcoming, all_reminders, threshold_hours)
    local lines = vim.fn.readfile(file_path)
    for i, line in ipairs(lines) do
        local reminder, datetime, is_checked = parse_reminder_line(line)
        if datetime and (all_reminders or not is_checked) then
            add_reminder(file_path, i, reminder, datetime, upcoming, all_reminders, threshold_hours)
        end
    end
end

--- Get scan dirs from zet config
local function get_scan_dirs()
    local cfg = require("zet.config").get()
    return cfg.scan_dirs or { cfg.home }
end

-- Function to scan all configured paths for due reminders
function M.scan_paths(paths)
    paths = paths or get_scan_dirs()
    M.reminders = {}
    for _, path in ipairs(paths) do
        -- Always scan recursively
        local files = vim.fn.globpath(path, "**/*.md", false, true)
        for _, file in ipairs(files) do
            scan_file(file, false, false)
        end
    end
end

-- Function to scan all configured paths for upcoming reminders
function M.scan_paths_upcoming(paths, threshold_hours)
    paths = paths or get_scan_dirs()
    M.reminders = {}
    for _, path in ipairs(paths) do
        local files = vim.fn.globpath(path, "**/*.md", false, true)
        for _, file in ipairs(files) do
            scan_file(file, true, false, threshold_hours)
        end
    end
end

-- Determine if a reminder's due date was within the last N hours
local function was_due_within(datetime, hours)
    hours = hours or 48

    local year = tonumber(datetime:sub(1, 4))
    local month = tonumber(datetime:sub(6, 7))
    local day = tonumber(datetime:sub(9, 10))
    local hour = tonumber(datetime:sub(12, 13))
    local min = tonumber(datetime:sub(15, 16))
    local sec = tonumber(datetime:sub(18, 19))

    local reminder_time = os.time({
        year = year, month = month, day = day,
        hour = hour, min = min, sec = sec, isdst = false,
    })

    local now_utc = os.date("!*t")
    local now = os.time({
        year = now_utc.year, month = now_utc.month, day = now_utc.day,
        hour = now_utc.hour, min = now_utc.min, sec = now_utc.sec, isdst = false,
    })

    local diff_seconds = now - reminder_time
    local threshold_seconds = hours * 3600

    -- Due date is in the past AND within the lookback window
    return diff_seconds >= 0 and diff_seconds <= threshold_seconds
end

-- Scan a file for recently completed reminders (checked + due within lookback window)
local function scan_file_recent_done(file_path, lookback_hours)
    local lines = vim.fn.readfile(file_path)
    for i, line in ipairs(lines) do
        local reminder, datetime, is_checked = parse_reminder_line(line)
        if datetime and is_checked and was_due_within(datetime, lookback_hours) then
            table.insert(M.reminders, {
                file = file_path,
                line_number = i,
                text = line,
                datetime = datetime,
            })
        end
    end
end

-- Scan all configured paths for recently completed reminders
function M.scan_paths_recent_done(paths, lookback_hours)
    paths = paths or get_scan_dirs()
    lookback_hours = lookback_hours or 48
    M.reminders = {}
    for _, path in ipairs(paths) do
        local files = vim.fn.globpath(path, "**/*.md", false, true)
        for _, file in ipairs(files) do
            scan_file_recent_done(file, lookback_hours)
        end
    end
end

-- Function to scan all configured paths for all reminders
function M.scan_paths_all(paths)
    paths = paths or get_scan_dirs()
    M.reminders = {}
    for _, path in ipairs(paths) do
        local files = vim.fn.globpath(path, "**/*.md", false, true)
        for _, file in ipairs(files) do
            scan_file(file, false, true)
        end
    end
end

return M
