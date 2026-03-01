-- run via:
-- :PlenaryBustedFile tests/contacts_markdown_spec.lua

local markdown = require("zet.contacts.markdown")

describe("contacts markdown", function()
    describe("to_lines", function()
        it("should produce valid frontmatter", function()
            local contact = {
                fn = "Ed Sweeney",
                emails = { "ed@onextent.com" },
                phones = { "650-555-1234" },
                org = "Falkonry",
                urls = {},
                addresses = {},
                notes = { "Category: Network" },
            }
            local lines = markdown.to_lines(contact)
            assert.are.equal("---", lines[1])
            assert.are.equal("title: Ed Sweeney", lines[2])
            assert.is_truthy(lines[3]:match("^date: %d%d%d%d%-%d%d%-%d%d$"))
            assert.are.equal("type: contact", lines[4])
        end)

        it("should include emails as list", function()
            local contact = {
                fn = "Test",
                emails = { "a@b.com", "c@d.com" },
                phones = {},
                urls = {},
                addresses = {},
                notes = {},
            }
            local lines = markdown.to_lines(contact)
            local text = table.concat(lines, "\n")
            assert.is_truthy(text:match("emails:"))
            assert.is_truthy(text:match("  %- a@b.com"))
            assert.is_truthy(text:match("  %- c@d.com"))
        end)

        it("should use empty list for no emails", function()
            local contact = {
                fn = "Test",
                emails = {},
                phones = {},
                urls = {},
                addresses = {},
                notes = {},
            }
            local lines = markdown.to_lines(contact)
            local text = table.concat(lines, "\n")
            assert.is_truthy(text:match("emails: %[%]"))
        end)

        it("should include #contact tag", function()
            local contact = {
                fn = "Test",
                emails = {},
                phones = {},
                urls = {},
                addresses = {},
                notes = {},
            }
            local lines = markdown.to_lines(contact)
            local found = false
            for _, line in ipairs(lines) do
                if line == "#contact" then
                    found = true
                end
            end
            assert.is_true(found)
        end)

        it("should include notes section", function()
            local contact = {
                fn = "Test",
                emails = {},
                phones = {},
                urls = {},
                addresses = {},
                notes = { "Category: Network", "Met at conference" },
            }
            local lines = markdown.to_lines(contact)
            local text = table.concat(lines, "\n")
            assert.is_truthy(text:match("## Notes"))
            assert.is_truthy(text:match("Category: Network"))
            assert.is_truthy(text:match("Met at conference"))
        end)
    end)

    describe("merge_contact_fields", function()
        it("should union email lists", function()
            local target = {
                fn = "Test",
                emails = { "a@b.com" },
                phones = {},
                urls = {},
                addresses = {},
                notes = {},
            }
            local source = {
                fn = "Test",
                emails = { "a@b.com", "c@d.com" },
                phones = {},
                urls = {},
                addresses = {},
                notes = {},
            }
            markdown.merge_contact_fields(target, source)
            assert.are.equal(2, #target.emails)
        end)

        it("should prefer non-empty org", function()
            local target = {
                fn = "Test",
                org = nil,
                emails = {},
                phones = {},
                urls = {},
                addresses = {},
                notes = {},
            }
            local source = {
                fn = "Test",
                org = "Acme",
                emails = {},
                phones = {},
                urls = {},
                addresses = {},
                notes = {},
            }
            markdown.merge_contact_fields(target, source)
            assert.are.equal("Acme", target.org)
        end)

        it("should not overwrite existing org", function()
            local target = {
                fn = "Test",
                org = "Original",
                emails = {},
                phones = {},
                urls = {},
                addresses = {},
                notes = {},
            }
            local source = {
                fn = "Test",
                org = "New",
                emails = {},
                phones = {},
                urls = {},
                addresses = {},
                notes = {},
            }
            markdown.merge_contact_fields(target, source)
            assert.are.equal("Original", target.org)
        end)
    end)

    describe("round-trip", function()
        it("should survive to_lines -> read_contact", function()
            local original = {
                fn = "Jane Smith",
                n_first = "Jane",
                n_last = "Smith",
                emails = { "jane@example.com" },
                phones = { "555-9876" },
                org = "Tech Co",
                urls = { "https://jane.dev" },
                addresses = { "123 Main St, City, ST 12345" },
                notes = { "Met at RubyConf" },
                birthday = "1985-03-15",
            }

            -- Write to temp file
            local tmpdir = vim.fn.tempname()
            vim.fn.mkdir(tmpdir, "p")
            local lines = markdown.to_lines(original)
            vim.fn.writefile(lines, tmpdir .. "/Jane_Smith.md")

            -- Read back
            local loaded = markdown.read_contact(tmpdir .. "/Jane_Smith.md")

            assert.are.equal("Jane Smith", loaded.fn)
            assert.are.equal(1, #loaded.emails)
            assert.are.equal("jane@example.com", loaded.emails[1])
            assert.are.equal(1, #loaded.phones)
            assert.are.equal("555-9876", loaded.phones[1])
            assert.are.equal("Tech Co", loaded.org)
            assert.are.equal(1, #loaded.urls)
            assert.are.equal("https://jane.dev", loaded.urls[1])
            assert.are.equal(1, #loaded.addresses)
            assert.are.equal("1985-03-15", loaded.birthday)
            assert.are.equal(1, #loaded.notes)
            assert.are.equal("Met at RubyConf", loaded.notes[1])

            -- Cleanup
            vim.fn.delete(tmpdir, "rf")
        end)
    end)
end)
