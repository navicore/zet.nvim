-- Autocommands for reminder processing: auto-convert natural language, update virtual text
local M = {}

local time_parser = require("zet.reminders.time_parser")
local virtual_text = require("zet.reminders.virtual_text")

-- Function to convert natural language time to ISO 8601
local function convert_to_iso8601(text)
    local iso_time = time_parser.parse(text)
    if iso_time then
        return iso_time
    else
        return nil
    end
end

-- Function to process the reminder line, rewrite time to ISO 8601, and ensure markdown prefix
local function process_reminder_line(line)
    -- Check if the line already contains a prefixed #reminder
    if line:match("%* %[%s?[ xX]?%s?%] #reminder") then
        -- Rewrite time for an existing prefixed #reminder
        return line:gsub("(#reminder) (.+):(%s)", function(reminder_prefix, time_expr, _)
            local iso_time = convert_to_iso8601(time_expr)
            local time_part = iso_time and iso_time or time_expr
            return reminder_prefix .. " " .. time_part .. ": "
        end)
    else
        -- Insert the prefix before the first occurrence of #reminder
        return line:gsub("(#reminder) (.+):(%s)", function(reminder_prefix, time_expr, _)
            local iso_time = convert_to_iso8601(time_expr)
            local time_part = iso_time and iso_time or time_expr
            return "* [ ] " .. reminder_prefix .. " " .. time_part .. ": "
        end)
    end
end

-- Function to process the current file
function M.process_file()
    local cfg = require("zet.config").get()
    local current_file = vim.fn.expand("%:p")

    for _, dir in ipairs(cfg.scan_dirs or { cfg.home }) do
        local abs_dir = vim.fn.fnamemodify(dir, ":p")
        if current_file:sub(1, #abs_dir) == abs_dir then
            local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            for i, line in ipairs(lines) do
                lines[i] = process_reminder_line(line)
            end
            vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
            break
        end
    end
end

-- Function to set up virtual text for the entire buffer
function M.update_virtual_text()
    local cfg = require("zet.config").get()
    if not cfg.reminders or not cfg.reminders.show_virtual_text then
        return
    end
    virtual_text.update_virtual_text()
end

-- Set up autocmds scoped to zet filetype
function M.setup_autocmds()
    local cfg = require("zet.config").get()
    if not cfg.reminders or not cfg.reminders.enabled then
        return
    end

    local group = vim.api.nvim_create_augroup("ZetReminders", { clear = true })

    if cfg.reminders.scan_on_save then
        vim.api.nvim_create_autocmd("BufWritePre", {
            group = group,
            pattern = "*.md",
            callback = function()
                M.process_file()
            end,
        })
    end

    if cfg.reminders.show_virtual_text then
        vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
            group = group,
            pattern = "*.md",
            callback = function()
                M.update_virtual_text()
            end,
        })
    end
end

return M
