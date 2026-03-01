-- Contact deduplication logic
local M = {}

local markdown = require("zet.contacts.markdown")

--- Merge contacts with exact same FN (used during import)
--- Returns deduplicated list
function M.merge_exact_fn(contacts)
    local by_fn = {}
    local order = {}

    for _, contact in ipairs(contacts) do
        local fn = contact.fn
        if fn and fn ~= "" then
            if by_fn[fn] then
                markdown.merge_contact_fields(by_fn[fn], contact)
            else
                by_fn[fn] = contact
                table.insert(order, fn)
            end
        end
    end

    local result = {}
    for _, fn in ipairs(order) do
        table.insert(result, by_fn[fn])
    end
    return result
end

--- Normalize a contact name for fuzzy matching
function M.normalize_name(name)
    if not name then
        return ""
    end
    local n = name:lower()
    -- Strip "via LinkedIn" suffix
    n = n:gsub("%s*via%s+linkedin%s*$", "")
    -- Strip parenthetical content
    n = n:gsub("%s*%(.*%)%s*", "")
    -- Strip extra whitespace
    n = n:gsub("%s+", " ")
    n = n:match("^%s*(.-)%s*$") or n
    return n
end

--- Find duplicate clusters among contacts in a directory
--- Returns list of clusters: { { contacts = {c1, c2, ...}, reason = "..." }, ... }
function M.find_duplicates(dir)
    local contacts = markdown.read_all(dir)
    local clusters = {}
    local used = {}

    -- Index by normalized name
    local by_norm = {}
    for idx, contact in ipairs(contacts) do
        local norm = M.normalize_name(contact.fn)
        if norm ~= "" then
            if not by_norm[norm] then
                by_norm[norm] = {}
            end
            table.insert(by_norm[norm], idx)
        end
    end

    -- Find clusters by normalized name
    for norm, indices in pairs(by_norm) do
        if #indices > 1 then
            local cluster_contacts = {}
            for _, idx in ipairs(indices) do
                table.insert(cluster_contacts, contacts[idx])
                used[idx] = true
            end
            table.insert(clusters, {
                contacts = cluster_contacts,
                reason = "normalized name: " .. norm,
            })
        end
    end

    -- Index by email for remaining contacts
    local by_email = {}
    for idx, contact in ipairs(contacts) do
        if not used[idx] then
            for _, email in ipairs(contact.emails or {}) do
                local lower_email = email:lower()
                if not by_email[lower_email] then
                    by_email[lower_email] = {}
                end
                table.insert(by_email[lower_email], idx)
            end
        end
    end

    -- Find clusters by shared email
    local email_clusters = {}
    for email, indices in pairs(by_email) do
        if #indices > 1 then
            -- Build a cluster key from sorted indices to avoid duplicate clusters
            table.sort(indices)
            local key = table.concat(indices, ",")
            if not email_clusters[key] then
                local cluster_contacts = {}
                for _, idx in ipairs(indices) do
                    table.insert(cluster_contacts, contacts[idx])
                end
                email_clusters[key] = {
                    contacts = cluster_contacts,
                    reason = "shared email: " .. email,
                }
            end
        end
    end

    for _, cluster in pairs(email_clusters) do
        table.insert(clusters, cluster)
    end

    return clusters
end

--- Interactive dedup via Telescope — launch from contacts/telescope.lua
function M.interactive()
    local cfg = require("zet.config").get()
    local contacts_dir = cfg.home .. "/" .. (cfg.contacts and cfg.contacts.dir or "contacts")
    local clusters = M.find_duplicates(contacts_dir)

    if #clusters == 0 then
        vim.notify("No duplicate contacts found.", vim.log.levels.INFO)
        return
    end

    local has_telescope, _ = pcall(require, "telescope")
    if not has_telescope then
        vim.notify("Telescope is required for dedup", vim.log.levels.ERROR)
        return
    end

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    -- Build entries from clusters
    local entries = {}
    for _, cluster in ipairs(clusters) do
        local names = {}
        for _, c in ipairs(cluster.contacts) do
            table.insert(names, c.fn or "(unnamed)")
        end
        table.insert(entries, {
            display = table.concat(names, " | ") .. "  (" .. cluster.reason .. ")",
            cluster = cluster,
        })
    end

    pickers.new({}, {
        prompt_title = "Duplicate Contacts (" .. #clusters .. " clusters)",
        finder = finders.new_table({
            results = entries,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.display,
                    ordinal = entry.display,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if selection then
                    local cluster = selection.value.cluster
                    -- Merge all into the first contact
                    local target = cluster.contacts[1]
                    for i = 2, #cluster.contacts do
                        markdown.merge_contact_fields(target, cluster.contacts[i])
                    end
                    -- Write merged contact
                    local filepath = target._filepath
                    if filepath then
                        local lines = markdown.to_lines(target)
                        require("zet.utils").write_lines(filepath, lines)
                        -- Delete other files
                        for i = 2, #cluster.contacts do
                            local other_path = cluster.contacts[i]._filepath
                            if other_path and other_path ~= filepath then
                                vim.fn.delete(other_path)
                            end
                        end
                        vim.notify(
                            "Merged " .. #cluster.contacts .. " contacts into " .. (target.fn or ""),
                            vim.log.levels.INFO
                        )
                    end
                end
            end)
            return true
        end,
    }):find()
end

return M
