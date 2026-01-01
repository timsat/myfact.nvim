if vim.g.loaded_myfact == 1 then
    return
end

vim.g.loaded_myfact = 1

local function refactor(opts)
    local startz = opts.line1 - 1
    local endz = opts.range ~= 0 and opts.line2 or nil -- end0 is exluded from matching so keeping it 1 line bigger
    require("myfact").refactor(0, startz, endz, require("myfact.refactorings").all[opts.args])
end

local function find_pattern(opts)
    local myfact = require("myfact")
    local startz = opts.line1 - 1
    local endz = opts.range ~= 0 and opts.line2 or nil -- end0 is exluded from matching so keeping it 1 line bigger
    myfact.populate_qflist(function()
        return myfact.find_matches(0, startz, endz, require("myfact.refactorings").all[opts.args])
    end
    )
end

local refactoring_names = vim.tbl_keys(require("myfact.refactorings").all)

vim.api.nvim_create_user_command("Myfact", refactor,
    { nargs = 1, range = true, complete = function() return refactoring_names end });

vim.api.nvim_create_user_command("MyfactFind", find_pattern,
    { nargs = 1, range = true, complete = function() return refactoring_names end })
