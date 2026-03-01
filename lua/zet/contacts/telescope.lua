-- Telescope contact picker for browsing and searching contacts
local M = {}

local has_telescope, _ = pcall(require, "telescope")
if not has_telescope then
    return M
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")

local config = require("zet.config")
local markdown = require("zet.contacts.markdown")

local function make_display(entry)
    local name = entry.value.fn or ""
    local email = (entry.value.emails and entry.value.emails[1]) or ""
    local org = entry.value.org or ""

    local displayer = entry_display.create({
        separator = " — ",
        items = {
            { width = 30 },
            { width = 30 },
            { remaining = true },
        },
    })

    return displayer({
        name,
        { email, "Comment" },
        { org, "Special" },
    })
end

--- Browse/search contacts via Telescope
function M.contacts_picker()
    local cfg = config.get()
    local contacts_dir = cfg.home .. "/" .. (cfg.contacts and cfg.contacts.dir or "contacts")
    local contacts = markdown.read_all(contacts_dir)

    if #contacts == 0 then
        vim.notify("No contacts found in " .. contacts_dir, vim.log.levels.INFO)
        return
    end

    -- Sort alphabetically
    table.sort(contacts, function(a, b)
        return (a.fn or ""):lower() < (b.fn or ""):lower()
    end)

    pickers.new({}, {
        prompt_title = "Contacts (" .. #contacts .. ")",
        finder = finders.new_table({
            results = contacts,
            entry_maker = function(contact)
                local ordinal = (contact.fn or "")
                    .. " "
                    .. table.concat(contact.emails or {}, " ")
                    .. " "
                    .. (contact.org or "")
                return {
                    value = contact,
                    display = make_display,
                    ordinal = ordinal,
                    filename = contact._filepath,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        previewer = conf.file_previewer({}),
        attach_mappings = function(prompt_bufnr, map)
            -- CR opens contact file
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if selection and selection.filename then
                    vim.cmd("edit " .. vim.fn.fnameescape(selection.filename))
                end
            end)

            -- 'd' triggers dedup for the selected contact
            map("n", "d", function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if selection then
                    require("zet.contacts.dedup").interactive()
                end
            end)

            return true
        end,
    }):find()
end

return M
