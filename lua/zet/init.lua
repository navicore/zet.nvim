-- zet.nvim — A focused Zettelkasten + reminders plugin for Neovim
local M = {}

--- Setup the plugin with user configuration
function M.setup(user_config)
    -- Initialize config
    local cfg = require("zet.config").setup(user_config)

    -- Setup calendar integration
    require("zet.calendar").setup()

    -- Setup reminder subsystem
    require("zet.reminders").setup()

    -- Setup default keymaps
    if cfg.default_keymaps then
        local map = vim.keymap.set
        map("n", "<leader>z", "<cmd>Zet panel<CR>", { desc = "Zet panel" })
        map("n", "<leader>zf", "<cmd>Zet find_notes<CR>", { desc = "Find notes" })
        map("n", "<leader>zd", "<cmd>Zet goto_today<CR>", { desc = "Today's note" })
        map("n", "<leader>zn", "<cmd>Zet new_note<CR>", { desc = "New note" })
        map("n", "<leader>zs", "<cmd>Zet search_notes<CR>", { desc = "Search notes" })
        map("n", "<leader>zc", "<cmd>Zet show_calendar<CR>", { desc = "Calendar" })
        map("n", "<leader>zr", "<cmd>Zet reminder_scan<CR>", { desc = "Due reminders" })
        map("n", "<leader>zre", "<cmd>Zet reminder_edit<CR>", { desc = "Snooze reminder" })
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
    "reminder_recent_done",
    "line_history",
}

function M.command_list()
    return commands
end

-- Public API: delegate to submodules

function M.panel()
    require("zet.pickers").panel()
end

function M.find_notes()
    require("zet.pickers").find_notes()
end

function M.find_daily_notes()
    require("zet.pickers").find_daily_notes()
end

function M.search_notes()
    require("zet.pickers").search_notes()
end

function M.new_note()
    require("zet.notes").new_note()
end

function M.new_templated_note()
    require("zet.notes").new_templated_note()
end

function M.rename_note()
    require("zet.notes").rename_note()
end

function M.follow_link()
    require("zet.links").follow_link()
end

function M.insert_link()
    require("zet.links").insert_link()
end

function M.goto_today()
    require("zet.notes").goto_today()
end

function M.show_tags()
    require("zet.tags").show_tags()
end

function M.show_calendar()
    require("zet.calendar").show_calendar()
end

function M.reminder_scan()
    require("zet.reminders").scan(false)
end

function M.reminder_scan_upcoming()
    require("zet.reminders").scan(true)
end

function M.reminder_scan_all()
    require("zet.reminders").scan_all()
end

function M.reminder_edit()
    require("zet.reminders").edit()
end

function M.reminder_recent_done()
    require("zet.reminders").scan_recent_done()
end

function M.line_history()
    require("zet.history").line_history()
end

return M
