local M = {}

local fn = vim.fn

M.defaults = {
    home = "~/git/navicore/zet",
    templates = "~/git/navicore/zet/templates",
    template_new_note = nil,
    template_new_daily = nil,
    template_new_weekly = nil,

    new_note_filename = "uuid-title",
    uuid_type = "%Y-%m-%d-%H%M",
    uuid_sep = "-",
    filename_space_subst = "_",
    extension = ".md",

    -- Year-based archive dirs to scan for links and search
    archive_dirs = {},

    follow_creates_nonexisting = true,
    dailies_create_nonexisting = true,
    rename_update_links = true,
    tag_notation = "#tag",

    plug_into_calendar = true,
    calendar_opts = {
        weeknm = 4,
        calendar_monday = 1,
        calendar_mark = "left-fit",
    },

    auto_set_filetype = true,
    command_palette_theme = "ivy",
    default_keymaps = true,

    reminders = {
        enabled = true,
        scan_on_save = true,
        show_virtual_text = true,
        default_threshold_hours = 48,
    },
}

function M.setup(user_config)
    M.config = vim.tbl_deep_extend("force", {}, M.defaults, user_config or {})

    -- Expand paths
    M.config.home = fn.expand(M.config.home)
    M.config.templates = fn.expand(M.config.templates)
    if M.config.template_new_note then
        M.config.template_new_note = fn.expand(M.config.template_new_note)
    end
    if M.config.template_new_daily then
        M.config.template_new_daily = fn.expand(M.config.template_new_daily)
    end
    if M.config.template_new_weekly then
        M.config.template_new_weekly = fn.expand(M.config.template_new_weekly)
    end

    -- Build scan_dirs: home + expanded archive dirs
    M.config.scan_dirs = { M.config.home }
    for _, dir in ipairs(M.config.archive_dirs) do
        local expanded = fn.expand(dir)
        -- If relative, treat as subdir of home
        if not expanded:match("^/") then
            expanded = M.config.home .. "/" .. expanded
        end
        table.insert(M.config.scan_dirs, expanded)
    end

    return M.config
end

function M.get()
    return M.config or M.defaults
end

return M
