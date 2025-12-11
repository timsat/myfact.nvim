local function inspect_(...)
    local objects = {}
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        table.insert(objects, vim.inspect(v))
    end

    return (table.concat(objects, '\n'))
end
local log = require("plenary.log").new({
    plugin = "myfact.tests",
    use_file = false,
    outfile = "tests.log",
    level =
    "debug"
})

local myfact = require("myfact")
describe("myfact.find_matches", function()
    it("should return empty list on empty buffer", function()
        local matches = myfact.find_matches(0, 0, nil, 'soften_constraint')
        log.debug("1. " .. inspect_(matches))
        log.debug(matches)
        assert.are_same({}, matches)
    end)

    it("should contain captures on when open valid python file is opened", function()
        vim.schedule(function() vim.cmd("e tests/test_data/test1.py") end)
        vim.fn.wait(500, function() return false end)
        local matches = myfact.find_matches(0, 0, nil, 'soften_constraint')
        log.debug("1. " .. inspect_(matches))
        assert.are_equal(1, #matches)
        assert.no_same({}, matches)
    end)
end)

describe("myfact.populate_qflist", function()
    it("should handle empty list", function()
        myfact.populate_qflist(function() return {} end)
    end)
end)
