-- zettlekast.nvim — A focused Zettelkasten + reminders plugin for Neovim
local M = {}

--- Setup the plugin with user configuration
function M.setup(user_config)
    -- Initialize config
    local cfg = require("zettlekast.config").setup(user_config)

    -- Setup calendar integration
    require("zettlekast.calendar").setup()

    -- Setup reminder subsystem
    require("zettlekast.reminders").setup()

    -- Setup default keymaps
    if cfg.default_keymaps then
        local map = vim.keymap.set
        map("n", "<leader>z", "<cmd>Zettlekast panel<CR>", { desc = "Zettlekast panel" })
        map("n", "<leader>zf", "<cmd>Zettlekast find_notes<CR>", { desc = "Find notes" })
        map("n", "<leader>zd", "<cmd>Zettlekast goto_today<CR>", { desc = "Today's note" })
        map("n", "<leader>zn", "<cmd>Zettlekast new_note<CR>", { desc = "New note" })
        map("n", "<leader>zs", "<cmd>Zettlekast search_notes<CR>", { desc = "Search notes" })
        map("n", "<leader>zc", "<cmd>Zettlekast show_calendar<CR>", { desc = "Calendar" })
        map("n", "<leader>zr", "<cmd>Zettlekast reminder_scan<CR>", { desc = "Due reminders" })
        map("n", "<leader>zre", "<cmd>Zettlekast reminder_edit<CR>", { desc = "Snooze reminder" })
    end
end

-- Command list for tab completion and panel
local commands = {
    "panel",
    "find_notes",
    "find_daily_notes",
    "search_notes",
    "new_note",
    "new_templated_note",
    "rename_note",
    "follow_link",
    "insert_link",
    "goto_today",
    "show_tags",
    "show_calendar",
    "reminder_scan",
    "reminder_scan_upcoming",
    "reminder_scan_all",
    "reminder_edit",
}

function M.command_list()
    return commands
end

-- Public API: delegate to submodules

function M.panel()
    require("zettlekast.pickers").panel()
end

function M.find_notes()
    require("zettlekast.pickers").find_notes()
end

function M.find_daily_notes()
    require("zettlekast.pickers").find_daily_notes()
end

function M.search_notes()
    require("zettlekast.pickers").search_notes()
end

function M.new_note()
    require("zettlekast.notes").new_note()
end

function M.new_templated_note()
    require("zettlekast.notes").new_templated_note()
end

function M.rename_note()
    require("zettlekast.notes").rename_note()
end

function M.follow_link()
    require("zettlekast.links").follow_link()
end

function M.insert_link()
    require("zettlekast.links").insert_link()
end

function M.goto_today()
    require("zettlekast.notes").goto_today()
end

function M.show_tags()
    require("zettlekast.tags").show_tags()
end

function M.show_calendar()
    require("zettlekast.calendar").show_calendar()
end

function M.reminder_scan()
    require("zettlekast.reminders").scan(false)
end

function M.reminder_scan_upcoming()
    require("zettlekast.reminders").scan(true)
end

function M.reminder_scan_all()
    require("zettlekast.reminders").scan_all()
end

function M.reminder_edit()
    require("zettlekast.reminders").edit()
end

return M
