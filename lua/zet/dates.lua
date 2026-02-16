local M = {}

--- Format a date as YYYY-MM-DD
function M.today()
    return os.date("%Y-%m-%d")
end

--- Format a date as YYYY-MM-DD from a time value
function M.format_date(time)
    return os.date("%Y-%m-%d", time)
end

--- Format a date for display (human-readable)
function M.human_date(time)
    return os.date("%A, %B %d, %Y", time)
end

--- Get the current ISO-8601 week number and year
function M.week_number(time)
    time = time or os.time()
    local wn = tonumber(os.date("%W", time))
    local year = tonumber(os.date("%Y", time))
    return year, wn
end

--- Format a week string like YYYY-W05
function M.week_string(time)
    local year, wn = M.week_number(time)
    return string.format("%04d-W%02d", year, wn)
end

--- Generate a UUID based on the configured pattern
function M.generate_uuid(uuid_type)
    uuid_type = uuid_type or "%Y-%m-%d-%H%M"
    return os.date(uuid_type)
end

--- Check if a filename looks like a daily note (YYYY-MM-DD.md)
function M.is_daily(filename)
    return filename:match("^%d%d%d%d%-%d%d%-%d%d%.md$") ~= nil
end

--- Check if a filename looks like a weekly note (YYYY-WNN.md)
function M.is_weekly(filename)
    return filename:match("^%d%d%d%d%-W%d%d%.md$") ~= nil
end

--- Get the daily note filename for a given date
function M.daily_filename(time)
    time = time or os.time()
    return os.date("%Y-%m-%d", time) .. ".md"
end

--- Get the weekly note filename for a given date
function M.weekly_filename(time)
    return M.week_string(time) .. ".md"
end

--- Parse a YYYY-MM-DD string into a time value
function M.parse_date(date_str)
    local year, month, day = date_str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if year then
        return os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day) })
    end
    return nil
end

--- Get template variables for a given time
function M.template_vars(time)
    time = time or os.time()
    return {
        date = os.date("%Y-%m-%d", time),
        time = os.date("%H:%M", time),
        year = os.date("%Y", time),
        month = os.date("%m", time),
        day = os.date("%d", time),
        hdate = os.date("%A, %B %d, %Y", time),
        week = M.week_string(time),
        title = "", -- filled in by caller
        uuid = "", -- filled in by caller
    }
end

return M
