if vim.g.loaded_zet then
    return
end
vim.g.loaded_zet = true

-- Tab-completable :Zet command
vim.api.nvim_create_user_command("Zet", function(opts)
    local zk = require("zet")
    local arg = opts.args and opts.args ~= "" and opts.args or "panel"
    if zk[arg] then
        zk[arg]()
    else
        vim.notify("Zet: unknown command '" .. arg .. "'", vim.log.levels.ERROR)
    end
end, {
    nargs = "?",
    complete = function()
        return require("zet").command_list()
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
