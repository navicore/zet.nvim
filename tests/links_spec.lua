-- run via:
-- :PlenaryBustedFile tests/links_spec.lua

local links = require("zet.links")

describe("links", function()
    describe("link_under_cursor", function()
        -- These tests require buffer manipulation, so they test the parsing logic
        it("module should load without error", function()
            assert.is_not_nil(links)
            assert.is_function(links.follow_link)
            assert.is_function(links.insert_link)
            assert.is_function(links.link_under_cursor)
        end)
    end)

    describe("resolve_link", function()
        it("should return nil for non-existent links", function()
            -- Set up minimal config
            require("zet.config").setup({
                home = "/tmp/zet_test_nonexistent",
                archive_dirs = {},
                auto_set_filetype = false,
                reminders = { enabled = false },
                plug_into_calendar = false,
            })
            local result = links.resolve_link("nonexistent-note")
            assert.is_nil(result)
        end)
    end)
end)
