-- Read/write contact markdown files with YAML frontmatter
local M = {}

local utils = require("zet.utils")
local dates = require("zet.dates")

--- Convert a contact table to markdown lines with YAML frontmatter
function M.to_lines(contact)
    local lines = {}

    table.insert(lines, "---")
    table.insert(lines, "title: " .. (contact.fn or ""))
    table.insert(lines, "date: " .. dates.today())
    table.insert(lines, "type: contact")

    -- emails
    if contact.emails and #contact.emails > 0 then
        table.insert(lines, "emails:")
        for _, email in ipairs(contact.emails) do
            table.insert(lines, "  - " .. email)
        end
    else
        table.insert(lines, "emails: []")
    end

    -- org
    if contact.org and contact.org ~= "" then
        table.insert(lines, "org: " .. contact.org)
    end

    -- phones
    if contact.phones and #contact.phones > 0 then
        table.insert(lines, "phones:")
        for _, phone in ipairs(contact.phones) do
            table.insert(lines, '  - "' .. phone .. '"')
        end
    else
        table.insert(lines, "phones: []")
    end

    -- urls
    if contact.urls and #contact.urls > 0 then
        table.insert(lines, "urls:")
        for _, url in ipairs(contact.urls) do
            table.insert(lines, "  - " .. url)
        end
    else
        table.insert(lines, "urls: []")
    end

    -- addresses
    if contact.addresses and #contact.addresses > 0 then
        table.insert(lines, "addresses:")
        for _, addr in ipairs(contact.addresses) do
            table.insert(lines, '  - "' .. addr .. '"')
        end
    else
        table.insert(lines, "addresses: []")
    end

    -- birthday
    if contact.birthday and contact.birthday ~= "" then
        table.insert(lines, "birthday: " .. contact.birthday)
    end

    table.insert(lines, "---")
    table.insert(lines, "")
    table.insert(lines, "#contact")

    -- Notes section
    if contact.notes and #contact.notes > 0 then
        table.insert(lines, "")
        table.insert(lines, "## Notes")
        table.insert(lines, "")
        for _, note in ipairs(contact.notes) do
            table.insert(lines, note)
        end
    end

    table.insert(lines, "")
    return lines
end

--- Generate a safe filename from a contact name
local function safe_filename(name)
    if not name or name == "" then
        return nil
    end
    local safe = name:gsub("[/\\:*?\"<>|]", ""):gsub("%s+", "_")
    return safe .. ".md"
end

--- Find an existing contact file by title in a directory
function M.find_by_title(title, dir)
    if not title or not dir then
        return nil
    end

    local filename = safe_filename(title)
    if not filename then
        return nil
    end

    local path = dir .. "/" .. filename
    if utils.file_exists(path) then
        return path
    end

    -- Try scanning directory for matching title in frontmatter
    if not utils.dir_exists(dir) then
        return nil
    end

    local files = vim.fn.globpath(dir, "*.md", false, true)
    for _, file in ipairs(files) do
        local lines = utils.read_lines(file)
        if lines then
            for _, line in ipairs(lines) do
                if line:match("^title:%s*(.+)$") then
                    local found_title = line:match("^title:%s*(.+)$")
                    if found_title == title then
                        return file
                    end
                    break
                end
            end
        end
    end

    return nil
end

--- Union two lists, avoiding duplicates (case-insensitive for strings)
local function union_list(target, source)
    local seen = {}
    for _, v in ipairs(target) do
        seen[v:lower()] = true
    end
    for _, v in ipairs(source) do
        if not seen[v:lower()] then
            table.insert(target, v)
            seen[v:lower()] = true
        end
    end
    return target
end

--- Merge fields from source into target contact
function M.merge_contact_fields(target, source)
    -- Prefer non-empty scalars from source
    if (not target.fn or target.fn == "") and source.fn and source.fn ~= "" then
        target.fn = source.fn
    end
    if (not target.org or target.org == "") and source.org and source.org ~= "" then
        target.org = source.org
    end
    if (not target.birthday or target.birthday == "") and source.birthday and source.birthday ~= "" then
        target.birthday = source.birthday
    end
    if (not target.n_first or target.n_first == "") and source.n_first and source.n_first ~= "" then
        target.n_first = source.n_first
    end
    if (not target.n_last or target.n_last == "") and source.n_last and source.n_last ~= "" then
        target.n_last = source.n_last
    end
    if (not target.n_middle or target.n_middle == "") and source.n_middle and source.n_middle ~= "" then
        target.n_middle = source.n_middle
    end

    -- Union list fields
    target.emails = union_list(target.emails or {}, source.emails or {})
    target.phones = union_list(target.phones or {}, source.phones or {})
    target.urls = union_list(target.urls or {}, source.urls or {})
    target.addresses = union_list(target.addresses or {}, source.addresses or {})
    target.notes = union_list(target.notes or {}, source.notes or {})

    return target
end

--- Write a contact to a markdown file. Merges if title already exists.
--- Returns filepath, was_update
function M.write_contact(contact, dir)
    if not contact.fn or contact.fn == "" then
        return nil, false
    end

    utils.ensure_dir(dir)

    local filename = safe_filename(contact.fn)
    if not filename then
        return nil, false
    end

    local filepath = dir .. "/" .. filename

    -- Check if file already exists
    local existing = M.find_by_title(contact.fn, dir)
    if existing then
        -- Merge with existing contact
        local existing_contact = M.read_contact(existing)
        if existing_contact then
            M.merge_contact_fields(existing_contact, contact)
            local lines = M.to_lines(existing_contact)
            utils.write_lines(existing, lines)
            return existing, true
        end
    end

    local lines = M.to_lines(contact)
    utils.write_lines(filepath, lines)
    return filepath, false
end

--- Parse a YAML list from frontmatter lines starting at index
local function parse_yaml_list(lines, start_idx)
    local result = {}
    local i = start_idx
    while i <= #lines do
        local line = lines[i]
        local item = line:match("^%s+%-%s+(.+)$")
        if item then
            -- Strip surrounding quotes
            item = item:match('^"(.*)"$') or item:match("^'(.*)'$") or item
            table.insert(result, item)
            i = i + 1
        else
            break
        end
    end
    return result, i
end

--- Read a contact markdown file back to a contact table
function M.read_contact(filepath)
    local lines = utils.read_lines(filepath)
    if not lines then
        return nil
    end

    local contact = {
        fn = nil,
        n_last = nil,
        n_first = nil,
        n_middle = nil,
        emails = {},
        phones = {},
        org = nil,
        urls = {},
        addresses = {},
        notes = {},
        birthday = nil,
    }

    -- Parse frontmatter
    local in_frontmatter = false
    local frontmatter_end = 0
    local i = 1

    while i <= #lines do
        local line = lines[i]

        if i == 1 and line == "---" then
            in_frontmatter = true
            i = i + 1
            goto continue
        end

        if in_frontmatter and line == "---" then
            frontmatter_end = i
            break
        end

        if in_frontmatter then
            -- Parse key: value pairs
            local key, value = line:match("^(%w+):%s*(.*)$")
            if key then
                if key == "title" then
                    contact.fn = value
                elseif key == "org" then
                    contact.org = value
                elseif key == "birthday" then
                    contact.birthday = value
                elseif key == "emails" then
                    if value == "[]" then
                        contact.emails = {}
                    else
                        contact.emails, i = parse_yaml_list(lines, i + 1)
                        goto continue
                    end
                elseif key == "phones" then
                    if value == "[]" then
                        contact.phones = {}
                    else
                        contact.phones, i = parse_yaml_list(lines, i + 1)
                        goto continue
                    end
                elseif key == "urls" then
                    if value == "[]" then
                        contact.urls = {}
                    else
                        contact.urls, i = parse_yaml_list(lines, i + 1)
                        goto continue
                    end
                elseif key == "addresses" then
                    if value == "[]" then
                        contact.addresses = {}
                    else
                        contact.addresses, i = parse_yaml_list(lines, i + 1)
                        goto continue
                    end
                end
            end
        end

        i = i + 1
        ::continue::
    end

    -- Parse body for notes (after "## Notes" heading)
    local in_notes = false
    for idx = frontmatter_end + 1, #lines do
        local line = lines[idx]
        if line:match("^## Notes") then
            in_notes = true
        elseif in_notes then
            local trimmed = line:match("^%s*(.-)%s*$")
            if trimmed ~= "" then
                table.insert(contact.notes, trimmed)
            end
        end
    end

    -- Derive n_first/n_last from fn if not set
    if contact.fn and (not contact.n_first or contact.n_first == "") then
        local parts = {}
        for word in contact.fn:gmatch("%S+") do
            table.insert(parts, word)
        end
        if #parts >= 2 then
            contact.n_first = parts[1]
            contact.n_last = parts[#parts]
            if #parts >= 3 then
                contact.n_middle = table.concat({ unpack(parts, 2, #parts - 1) }, " ")
            end
        elseif #parts == 1 then
            contact.n_last = parts[1]
        end
    end

    return contact
end

--- Read all contacts from a directory
function M.read_all(dir)
    if not utils.dir_exists(dir) then
        return {}
    end

    local files = vim.fn.globpath(dir, "*.md", false, true)
    local contacts = {}

    for _, file in ipairs(files) do
        local contact = M.read_contact(file)
        if contact and contact.fn then
            contact._filepath = file
            table.insert(contacts, contact)
        end
    end

    return contacts
end

return M
