-- Virtual text display for reminder countdowns using extmarks
local M = {}

-- Namespace for the virtual text
local namespace_id = vim.api.nvim_create_namespace("zet_reminder_virtual_text")

-- Function to set virtual text for a reminder line using extmarks
function M.set_virtual_text(bufnr, line_nr, text)
    vim.api.nvim_buf_set_extmark(bufnr, namespace_id, line_nr, 0, {
        virt_text = { { text, "Comment" } },
        virt_text_pos = "eol",
    })
end

-- Function to update virtual text for all reminders in the buffer
function M.update_virtual_text()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    -- Clear all virtual texts in the namespace before updating
    vim.api.nvim_buf_clear_namespace(bufnr, namespace_id, 0, -1)

    local time_parser = require("zet.reminders.time_parser")

    for i, line in ipairs(lines) do
        local datetime = line:match("#reminder (%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ)")
        if datetime then
            local countdown = time_parser.time_until(datetime)
            M.set_virtual_text(bufnr, i - 1, countdown)
        end
    end
end

return M
