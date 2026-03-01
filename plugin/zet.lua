if vim.g.loaded_zet then
    return
end
vim.g.loaded_zet = true

-- Tab-completable :Zet command
vim.api.nvim_create_user_command("Zet", function(opts)
    local zk = require("zet")
    local parts = vim.split(opts.args or "", "%s+", { trimempty = true })
    local cmd = parts[1] or "panel"
    local extra = table.concat({ unpack(parts, 2) }, " ")
    if zk[cmd] then
        if extra ~= "" then
            zk[cmd](extra)
        else
            zk[cmd]()
        end
    else
        vim.notify("Zet: unknown command '" .. cmd .. "'", vim.log.levels.ERROR)
    end
end, {
    nargs = "*",
    complete = function(_, line)
        local parts = vim.split(line, "%s+", { trimempty = true })
        if #parts <= 2 then
            return require("zet").command_list()
        end
        return {}
    end,
})

-- Filetype detection: set zet filetype for .md files in the vault
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = "*.md",
    callback = function(ev)
        local cfg = require("zet.config").get()
        if not cfg.auto_set_filetype then
            return
        end
        local bufpath = vim.fn.fnamemodify(ev.file, ":p")
        for _, dir in ipairs(cfg.scan_dirs or { cfg.home }) do
            local abs_dir = vim.fn.fnamemodify(dir, ":p")
            if bufpath:sub(1, #abs_dir) == abs_dir then
                vim.bo[ev.buf].filetype = "zet"
                return
            end
        end
    end,
})
