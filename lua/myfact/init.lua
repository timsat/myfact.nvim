local templ = require("template")
local async = require("plenary.async")

local M = {}

--- @class MatchEntry
--- @field node TSNode
--- @field bufnr integer
---
---
--- @class Refactoring
--- @field q string
--- @field sub string
--- @field lang string

local op_negations = {
    ["=="] = "!=",
    ["!="] = "==",
    ["<"] = ">=",
    [">="] = "<",
    ["<="] = ">",
    [">"] = "<=",
}

local function get_root(bufnr)
    local parser = vim.treesitter.get_parser(bufnr, "python", {})
    local tree = parser:parse()[1]
    return tree:root()
end

local confirm = async.wrap(function(prompt, callback)
    local ns_id = vim.api.nvim_create_namespace('')
    vim.api.nvim_echo({ { prompt, "Question" } }, false, {})
    --vim.print(prompt)

    vim.on_key(function(key)
        -- Clean up
        vim.on_key(nil, ns_id)
        vim.api.nvim_echo({ { "", "None" } }, false, {})

        -- Return the key via callback
        vim.schedule(function()
            callback(key)
        end)
        return ""
    end, ns_id)
end, 2)

local select_range = async.wrap(function(sr, sc, so, er, ec, eo, cb)
    vim.fn.setpos("'<", { 0, sr + 1, sc + 1, so })
    vim.fn.setpos("'>", { 0, er + 1, ec + 1, eo })
    vim.cmd("normal! gv")
    vim.defer_fn(cb, 200)
end, 7)

---
---
---@param matchentry MatchEntry
---@return table
local matchentry_to_qf = function(matchentry)
    local text   = vim.treesitter.get_node_text(matchentry.node, matchentry.bufnr)
    local sl, sc = matchentry.node:range(false)

    return {
        bufnr = matchentry.bufnr,
        filename = vim.api.nvim_buf_get_name(matchentry.bufnr),
        lnum = sl + 1,
        col = sc + 1,
        text = text,
    }
end

--- refactors buffer within region.
---
---@param bufnr integer bufno
---@param startz integer? 0-based line to start with (including)
---@param endz integer? 0-based end line (excluding)
---@param refactoring Refactoring the refactoring to apply
local function refactor(bufnr, startz, endz, refactoring)
    local to_replace = {}

    --- @type vim.treesitter.Query
    local query_parsed = vim.treesitter.query.parse(refactoring.lang, refactoring.q)

    -- Collect matches and ask user
    for pattern, match, metadata in query_parsed:iter_matches(get_root(bufnr), bufnr, startz, endz) do
        local captures = {}
        for id, nodes in pairs(match) do
            local name = query_parsed.captures[id]
            captures[name] = nodes[1]
        end

        local stm = captures.stm
        if stm then
            local sr, sc, so, er, ec, eo = stm:range(true)
            select_range(sr, sc, so, er, ec, eo)
            local _input = confirm("Replace? (y/n/q): ")

            if _input == "q" then
                break
            elseif _input == "y" then
                -- Save this match for later replacement
                table.insert(to_replace, {
                    captures = captures,
                    sr = sr,
                    sc = sc,
                    so = so,
                    er = er,
                    ec = ec,
                    eo = eo,
                })
            end
        end
    end

    -- Apply replacements in reverse order (bottom to top)
    for i = #to_replace, 1, -1 do
        local m = to_replace[i]

        -- Extract text from captured nodes
        local captures_text = vim.tbl_map(
            function(v)
                return vim.treesitter.get_node_text(v, bufnr) or ""
            end, m.captures)
        local env = setmetatable(captures_text, { __index = _G })
        env.op_not = op_negations[env.op] or env.op

        -- Render the template
        local rendered = templ.compile(refactoring.sub, env)

        -- Get range and indentation
        local sr, sc, er, ec = m.captures.stm:range()
        local indent = string.rep(" ", sc)

        -- Split rendered text and add indentation to all lines except first
        local lines = vim.split(rendered, "\n")
        for j = 2, #lines do
            lines[j] = indent .. lines[j]
        end

        -- Replace the text at stm's range
        vim.api.nvim_buf_set_text(bufnr, sr, sc, er, ec, lines)
    end

    vim.api.nvim_input("<esc>")
end

--- finds matches <wip>
---
---@param bufnr integer bufno
---@param startz integer? 0-based line to start with (including)
---@param endz integer? 0-based end line (excluding)
---@param refactoring Refactoring the refactoring to search query from
---@return MatchEntry[]
M.find_matches = function(bufnr, startz, endz, refactoring)
    --- @type vim.treesitter.Query
    local query_parsed = vim.treesitter.query.parse(refactoring.lang, refactoring.q)
    local captures = {}
    local norm_bufnr = vim.fn.bufnr(bufnr)
    -- Collect matches and ask user
    for pattern, match, metadata in query_parsed:iter_matches(get_root(bufnr), bufnr, startz, endz) do
        local capture = {}
        for id, nodes in pairs(match) do
            local name = query_parsed.captures[id]
            capture[name] = nodes[1]
        end
        table.insert(captures, { node = capture.stm, bufnr = norm_bufnr })
    end
    return captures
end

--- Calls list_producer function to get the list and puts it into qflist
---
---@param list_producer fun(): MatchEntry[] function which generates matches
M.populate_qflist = function(list_producer)
    local qf_entries = {}
    for _, value in ipairs(list_producer()) do
        table.insert(qf_entries, matchentry_to_qf(value))
    end
    vim.fn.setqflist(qf_entries, " ")
    vim.fn.setqflist({}, "a", { title = "myfact matches" })
end
--[[
local myfact = require('myfact')
myfact.populate_qflist(function() myfact.find_matches(0,0,nil,"soften_constraint") end)
--]]

--- refactors buffer within region. Function is asynchronous, so will be
--- executed in a coroutine
---
---@param bufnr integer bufno
---@param startz integer? 0-based line to start with (including)
---@param endz integeri? 0-based end line (excluding)
---@param refactoring Refactoring the refactoring to apply
M.refactor = async.void(refactor)

return M
