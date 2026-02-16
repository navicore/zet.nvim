-- run via:
-- :PlenaryBustedFile tests/templates_spec.lua

local templates = require("zet.templates")

describe("templates", function()
    describe("substitute", function()
        it("should replace {{variable}} placeholders", function()
            local result = templates.substitute("Hello {{name}}", { name = "World" })
            assert.are.equal("Hello World", result)
        end)

        it("should replace multiple variables", function()
            local result = templates.substitute("{{date}} - {{title}}", { date = "2026-02-15", title = "Test" })
            assert.are.equal("2026-02-15 - Test", result)
        end)

        it("should preserve unmatched placeholders", function()
            local result = templates.substitute("{{known}} and {{unknown}}", { known = "yes" })
            assert.are.equal("yes and {{unknown}}", result)
        end)

        it("should return nil for nil input", function()
            assert.is_nil(templates.substitute(nil, {}))
        end)
    end)

    describe("load", function()
        it("should return nil for non-existent file", function()
            assert.is_nil(templates.load("/tmp/nonexistent_template_file.md"))
        end)

        it("should return nil for nil path", function()
            assert.is_nil(templates.load(nil))
        end)
    end)
end)
