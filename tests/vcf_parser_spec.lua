-- run via:
-- :PlenaryBustedFile tests/vcf_parser_spec.lua

local parser = require("zet.contacts.vcf_parser")

describe("vcf_parser", function()
    describe("unfold", function()
        it("should join continuation lines", function()
            local lines = {
                "NOTE:This is a long",
                " continuation line",
                "TEL:555-1234",
            }
            local result = parser.unfold(lines)
            assert.are.equal(3, #lines)
            assert.are.equal(2, #result)
            assert.are.equal("NOTE:This is a longcontinuation line", result[1])
            assert.are.equal("TEL:555-1234", result[2])
        end)

        it("should handle tab continuation", function()
            local lines = {
                "NOTE:line one",
                "\tline two",
            }
            local result = parser.unfold(lines)
            assert.are.equal(1, #result)
            assert.are.equal("NOTE:line oneline two", result[1])
        end)

        it("should handle no continuations", function()
            local lines = { "FN:John", "TEL:555" }
            local result = parser.unfold(lines)
            assert.are.equal(2, #result)
        end)
    end)

    describe("parse_property", function()
        it("should parse simple property", function()
            local prop = parser.parse_property("FN:John Doe")
            assert.are.equal("FN", prop.name)
            assert.are.equal("John Doe", prop.value)
        end)

        it("should parse property with params", function()
            local prop = parser.parse_property("TEL;type=WORK:555-1234")
            assert.are.equal("TEL", prop.name)
            assert.are.equal("555-1234", prop.value)
            assert.are.equal("WORK", prop.params.type)
        end)

        it("should parse property with multiple params", function()
            local prop = parser.parse_property("TEL;type=WORK;type=VOICE:555-1234")
            assert.are.equal("TEL", prop.name)
            assert.are.equal("555-1234", prop.value)
        end)

        it("should handle bare params", function()
            local prop = parser.parse_property("TEL;WORK:555-1234")
            assert.are.equal("TEL", prop.name)
            assert.is_truthy(prop.params.work)
        end)

        it("should return nil for empty line", function()
            assert.is_nil(parser.parse_property(""))
            assert.is_nil(parser.parse_property(nil))
        end)

        it("should handle value with colons", function()
            local prop = parser.parse_property("URL:https://example.com:8080/path")
            assert.are.equal("URL", prop.name)
            assert.are.equal("https://example.com:8080/path", prop.value)
        end)

        it("should uppercase the property name", function()
            local prop = parser.parse_property("fn:Jane")
            assert.are.equal("FN", prop.name)
        end)
    end)

    describe("unescape_value", function()
        it("should unescape newlines", function()
            assert.are.equal("line1\nline2", parser.unescape_value("line1\\nline2"))
            assert.are.equal("line1\nline2", parser.unescape_value("line1\\Nline2"))
        end)

        it("should unescape commas and semicolons", function()
            assert.are.equal("a,b", parser.unescape_value("a\\,b"))
            assert.are.equal("a;b", parser.unescape_value("a\\;b"))
        end)

        it("should unescape backslashes", function()
            assert.are.equal("a\\b", parser.unescape_value("a\\\\b"))
        end)

        it("should handle nil", function()
            assert.are.equal("", parser.unescape_value(nil))
        end)
    end)

    describe("parse_vcard", function()
        it("should parse a basic vcard", function()
            local lines = {
                "FN:John Doe",
                "N:Doe;John;;;",
                "EMAIL:john@example.com",
                "TEL;type=CELL:555-1234",
                "ORG:Acme Corp",
            }
            local contact = parser.parse_vcard(lines)
            assert.are.equal("John Doe", contact.fn)
            assert.are.equal("Doe", contact.n_last)
            assert.are.equal("John", contact.n_first)
            assert.are.equal(1, #contact.emails)
            assert.are.equal("john@example.com", contact.emails[1])
            assert.are.equal(1, #contact.phones)
            assert.are.equal("555-1234", contact.phones[1])
            assert.are.equal("Acme Corp", contact.org)
        end)

        it("should handle multiple emails", function()
            local lines = {
                "FN:Jane",
                "EMAIL:jane@work.com",
                "EMAIL:jane@home.com",
            }
            local contact = parser.parse_vcard(lines)
            assert.are.equal(2, #contact.emails)
        end)

        it("should parse address", function()
            local lines = {
                "FN:Test",
                "ADR:;;123 Main St;Springfield;IL;62701;US",
            }
            local contact = parser.parse_vcard(lines)
            assert.are.equal(1, #contact.addresses)
            assert.is_truthy(contact.addresses[1]:match("123 Main St"))
        end)

        it("should parse birthday", function()
            local lines = {
                "FN:Test",
                "BDAY:1990-01-15",
            }
            local contact = parser.parse_vcard(lines)
            assert.are.equal("1990-01-15", contact.birthday)
        end)

        it("should parse notes", function()
            local lines = {
                "FN:Test",
                "NOTE:Category: Network",
            }
            local contact = parser.parse_vcard(lines)
            assert.are.equal(1, #contact.notes)
            assert.are.equal("Category: Network", contact.notes[1])
        end)

        it("should parse URL", function()
            local lines = {
                "FN:Test",
                "URL:https://example.com",
            }
            local contact = parser.parse_vcard(lines)
            assert.are.equal(1, #contact.urls)
            assert.are.equal("https://example.com", contact.urls[1])
        end)

        it("should handle empty N components", function()
            local lines = {
                "FN:Madonna",
                "N:Madonna;;;;",
            }
            local contact = parser.parse_vcard(lines)
            assert.are.equal("Madonna", contact.n_last)
            assert.are.equal("", contact.n_first)
        end)
    end)

    describe("parse_file", function()
        it("should return error for missing file", function()
            local contacts, err = parser.parse_file("/nonexistent/file.vcf")
            assert.is_nil(contacts)
            assert.is_truthy(err)
        end)
    end)
end)
