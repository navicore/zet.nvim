-- run via:
-- :PlenaryBustedFile tests/dedup_spec.lua

local dedup = require("zet.contacts.dedup")
local markdown = require("zet.contacts.markdown")

describe("dedup", function()
    describe("normalize_name", function()
        it("should lowercase names", function()
            assert.are.equal("john doe", dedup.normalize_name("John Doe"))
        end)

        it("should strip 'via LinkedIn'", function()
            assert.are.equal("john doe", dedup.normalize_name("John Doe via LinkedIn"))
        end)

        it("should strip parentheticals", function()
            assert.are.equal("john doe", dedup.normalize_name("John Doe (Acme Corp)"))
        end)

        it("should handle nil", function()
            assert.are.equal("", dedup.normalize_name(nil))
        end)

        it("should strip extra whitespace", function()
            assert.are.equal("john doe", dedup.normalize_name("  John   Doe  "))
        end)

        it("should handle combined patterns", function()
            assert.are.equal("jane smith", dedup.normalize_name("Jane Smith (CEO) via LinkedIn"))
        end)
    end)

    describe("merge_exact_fn", function()
        it("should merge contacts with same FN", function()
            local contacts = {
                {
                    fn = "John Doe",
                    emails = { "john@work.com" },
                    phones = {},
                    urls = {},
                    addresses = {},
                    notes = {},
                },
                {
                    fn = "John Doe",
                    emails = { "john@personal.com" },
                    phones = { "555-1234" },
                    urls = {},
                    addresses = {},
                    notes = {},
                },
                {
                    fn = "Jane Smith",
                    emails = { "jane@work.com" },
                    phones = {},
                    urls = {},
                    addresses = {},
                    notes = {},
                },
            }

            local result = dedup.merge_exact_fn(contacts)
            assert.are.equal(2, #result)

            -- Find John
            local john
            for _, c in ipairs(result) do
                if c.fn == "John Doe" then
                    john = c
                end
            end
            assert.is_truthy(john)
            assert.are.equal(2, #john.emails)
            assert.are.equal(1, #john.phones)
        end)

        it("should skip contacts with empty FN", function()
            local contacts = {
                { fn = "", emails = { "a@b.com" }, phones = {}, urls = {}, addresses = {}, notes = {} },
                { fn = "Valid", emails = {}, phones = {}, urls = {}, addresses = {}, notes = {} },
            }
            local result = dedup.merge_exact_fn(contacts)
            assert.are.equal(1, #result)
            assert.are.equal("Valid", result[1].fn)
        end)

        it("should preserve order of first occurrence", function()
            local contacts = {
                { fn = "Bravo", emails = {}, phones = {}, urls = {}, addresses = {}, notes = {} },
                { fn = "Alpha", emails = {}, phones = {}, urls = {}, addresses = {}, notes = {} },
                { fn = "Bravo", emails = { "extra@b.com" }, phones = {}, urls = {}, addresses = {}, notes = {} },
            }
            local result = dedup.merge_exact_fn(contacts)
            assert.are.equal(2, #result)
            assert.are.equal("Bravo", result[1].fn)
            assert.are.equal("Alpha", result[2].fn)
        end)
    end)

    describe("find_duplicates", function()
        it("should find dupes by normalized name", function()
            local tmpdir = vim.fn.tempname()
            vim.fn.mkdir(tmpdir, "p")

            -- Write two contacts with names that normalize the same
            local c1 = {
                fn = "John Doe",
                emails = { "john@a.com" },
                phones = {},
                urls = {},
                addresses = {},
                notes = {},
            }
            local c2 = {
                fn = "John Doe (Acme)",
                emails = { "john@b.com" },
                phones = {},
                urls = {},
                addresses = {},
                notes = {},
            }
            local lines1 = markdown.to_lines(c1)
            local lines2 = markdown.to_lines(c2)
            vim.fn.writefile(lines1, tmpdir .. "/John_Doe.md")
            vim.fn.writefile(lines2, tmpdir .. "/John_Doe_(Acme).md")

            local clusters = dedup.find_duplicates(tmpdir)
            assert.are.equal(1, #clusters)
            assert.are.equal(2, #clusters[1].contacts)

            vim.fn.delete(tmpdir, "rf")
        end)
    end)
end)
