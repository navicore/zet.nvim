-- VCF 3.0 parser for contact import
local M = {}

--- Join continuation lines per RFC 2425 (lines starting with space/tab)
function M.unfold(raw_lines)
    local result = {}
    for _, line in ipairs(raw_lines) do
        if line:match("^[ \t]") and #result > 0 then
            result[#result] = result[#result] .. line:sub(2)
        else
            table.insert(result, line)
        end
    end
    return result
end

--- Parse a property line into {name, params, value}
--- e.g. "TEL;type=WORK:555-1234" -> {name="TEL", params={type="WORK"}, value="555-1234"}
function M.parse_property(line)
    if not line or line == "" then
        return nil
    end

    -- Split name+params from value at first unescaped colon
    -- Handle QUOTED-PRINTABLE values with colons inside
    local head, value
    local colon_pos = nil
    local i = 1
    while i <= #line do
        local c = line:sub(i, i)
        if c == "\\" then
            i = i + 2 -- skip escaped char
        elseif c == ":" then
            colon_pos = i
            break
        else
            i = i + 1
        end
    end

    if not colon_pos then
        return nil
    end

    head = line:sub(1, colon_pos - 1)
    value = line:sub(colon_pos + 1)

    -- Split head into name and params at semicolons
    local parts = {}
    for part in head:gmatch("[^;]+") do
        table.insert(parts, part)
    end

    local name = (parts[1] or ""):upper()
    local params = {}

    for idx = 2, #parts do
        local param = parts[idx]
        local k, v = param:match("^(.-)=(.+)$")
        if k then
            params[k:lower()] = v
        else
            -- Bare parameter (e.g. "WORK" instead of "type=WORK")
            params[param:lower()] = true
        end
    end

    return { name = name, params = params, value = value }
end

--- Unescape VCF property values
function M.unescape_value(s)
    if not s then
        return ""
    end
    s = s:gsub("\\n", "\n")
    s = s:gsub("\\N", "\n")
    s = s:gsub("\\,", ",")
    s = s:gsub("\\;", ";")
    s = s:gsub("\\\\", "\\")
    return s
end

--- Parse a single vCard block (lines between BEGIN:VCARD and END:VCARD)
function M.parse_vcard(lines)
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

    for _, line in ipairs(lines) do
        local prop = M.parse_property(line)
        if not prop then
            goto continue
        end

        local name = prop.name
        local val = M.unescape_value(prop.value)

        if name == "FN" then
            contact.fn = val
        elseif name == "N" then
            -- N:Last;First;Middle;Prefix;Suffix
            local parts = {}
            for part in (val .. ";"):gmatch("([^;]*);") do
                table.insert(parts, part)
            end
            contact.n_last = parts[1] or ""
            contact.n_first = parts[2] or ""
            contact.n_middle = parts[3] or ""
        elseif name == "EMAIL" then
            if val ~= "" then
                table.insert(contact.emails, val)
            end
        elseif name == "TEL" then
            if val ~= "" then
                table.insert(contact.phones, val)
            end
        elseif name == "ORG" then
            -- ORG can have multiple components separated by ;
            contact.org = val:gsub(";+$", ""):gsub(";", ", ")
        elseif name == "URL" then
            if val ~= "" then
                table.insert(contact.urls, val)
            end
        elseif name == "ADR" then
            -- ADR:;;Street;City;State;Zip;Country
            local parts = {}
            for part in (val .. ";"):gmatch("([^;]*);") do
                table.insert(parts, part)
            end
            local addr_parts = {}
            for _, p in ipairs(parts) do
                if p ~= "" then
                    table.insert(addr_parts, p)
                end
            end
            if #addr_parts > 0 then
                table.insert(contact.addresses, table.concat(addr_parts, ", "))
            end
        elseif name == "NOTE" then
            if val ~= "" then
                table.insert(contact.notes, val)
            end
        elseif name == "BDAY" then
            contact.birthday = val
        end

        ::continue::
    end

    return contact
end

--- Parse an entire VCF file into a list of contact tables
function M.parse_file(filepath)
    local fn = vim.fn
    if fn.filereadable(filepath) ~= 1 then
        return nil, "File not readable: " .. filepath
    end

    local raw_lines = fn.readfile(filepath)
    local unfolded = M.unfold(raw_lines)

    local contacts = {}
    local current_lines = {}
    local in_vcard = false

    for _, line in ipairs(unfolded) do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed:upper() == "BEGIN:VCARD" then
            in_vcard = true
            current_lines = {}
        elseif trimmed:upper() == "END:VCARD" then
            if in_vcard then
                local contact = M.parse_vcard(current_lines)
                table.insert(contacts, contact)
            end
            in_vcard = false
            current_lines = {}
        elseif in_vcard then
            table.insert(current_lines, line)
        end
    end

    return contacts
end

return M
