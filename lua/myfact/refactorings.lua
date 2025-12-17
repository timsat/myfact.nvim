M = {}

--- @type {string: {q: string, sub: string, lang:string} }[]
M.all = {
    substitute_optional = {
        q = [[
(type (subscript value: (_) @val (#eq? @val "t.Optional")
                 subscript: (_) @sub) ) @stm
                       ]],
        sub = [[{{sub}} | None]],
        lang = "python",
    },
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
        sub = [[#------automated substitution starts------
tmp_key = """{{ string.gsub(lhs..op..rhs,"%s+", " ") }}"""
tmp_var = model.NewBoolVar(tmp_key)
tmp_obj[tmp_key] = tmp_var
model.Add({{lhs}}{{op}}{{rhs}}).OnlyEnforceIf(tmp_var)
model.Add({{lhs}}{{op_not}}{{rhs}}).OnlyEnforceIf(tmp_var.Not())
#^^^^^^^^automated substitution ends------
]],
        lang = "python",
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
        sub = [[]],
        lang = "python",
    },
}

return M
