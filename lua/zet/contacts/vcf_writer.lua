-- Export contacts to VCF 3.0 format
local M = {}

local utils = require("zet.utils")

--- Escape a value for VCF output (reverse of unescape)
function M.escape_value(s)
    if not s then
        return ""
    end
    s = s:gsub("\\", "\\\\")
    s = s:gsub(";", "\\;")
    s = s:gsub(",", "\\,")
    s = s:gsub("\n", "\\n")
    return s
end

--- Fold a line per RFC 2425 (max 75 octets)
function M.fold_line(line)
    if #line <= 75 then
        return line
    end

    local result = {}
    local pos = 1
    local first = true

    while pos <= #line do
        local chunk_len = first and 75 or 74 -- continuation lines get space prefix
        local chunk = line:sub(pos, pos + chunk_len - 1)
        if first then
            table.insert(result, chunk)
            first = false
        else
            table.insert(result, " " .. chunk)
        end
        pos = pos + chunk_len
    end

    return table.concat(result, "\r\n")
end

--- Convert a contact table to VCF 3.0 lines
function M.to_vcard(contact)
    local lines = {}

    table.insert(lines, "BEGIN:VCARD")
    table.insert(lines, "VERSION:3.0")

    -- FN (required)
    local fn = contact.fn or ""
    table.insert(lines, M.fold_line("FN:" .. M.escape_value(fn)))

    -- N — derive from fn if not set
    local last = contact.n_last or ""
    local first = contact.n_first or ""
    local middle = contact.n_middle or ""

    if last == "" and first == "" and fn ~= "" then
        local parts = {}
        for word in fn:gmatch("%S+") do
            table.insert(parts, word)
        end
        if #parts >= 2 then
            first = parts[1]
            last = parts[#parts]
            if #parts >= 3 then
                middle = table.concat({ unpack(parts, 2, #parts - 1) }, " ")
            end
        elseif #parts == 1 then
            last = parts[1]
        end
    end

    table.insert(lines, M.fold_line("N:" .. M.escape_value(last) .. ";" .. M.escape_value(first) .. ";" .. M.escape_value(middle) .. ";;"))

    -- ORG
    if contact.org and contact.org ~= "" then
        table.insert(lines, M.fold_line("ORG:" .. M.escape_value(contact.org)))
    end

    -- EMAIL
    for _, email in ipairs(contact.emails or {}) do
        table.insert(lines, M.fold_line("EMAIL:" .. email))
    end

    -- TEL
    for _, phone in ipairs(contact.phones or {}) do
        table.insert(lines, M.fold_line("TEL:" .. phone))
    end

    -- URL
    for _, url in ipairs(contact.urls or {}) do
        table.insert(lines, M.fold_line("URL:" .. url))
    end

    -- ADR
    for _, addr in ipairs(contact.addresses or {}) do
        -- Store as a single street component since we lost structure
        table.insert(lines, M.fold_line("ADR:;;" .. M.escape_value(addr) .. ";;;;"))
    end

    -- BDAY
    if contact.birthday and contact.birthday ~= "" then
        table.insert(lines, "BDAY:" .. contact.birthday)
    end

    -- NOTE
    for _, note in ipairs(contact.notes or {}) do
        table.insert(lines, M.fold_line("NOTE:" .. M.escape_value(note)))
    end

    table.insert(lines, "END:VCARD")

    return lines
end

--- Write all contacts to a single VCF file
function M.write_file(contacts, filepath)
    local all_lines = {}

    for _, contact in ipairs(contacts) do
        local vcard_lines = M.to_vcard(contact)
        for _, line in ipairs(vcard_lines) do
            table.insert(all_lines, line)
        end
    end

    utils.ensure_dir(utils.dirname(filepath))
    utils.write_lines(filepath, all_lines)
end

return M
