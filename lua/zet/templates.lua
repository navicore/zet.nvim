local M = {}

local utils = require("zet.utils")

--- Load a template file and return its content as a string
function M.load(template_path)
    if not template_path or not utils.file_exists(template_path) then
        return nil
    end
    local lines = utils.read_lines(template_path)
    if lines then
        return table.concat(lines, "\n")
    end
    return nil
end

--- Substitute {{variable}} placeholders in a template string
function M.substitute(template_str, vars)
    if not template_str then
        return nil
    end
    return template_str:gsub("{{(%w+)}}", function(key)
        return vars[key] or ("{{" .. key .. "}}")
    end)
end

--- Load a template and substitute variables, return as lines
function M.apply(template_path, vars)
    local content = M.load(template_path)
    if not content then
        return nil
    end
    content = M.substitute(content, vars)
    local lines = {}
    for line in (content .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

--- List available templates in the templates directory
function M.list(templates_dir)
    if not templates_dir or not utils.dir_exists(templates_dir) then
        return {}
    end
    local files = vim.fn.globpath(templates_dir, "*.md", false, true)
    local templates = {}
    for _, f in ipairs(files) do
        table.insert(templates, {
            path = f,
            name = utils.stem(f),
        })
    end
    return templates
end

return M
