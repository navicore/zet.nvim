-- run via:
-- :PlenaryBustedFile tests/notes_spec.lua

local notes = require("zet.notes")

describe("notes", function()
    describe("generate_filename", function()
        local cfg = {
            uuid_type = "%Y-%m-%d-%H%M",
            uuid_sep = "-",
            filename_space_subst = "_",
            extension = ".md",
            new_note_filename = "uuid-title",
        }

        it("should generate uuid-title filename", function()
            local result = notes.generate_filename("My Test Note", cfg)
            assert.is_truthy(result:match("^%d%d%d%d%-%d%d%-%d%d%-%d%d%d%d%-My_Test_Note%.md$"))
        end)

        it("should generate uuid-only filename when no title", function()
            local result = notes.generate_filename(nil, cfg)
            assert.is_truthy(result:match("^%d%d%d%d%-%d%d%-%d%d%-%d%d%d%d%.md$"))
        end)

        it("should generate uuid-only filename for empty title", function()
            local result = notes.generate_filename("", cfg)
            assert.is_truthy(result:match("^%d%d%d%d%-%d%d%-%d%d%-%d%d%d%d%.md$"))
        end)

        it("should generate title-uuid filename", function()
            cfg.new_note_filename = "title-uuid"
            local result = notes.generate_filename("Test", cfg)
            assert.is_truthy(result:match("^Test%-%d%d%d%d%-%d%d%-%d%d%-%d%d%d%d%.md$"))
            cfg.new_note_filename = "uuid-title" -- restore
        end)

        it("should generate title-only filename", function()
            cfg.new_note_filename = "title"
            local result = notes.generate_filename("My Note", cfg)
            assert.are.equal("My_Note.md", result)
            cfg.new_note_filename = "uuid-title" -- restore
        end)

        it("should generate uuid-only filename when configured", function()
            cfg.new_note_filename = "uuid"
            local result = notes.generate_filename("Ignored Title", cfg)
            assert.is_truthy(result:match("^%d%d%d%d%-%d%d%-%d%d%-%d%d%d%d%.md$"))
            cfg.new_note_filename = "uuid-title" -- restore
        end)
    end)

    describe("update_backlinks", function()
        it("should be a callable function", function()
            assert.is_function(notes.update_backlinks)
        end)
    end)
end)
