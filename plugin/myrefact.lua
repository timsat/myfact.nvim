if vim.g.loaded_myrefact == 1 then
    return
end

vim.g.loaded_myrefact = 1
local function refactor(opts)
    local startz = opts.range ~= 0 and opts.line1 - 1 or nil
    local endz = opts.range ~= 0 and opts.line2 or nil -- end0 is exluded from matching so keeping it 1 line bigger
    require("myrefact").refactor(0, startz, endz, "soften_constraint")
end


vim.api.nvim_create_user_command("Myrefact", refactor, { nargs = 0, range = true })
