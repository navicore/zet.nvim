.PHONY: test test-time-parser test-dates test-templates test-links test-notes test-vcf-parser test-contacts-markdown test-dedup lint

PLENARY_DIR ?= $(shell nvim --headless -c 'echo stdpath("data") .. "/lazy/plenary.nvim"' -c 'quit' 2>&1 | tr -d '\n')

test:
	nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'scripts/minimal_init.vim'}"

test-time-parser:
	nvim --headless -c "PlenaryBustedFile tests/time_parser_spec.lua"

test-dates:
	nvim --headless -c "PlenaryBustedFile tests/dates_spec.lua"

test-templates:
	nvim --headless -c "PlenaryBustedFile tests/templates_spec.lua"

test-links:
	nvim --headless -c "PlenaryBustedFile tests/links_spec.lua"

test-notes:
	nvim --headless -c "PlenaryBustedFile tests/notes_spec.lua"

test-vcf-parser:
	nvim --headless -c "PlenaryBustedFile tests/vcf_parser_spec.lua"

test-contacts-markdown:
	nvim --headless -c "PlenaryBustedFile tests/contacts_markdown_spec.lua"

test-dedup:
	nvim --headless -c "PlenaryBustedFile tests/dedup_spec.lua"

lint:
	luacheck lua/ --no-max-line-length --globals vim
