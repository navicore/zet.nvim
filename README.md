# zet.nvim

A focused Zettelkasten note-taking plugin for Neovim with integrated reminder
management. Built on Telescope and designed to work with existing markdown note
collections without migration.

> **Note:** This is my personal fork/rewrite combining the features I actually
> use from [telekasten.nvim](https://github.com/renerocksai/telekasten.nvim)
> and my own [nvim-reminders](https://github.com/navicore/nvim-reminders).
> You're welcome to use it, but if you want a full-featured, well-supported
> Zettelkasten plugin, **telekasten.nvim is probably what you want**. This repo
> exists because I only use ~12 of telekasten's many features and wanted a
> smaller codebase I can extend (image handling, etc.) without carrying the
> rest.

## Requirements

- Neovim >= 0.8
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (required)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (required, dependency of telescope)
- [calendar-vim](https://github.com/mattn/calendar-vim) (optional, for calendar integration)
- [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) (optional, detects the `zet` filetype)

## Installation

### lazy.nvim

```lua
{
    "navicore/zet.nvim",
    dependencies = {
        "nvim-telescope/telescope.nvim",
        "nvim-lua/plenary.nvim",
        "mattn/calendar-vim", -- optional
    },
    config = function()
        require("zet").setup({
            -- see Configuration below
        })
    end,
}
```

## Configuration

```lua
require("zet").setup({
    home = "~/git/navicore/zet",
    templates = "~/git/navicore/zet/templates",
    template_new_note = "~/git/navicore/zet/templates/base_note.md",
    template_new_daily = "~/git/navicore/zet/templates/daily.md",
    template_new_weekly = "~/git/navicore/zet/templates/weekly.md",

    -- Filename generation
    new_note_filename = "uuid-title",   -- "uuid-title", "title-uuid", "uuid", or "title"
    uuid_type = "%Y-%m-%d-%H%M",       -- os.date() format string for UUID
    uuid_sep = "-",                     -- separator between UUID and title
    filename_space_subst = "_",         -- replace spaces in filenames
    extension = ".md",

    -- Year-based archive dirs to scan for links and search
    archive_dirs = { "2015", "2016", "2017", "2018", "2019",
                     "2020", "2021", "2022", "2023", "2024" },

    -- Behavior
    follow_creates_nonexisting = true,  -- following a [[link]] creates the note if missing
    dailies_create_nonexisting = true,  -- goto_today creates the note if missing
    rename_update_links = true,         -- renaming a note updates all [[backlinks]]
    tag_notation = "#tag",

    -- Calendar (requires calendar-vim)
    plug_into_calendar = true,
    calendar_opts = {
        weeknm = 4,
        calendar_monday = 1,
        calendar_mark = "left-fit",
    },

    -- Appearance
    auto_set_filetype = true,           -- set zet filetype for vault .md files
    command_palette_theme = "ivy",      -- "ivy" or "dropdown"

    -- Reminders
    reminders = {
        enabled = true,
        scan_on_save = true,            -- auto-convert natural language times on save
        show_virtual_text = true,       -- show countdown extmarks
        default_threshold_hours = 48,   -- for upcoming reminder scans
    },
})
```

### Templates

Template files use `{{variable}}` placeholders:

| Variable | Value |
|----------|-------|
| `{{title}}` | Note title |
| `{{date}}` | `YYYY-MM-DD` |
| `{{time}}` | `HH:MM` |
| `{{year}}` | `YYYY` |
| `{{month}}` | `MM` |
| `{{day}}` | `DD` |
| `{{hdate}}` | Human-readable date (e.g., "Saturday, February 15, 2026") |
| `{{week}}` | `YYYY-WNN` |
| `{{uuid}}` | Generated UUID |

## Commands

All accessible via `:Zet <subcommand>` with tab completion.
`:Zet` alone opens the command palette.

| Command | Description |
|---------|-------------|
| `panel` | Command palette (all commands via Telescope) |
| `find_notes` | Browse notes by filename |
| `find_daily_notes` | Browse daily notes only |
| `search_notes` | Live grep across all notes |
| `new_note` | Create note with uuid-title filename |
| `new_templated_note` | Pick a template, then create note |
| `rename_note` | Rename + update all `[[backlinks]]` |
| `follow_link` | Follow `[[link]]` under cursor (create if missing) |
| `insert_link` | Pick a note, insert `[[link]]` at cursor |
| `goto_today` | Open/create today's daily note |
| `show_tags` | Browse all `#tags` via Telescope |
| `show_calendar` | Open calendar-vim |
| `reminder_scan` | Show due reminders |
| `reminder_scan_upcoming` | Show reminders due within N hours |
| `reminder_scan_all` | Show all reminders |
| `reminder_edit` | Snooze/edit reminder on current line |

Legacy aliases: `:ReminderScan`, `:ReminderScanUpcoming`, `:ReminderScanAll`, `:ReminderEdit`

## Keybinding Examples

```lua
local zk = require("zet")
vim.keymap.set("n", "<leader>zf", zk.find_notes, { desc = "Find notes" })
vim.keymap.set("n", "<leader>zd", zk.find_daily_notes, { desc = "Daily notes" })
vim.keymap.set("n", "<leader>zg", zk.search_notes, { desc = "Grep notes" })
vim.keymap.set("n", "<leader>zn", zk.new_note, { desc = "New note" })
vim.keymap.set("n", "<leader>zt", zk.new_templated_note, { desc = "New from template" })
vim.keymap.set("n", "<leader>zz", zk.follow_link, { desc = "Follow link" })
vim.keymap.set("n", "<leader>zi", zk.insert_link, { desc = "Insert link" })
vim.keymap.set("n", "<leader>zT", zk.goto_today, { desc = "Today's note" })
vim.keymap.set("n", "<leader>z#", zk.show_tags, { desc = "Tags" })
vim.keymap.set("n", "<leader>zc", zk.show_calendar, { desc = "Calendar" })
vim.keymap.set("n", "<leader>zr", zk.reminder_scan, { desc = "Due reminders" })
vim.keymap.set("n", "<leader>zR", zk.reminder_scan_all, { desc = "All reminders" })
vim.keymap.set("n", "<leader>ze", zk.reminder_edit, { desc = "Snooze reminder" })
vim.keymap.set("n", "<leader>zp", zk.panel, { desc = "Command palette" })
```

## Reminders

Write reminders inline in any note:

```markdown
#reminder in 2 hours: review pull request
```

On save, the natural language time auto-converts to ISO 8601:

```markdown
* [ ] #reminder 2026-02-15T17:30:00Z: review pull request
```

Virtual text shows countdowns at the end of each reminder line. Check off a
reminder (`[x]`) and it won't appear in scans.

Supported time expressions:
- `in 10 minutes`, `in 2 hours`, `in 1 week`
- `tomorrow at 6am`, `today at 3:30pm`
- `next Monday`, `on Tuesday at 3pm`
- `Feb 14 at 6pm`, `December 25, 2025`
- `2/20/26 9am`

## Tmux Integration

Three scripts in `scripts/` integrate with tmux. The paths below assume
lazy.nvim — adjust if your plugin manager installs elsewhere.

**Status bar reminder count** — reference in `status-right`:
```
#($HOME/.local/share/nvim/lazy/zet.nvim/scripts/tmux-reminders.sh $HOME/git/$(whoami)/zet)
```

**Popup keybindings:**
```tmux
bind r run-shell '$HOME/.local/share/nvim/lazy/zet.nvim/scripts/tmux-reminder-popup.sh'
bind z run-shell '$HOME/.local/share/nvim/lazy/zet.nvim/scripts/tmux-zett-popup.sh'
```

**Click support** for the status bar badges:
```tmux
bind -Troot MouseDown1Status if -F '#{==:#{mouse_status_range},reminder}' \
  'run-shell "$HOME/.local/share/nvim/lazy/zet.nvim/scripts/tmux-reminder-popup.sh"' \
  'if -F "#{==:#{mouse_status_range},zett}" \
    "run-shell $HOME/.local/share/nvim/lazy/zet.nvim/scripts/tmux-zett-popup.sh" \
    "select-window -t ="'
```

## Syntax Highlighting

The `zet` filetype extends markdown with highlight groups for:
- `zkLink` — `[[wiki links]]`
- `zkHighlight` — `==highlighted text==`
- `zkTag` — `#tags`
- `zkBrackets` — the `[[` `]]` `==` delimiters

These work with any colorscheme. If you use render-markdown.nvim, add
`zet` to its filetypes.

## Credits

This plugin is a focused rewrite combining ideas and code from:

- [telekasten.nvim](https://github.com/renerocksai/telekasten.nvim) by renerocksai — the Zettelkasten features, Telescope patterns, calendar integration, and syntax highlighting
- [nvim-reminders](https://github.com/navicore/nvim-reminders) — the time parser, reminder scanning, and tmux integration

## License

MIT
