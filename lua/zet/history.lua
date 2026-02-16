-- Line history: git-powered creation/modification tracking for note lines
local M = {}

--- Parse git log -L output into structured entries
--- Each entry has: hash, date, message, line_content
local function parse_log_output(output)
    local entries = {}
    local current = nil

    for _, raw_line in ipairs(output) do
        local line = raw_line:gsub("%s+$", "")

        -- Commit line: "commit <hash>"
        local hash = line:match("^commit (%x+)")
        if hash then
            if current then
                table.insert(entries, current)
            end
            current = { hash = hash:sub(1, 8), date = "", message = "", line_content = "" }
            goto continue
        end

        if not current then
            goto continue
        end

        -- Date line: "Date:   <date>"
        local date = line:match("^Date:%s+(.+)")
        if date then
            current.date = vim.trim(date)
            goto continue
        end

        -- Skip Author line
        if line:match("^Author:") then
            goto continue
        end

        -- Message lines (indented with 4 spaces)
        local msg = line:match("^    (.+)")
        if msg then
            if current.message == "" then
                current.message = msg
            else
                current.message = current.message .. " " .. msg
            end
            goto continue
        end

        -- Diff content: lines starting with + (added) that aren't diff headers
        if line:match("^%+") and not line:match("^%+%+%+") then
            current.line_content = line:sub(2)
        end

        ::continue::
    end

    if current then
        table.insert(entries, current)
    end

    return entries
end

--- Format entries into display lines for the floating window
local function format_display(entries, current_line_text)
    local lines = {}
    local highlights = {}

    if #entries == 0 then
        return { " No git history for this line (uncommitted or new file)" }, {}
    end

    -- Entries come newest-first from git log; oldest = created
    local created = entries[#entries]
    local latest = entries[1]

    table.insert(lines, " Line History")
    table.insert(highlights, { line = #lines - 1, hl = "Title" })
    table.insert(lines, string.rep("─", 50))
    table.insert(highlights, { line = #lines - 1, hl = "FloatBorder" })

    -- Current content
    local display_text = vim.trim(current_line_text)
    if #display_text > 60 then
        display_text = display_text:sub(1, 57) .. "..."
    end
    table.insert(lines, " " .. display_text)
    table.insert(highlights, { line = #lines - 1, hl = "String" })
    table.insert(lines, "")

    -- Created info
    table.insert(lines, " Created:  " .. created.date)
    table.insert(highlights, { line = #lines - 1, hl = "DiagnosticInfo" })
    if created.message ~= "" then
        table.insert(lines, "           " .. created.message)
        table.insert(highlights, { line = #lines - 1, hl = "Comment" })
    end

    -- Last modified (if different from created)
    if #entries > 1 then
        table.insert(lines, "")
        table.insert(lines, " Modified: " .. latest.date)
        table.insert(highlights, { line = #lines - 1, hl = "DiagnosticWarn" })
        if latest.message ~= "" then
            table.insert(lines, "           " .. latest.message)
            table.insert(highlights, { line = #lines - 1, hl = "Comment" })
        end

        -- Edit count
        table.insert(lines, "")
        local edits = #entries - 1
        local word = edits == 1 and "edit" or "edits"
        table.insert(lines, " " .. edits .. " " .. word .. " total")
        table.insert(highlights, { line = #lines - 1, hl = "DiagnosticHint" })
    end

    -- Full history if more than 2 entries
    if #entries > 2 then
        table.insert(lines, "")
        table.insert(lines, " History")
        table.insert(highlights, { line = #lines - 1, hl = "Title" })
        table.insert(lines, string.rep("─", 50))
        table.insert(highlights, { line = #lines - 1, hl = "FloatBorder" })

        for i, entry in ipairs(entries) do
            local prefix = i == #entries and " ● " or " │ "
            local msg = entry.message ~= "" and ("  " .. entry.message) or ""
            table.insert(lines, prefix .. entry.date .. msg)
            local hl = i == #entries and "DiagnosticInfo" or "Normal"
            table.insert(highlights, { line = #lines - 1, hl = hl })
        end
    end

    return lines, highlights
end

--- Show line history in a floating window
function M.line_history()
    local bufnr = vim.api.nvim_get_current_buf()
    local filepath = vim.api.nvim_buf_get_name(bufnr)

    if filepath == "" then
        vim.notify("Zet: buffer has no file", vim.log.levels.WARN)
        return
    end

    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local current_line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""

    -- Get the git repo root for this file
    local dir = vim.fn.fnamemodify(filepath, ":h")

    vim.fn.jobstart({
        "git", "-C", dir, "log",
        "--format=commit %H%nAuthor: %an%nDate:   %ai%n%n    %s",
        "-L", lnum .. "," .. lnum .. ":" .. filepath,
    }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            vim.schedule(function()
                -- Filter empty lines from end
                while data[#data] == "" do
                    table.remove(data)
                end

                local entries = parse_log_output(data)
                local lines, highlights = format_display(entries, current_line)

                -- Calculate window size
                local width = 2
                for _, line in ipairs(lines) do
                    width = math.max(width, vim.fn.strdisplaywidth(line) + 2)
                end
                width = math.min(width, 72)
                local height = math.min(#lines, 20)

                -- Create scratch buffer
                local float_buf = vim.api.nvim_create_buf(false, true)
                vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, lines)
                vim.bo[float_buf].modifiable = false
                vim.bo[float_buf].bufhidden = "wipe"

                -- Apply highlights
                local ns = vim.api.nvim_create_namespace("zet_history")
                for _, hl in ipairs(highlights) do
                    vim.api.nvim_buf_add_highlight(float_buf, ns, hl.hl, hl.line, 0, -1)
                end

                -- Open floating window
                local win = vim.api.nvim_open_win(float_buf, true, {
                    relative = "cursor",
                    row = 1,
                    col = 0,
                    width = width,
                    height = height,
                    style = "minimal",
                    border = "rounded",
                    title = " Line History ",
                    title_pos = "center",
                })

                -- Close on any key press
                vim.keymap.set("n", "q", function()
                    if vim.api.nvim_win_is_valid(win) then
                        vim.api.nvim_win_close(win, true)
                    end
                end, { buffer = float_buf, nowait = true })

                vim.keymap.set("n", "<Esc>", function()
                    if vim.api.nvim_win_is_valid(win) then
                        vim.api.nvim_win_close(win, true)
                    end
                end, { buffer = float_buf, nowait = true })
            end)
        end,
        on_stderr = function(_, data)
            vim.schedule(function()
                local err = table.concat(data, "\n")
                if err and err ~= "" then
                    vim.notify("Zet: " .. vim.trim(err), vim.log.levels.WARN)
                end
            end)
        end,
    })
end

return M
