if vim.g.loaded_myfact == 1 then
    return
end

vim.g.loaded_myfact = 1

local function refactor(opts)
    local startz = opts.line1 - 1
    local endz = opts.range ~= 0 and opts.line2 or nil -- end0 is exluded from matching so keeping it 1 line bigger
    require("myfact").refactor(0, startz, endz, "soften_constraint")
end


vim.api.nvim_create_user_command("Myfact", refactor, { nargs = 0, range = true })
