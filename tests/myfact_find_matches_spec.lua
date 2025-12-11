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

describe("myfact.find_matches", function()
    local myfact = require("myfact")
    it("should return empty list on empty buffer", function()
        local matches = myfact.find_matches(0, 0, nil, 'soften_constraint')
        log.debug("1. " .. inspect_(matches))
        log.debug(matches)
        assert.array_equal({}, matches, 1)
    end)

    it("should not fail", function()
        vim.schedule(function() vim.cmd("e tests/test_data/test1.py") end)
        vim.fn.wait(500, function() return false end)
        local matches = myfact.find_matches(0, 0, nil, 'soften_constraint')
        log.debug("2. " .. inspect_(matches))
        assert.array_equal({}, matches)
        assert.are_same(1, #matches)
    end)
end)
