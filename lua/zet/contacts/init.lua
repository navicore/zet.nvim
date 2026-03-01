-- Contacts subsystem orchestration
local M = {}

local config = require("zet.config")

--- Get the contacts directory path
function M.contacts_dir()
    local cfg = config.get()
    local dir_name = cfg.contacts and cfg.contacts.dir or "contacts"
    return cfg.home .. "/" .. dir_name
end

--- Import contacts from a VCF file
function M.import(vcf_path)
    local cfg = config.get()

    -- Resolve path
    if not vcf_path or vcf_path == "" then
        vcf_path = cfg.contacts and cfg.contacts.default_import_path
            or "~/Desktop/All contacts.vcf"
    end
    vcf_path = vim.fn.expand(vcf_path)

    if vim.fn.filereadable(vcf_path) ~= 1 then
        vim.notify("VCF file not found: " .. vcf_path, vim.log.levels.ERROR)
        return
    end

    local parser = require("zet.contacts.vcf_parser")
    local dedup = require("zet.contacts.dedup")
    local markdown = require("zet.contacts.markdown")

    -- Parse
    vim.notify("Parsing VCF file...", vim.log.levels.INFO)
    local contacts, err = parser.parse_file(vcf_path)
    if not contacts then
        vim.notify("Parse error: " .. (err or "unknown"), vim.log.levels.ERROR)
        return
    end

    local total_parsed = #contacts

    -- Filter empty names
    local filtered = {}
    for _, contact in ipairs(contacts) do
        if contact.fn and contact.fn ~= "" then
            table.insert(filtered, contact)
        end
    end
    local after_filter = #filtered

    -- Merge exact duplicates
    local merged = dedup.merge_exact_fn(filtered)
    local after_merge = #merged

    -- Write to disk
    local dir = M.contacts_dir()
    local written = 0
    local updated = 0

    for _, contact in ipairs(merged) do
        local _, was_update = markdown.write_contact(contact, dir)
        if was_update then
            updated = updated + 1
        else
            written = written + 1
        end
    end

    vim.notify(
        string.format(
            "Import complete: %d parsed, %d filtered (no name), %d merged → %d written, %d updated",
            total_parsed,
            total_parsed - after_filter,
            after_filter - after_merge,
            written,
            updated
        ),
        vim.log.levels.INFO
    )
end

--- Launch Telescope contact picker
function M.find()
    require("zet.contacts.telescope").contacts_picker()
end

--- Launch interactive dedup workflow
function M.dedup_interactive()
    require("zet.contacts.dedup").interactive()
end

--- Export all contacts to a VCF file
function M.export(output_path)
    local cfg = config.get()

    if not output_path or output_path == "" then
        output_path = cfg.contacts and cfg.contacts.default_export_path
            or "~/Desktop/contacts-export.vcf"
    end
    output_path = vim.fn.expand(output_path)

    local markdown = require("zet.contacts.markdown")
    local writer = require("zet.contacts.vcf_writer")

    local dir = M.contacts_dir()
    local contacts = markdown.read_all(dir)

    if #contacts == 0 then
        vim.notify("No contacts found in " .. dir, vim.log.levels.WARN)
        return
    end

    writer.write_file(contacts, output_path)
    vim.notify(
        string.format("Exported %d contacts to %s", #contacts, output_path),
        vim.log.levels.INFO
    )
end

return M
