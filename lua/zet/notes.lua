local M = {}

local config = require("zet.config")
local dates = require("zet.dates")
local templates = require("zet.templates")
local utils = require("zet.utils")

--- Generate a filename for a new note
function M.generate_filename(title, cfg)
    cfg = cfg or config.get()
    local uuid = dates.generate_uuid(cfg.uuid_type)

    if not title or title == "" then
        return uuid .. cfg.extension
    end

    -- Apply space substitution
    local safe_title = title
    if cfg.filename_space_subst then
        safe_title = title:gsub(" ", cfg.filename_space_subst)
    end

    local sep = cfg.uuid_sep or "-"
    if cfg.new_note_filename == "uuid-title" then
        return uuid .. sep .. safe_title .. cfg.extension
    elseif cfg.new_note_filename == "title-uuid" then
        return safe_title .. sep .. uuid .. cfg.extension
    elseif cfg.new_note_filename == "uuid" then
        return uuid .. cfg.extension
    else
        -- "title"
        return safe_title .. cfg.extension
    end
end

--- Create a new note with optional title, returns the filepath
function M.new_note(title, template_path, target_dir)
    local cfg = config.get()
    target_dir = target_dir or cfg.home

    -- Prompt for title if not provided
    if not title then
        title = vim.fn.input("Note title: ")
        if title == "" then
            title = nil
        end
    end

    local filename = M.generate_filename(title, cfg)
    local filepath = target_dir .. "/" .. filename

    -- Check if file already exists
    if utils.file_exists(filepath) then
        vim.cmd("edit " .. vim.fn.fnameescape(filepath))
        return filepath
    end

    utils.ensure_dir(target_dir)

    -- Apply template
    template_path = template_path or cfg.template_new_note
    local vars = dates.template_vars()
    vars.title = title or ""
    vars.uuid = dates.generate_uuid(cfg.uuid_type)

    local lines = templates.apply(template_path, vars)
    if lines then
        utils.write_lines(filepath, lines)
    else
        -- Create with minimal frontmatter
        utils.write_lines(filepath, {
            "---",
            "title: " .. (title or ""),
            "date: " .. vars.date,
            "---",
            "",
        })
    end

    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
    return filepath
end

--- Create a new note from a template picked via Telescope
function M.new_templated_note()
    local cfg = config.get()
    local template_list = templates.list(cfg.templates)

    if #template_list == 0 then
        vim.notify("No templates found in " .. cfg.templates, vim.log.levels.WARN)
        M.new_note()
        return
    end

    local has_telescope, _ = pcall(require, "telescope")
    if not has_telescope then
        vim.notify("Telescope is required for template selection", vim.log.levels.ERROR)
        return
    end

    local pickers_mod = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers_mod.new({}, {
        prompt_title = "Select Template",
        finder = finders.new_table({
            results = template_list,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.name,
                    ordinal = entry.name,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if selection then
                    M.new_note(nil, selection.value.path)
                end
            end)
            return true
        end,
    }):find()
end

--- Open or create today's daily note
function M.goto_today()
    local cfg = config.get()
    local filename = dates.daily_filename()
    local filepath = cfg.home .. "/" .. filename

    if utils.file_exists(filepath) then
        vim.cmd("edit " .. vim.fn.fnameescape(filepath))
        return filepath
    end

    if not cfg.dailies_create_nonexisting then
        vim.notify("Today's note does not exist: " .. filename, vim.log.levels.INFO)
        return nil
    end

    -- Create from daily template
    local template_path = cfg.template_new_daily
    local vars = dates.template_vars()
    vars.title = dates.today()
    vars.uuid = dates.generate_uuid(cfg.uuid_type)

    local lines = templates.apply(template_path, vars)
    if lines then
        utils.write_lines(filepath, lines)
    else
        utils.write_lines(filepath, {
            "---",
            "title: " .. vars.title,
            "date: " .. vars.date,
            "---",
            "",
        })
    end

    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
    return filepath
end

--- Rename the current note and optionally update backlinks
function M.rename_note()
    local cfg = config.get()
    local current_file = vim.fn.expand("%:p")
    local current_name = utils.stem(current_file)
    local current_dir = utils.dirname(current_file)

    local new_title = vim.fn.input("New title: ", utils.title_from_filename(utils.basename(current_file)))
    if new_title == "" then
        return
    end

    local new_filename = M.generate_filename(new_title, cfg)
    local new_filepath = current_dir .. "/" .. new_filename
    local new_stem = utils.stem(new_filepath)

    if utils.file_exists(new_filepath) then
        vim.notify("File already exists: " .. new_filepath, vim.log.levels.ERROR)
        return
    end

    -- Rename the file
    vim.cmd("saveas " .. vim.fn.fnameescape(new_filepath))
    vim.fn.delete(current_file)

    -- Update backlinks if configured
    if cfg.rename_update_links then
        M.update_backlinks(cfg.scan_dirs, current_name, new_stem)
    end

    vim.notify("Renamed to " .. new_filename)
end

--- Update all [[old_name]] links to [[new_name]] across scan dirs
function M.update_backlinks(dirs, old_name, new_name)
    local files = utils.collect_md_files(dirs)
    local old_pattern = "%[%[" .. utils.escape_pattern(old_name) .. "([^%]]*)%]%]"
    local new_replacement = "[[" .. new_name .. "%1]]"
    local updated_count = 0

    for _, file in ipairs(files) do
        local lines = utils.read_lines(file)
        if lines then
            local modified = false
            for i, line in ipairs(lines) do
                local new_line = line:gsub(old_pattern, new_replacement)
                if new_line ~= line then
                    lines[i] = new_line
                    modified = true
                end
            end
            if modified then
                utils.write_lines(file, lines)
                updated_count = updated_count + 1
            end
        end
    end

    if updated_count > 0 then
        vim.notify("Updated backlinks in " .. updated_count .. " file(s)")
    end
end

return M
