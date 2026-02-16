local M = {}

local fn = vim.fn

function M.file_exists(path)
    return fn.filereadable(path) == 1
end

function M.dir_exists(path)
    return fn.isdirectory(path) == 1
end

function M.ensure_dir(path)
    if not M.dir_exists(path) then
        fn.mkdir(path, "p")
    end
end

function M.expand_path(path)
    return fn.expand(path)
end

--- Escape a string for use in a Lua pattern
function M.escape_pattern(str)
    return str:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

--- Get the title from a filename (strip extension and uuid prefix)
function M.title_from_filename(filename)
    -- Strip extension
    local name = filename:gsub("%.md$", "")
    -- Strip uuid prefix (pattern: YYYY-MM-DD-HHMM-)
    local title = name:match("^%d%d%d%d%-%d%d%-%d%d%-%d%d%d%d%-(.+)$")
    if title then
        return title:gsub("_", " ")
    end
    return name:gsub("_", " ")
end

--- Get the filename (without path) from a full path
function M.basename(path)
    return fn.fnamemodify(path, ":t")
end

--- Get the filename without extension
function M.stem(path)
    return fn.fnamemodify(path, ":t:r")
end

--- Get the directory part of a path
function M.dirname(path)
    return fn.fnamemodify(path, ":h")
end

--- Check if a path is inside a directory
function M.path_in_dir(path, dir)
    local abs_path = fn.fnamemodify(path, ":p")
    local abs_dir = fn.fnamemodify(dir, ":p")
    return abs_path:sub(1, #abs_dir) == abs_dir
end

--- Read all lines of a file
function M.read_lines(path)
    if not M.file_exists(path) then
        return nil
    end
    return fn.readfile(path)
end

--- Write lines to a file
function M.write_lines(path, lines)
    fn.writefile(lines, path)
end

--- Collect all .md files from a list of directories (recursive)
function M.collect_md_files(dirs)
    local files = {}
    local seen = {}
    for _, dir in ipairs(dirs) do
        if M.dir_exists(dir) then
            local found = fn.globpath(dir, "**/*.md", false, true)
            for _, f in ipairs(found) do
                if not seen[f] then
                    seen[f] = true
                    table.insert(files, f)
                end
            end
        end
    end
    return files
end

return M
