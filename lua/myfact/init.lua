local templ = require("template")
local async = require("plenary.async")

local M = {}

local queries = {
    soften_constraint = {
        q = [[
(expression_statement
  (call function: (attribute
                    object: (identifier) @obj (#eq? @obj "model")
                    attribute: (identifier) @attr (#eq? @attr "Add") )
        arguments: (argument_list
                     (comparison_operator
                       (_) @lhs
                        _ @op
                       (_) @rhs)))) @stm
                       ]],
        q_parsed = nil,
        sub = [[#------automated substitution starts------
tmp_key = """{{ string.gsub(lhs..op..rhs,"%s+", " ") }}"""
tmp_var = model.NewBoolVar(tmp_key)
tmp_obj[tmp_key] = tmp_var
model.Add({{lhs}}{{op}}{{rhs}}).OnlyEnforceIf(tmp_var)
model.Add({{lhs}}{{op_not}}{{rhs}}).OnlyEnforceIf(tmp_var.Not())
#^^^^^^^^automated substitution ends------
]]
    },
    soften_conditional_constraint = {
        q = [[
(expression_statement
  (call function:
        (attribute
          object: (call function: (attribute
                                    object: (identifier) @obj (#eq? @obj "model")
                                    attribute: (identifier) @attr (#eq? @attr "Add") )
                        arguments: (argument_list
                                     (comparison_operator
                                       (_) @lhs
                                        _ @op
                                       (_) @rhs
                                       )))
          attribute:(identifier) @attr2 (#eq? @attr2 "OnlyEnforceIf") )
        arguments: (_) @enf_lit
        )) @stm

    ]],
        q_parsed = nil,
        sub = [[]]
    },
}
do
    for key, value in pairs(queries) do
        value.q_parsed = vim.treesitter.query.parse("python", value.q)
    end
end


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

--- refactors buffer within region.
---
---@param bufnr integer bufno
---@param startz integer? 0-based line to start with (including)
---@param endz integer? 0-based end line (excluding)
---@param refactoring_name string name of the refactoring to apply see queries keys above
function refactor(bufnr, startz, endz, refactoring_name)
    local to_replace = {}
    local query_parsed = queries[refactoring_name].q_parsed

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
        local env = setmetatable({
            obj = m.captures.obj and vim.treesitter.get_node_text(m.captures.obj, bufnr) or "",
            attr = m.captures.attr and vim.treesitter.get_node_text(m.captures.attr, bufnr) or "",
            lhs = m.captures.lhs and vim.treesitter.get_node_text(m.captures.lhs, bufnr) or "",
            op = m.captures.op and vim.treesitter.get_node_text(m.captures.op, bufnr) or "",
            rhs = m.captures.rhs and vim.treesitter.get_node_text(m.captures.rhs, bufnr) or "",
        }, { __index = _G })
        env.op_not = op_negations[env.op] or env.op

        -- Render the template
        local rendered = templ.compile(queries[refactoring_name].sub, env)

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
---@param refactoring_name string name of the refactoring to apply see queries keys above
M.find_matches = function(bufnr, startz, endz, refactoring_name)
    local to_replace = {}
    local query_parsed = queries[refactoring_name].q_parsed
    local captures = {}
    -- Collect matches and ask user
    for pattern, match, metadata in query_parsed:iter_matches(get_root(bufnr), bufnr, startz, endz) do
        for id, nodes in pairs(match) do
            local name = query_parsed.captures[id]
            captures[name] = nodes[1]
        end

        local stm = captures.stm
    end
    return captures
end

--- refactors buffer within region. Function is asynchronous, so will be
--- executed in a coroutine
---
---@param bufnr integer bufno
---@param startz integer? 0-based line to start with (including)
---@param endz integeri? 0-based end line (excluding)
---@param refactoring_name string name of the refactoring to apply see queries keys above
M.refactor = async.void(refactor)

return M
