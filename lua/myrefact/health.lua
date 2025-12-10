local M = {}


M.check = function()
    vim.health.start("Dependencies")
    -- make sure setup function parameters are ok
    local res, _ = pcall(function() require("plenary.async") end)
    if res then
        vim.health.ok("Setup is correct")
    else
        vim.health.error("plenary.async couldn't be loaded")
    end
end

return M
