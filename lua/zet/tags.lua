local M = {}

local config = require("zet.config")
local utils = require("zet.utils")

--- Scan all notes for #tags and return a sorted unique list
function M.collect_tags()
    local cfg = config.get()
    local files = utils.collect_md_files(cfg.scan_dirs)
    local tag_set = {}

    for _, file in ipairs(files) do
        local lines = utils.read_lines(file)
        if lines then
            for _, line in ipairs(lines) do
                -- Match #tag notation (not inside code blocks)
                for tag in line:gmatch("#([%w][%w%d/_-]*)") do
                    -- Skip pure numbers (like #1, #2)
                    if not tag:match("^%d+$") then
                        tag_set["#" .. tag] = (tag_set["#" .. tag] or 0) + 1
                    end
                end
            end
        end
    end

    -- Convert to sorted list
    local tags = {}
    for tag, count in pairs(tag_set) do
        table.insert(tags, { tag = tag, count = count })
    end
    table.sort(tags, function(a, b)
        return a.count > b.count
    end)

    return tags
end

--- Show tags in a Telescope picker
function M.show_tags()
    local has_telescope, _ = pcall(require, "telescope")
    if not has_telescope then
        vim.notify("Telescope is required", vim.log.levels.ERROR)
        return
    end

    local pickers_mod = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    local tags = M.collect_tags()

    if #tags == 0 then
        vim.notify("No tags found", vim.log.levels.INFO)
        return
    end

    pickers_mod.new({}, {
        prompt_title = "Tags",
        finder = finders.new_table({
            results = tags,
            entry_maker = function(entry)
                local display = string.format("%-30s (%d)", entry.tag, entry.count)
                return {
                    value = entry,
                    display = display,
                    ordinal = entry.tag,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if selection then
                    -- Search for the selected tag across notes
                    local cfg = config.get()
                    require("telescope.builtin").grep_string({
                        prompt_title = "Notes with " .. selection.value.tag,
                        search = selection.value.tag,
                        search_dirs = cfg.scan_dirs,
                        glob_pattern = "*.md",
                    })
                end
            end)
            return true
        end,
    }):find()
end

return M
