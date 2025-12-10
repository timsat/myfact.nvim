# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**myrefact.nvim** - Neovim plugin for automated constraint softening in Python OR-Tools/CP-SAT solver models. Converts hard constraints like `model.Add(x == y)` into soft constraints with optional enforcement variables using Tree-sitter queries and template-based code generation.

## Architecture

### Three-Component Design

1. **plugin/myrefact.lua** - Plugin entry point that registers `:Myrefact` command
2. **lua/myrefact/init.lua** - Core refactoring engine with Tree-sitter queries
3. **lua/template.lua** - Standalone template engine (reusable, no dependencies on plugin)

### Core Workflow Pattern

The plugin implements an async interactive refactoring workflow:

1. Parse Python code with Tree-sitter queries to find constraint patterns
2. Highlight each match and prompt user interactively (y/n/q)
3. Collect all approved matches
4. **Apply replacements in reverse order** (bottom to top) to maintain line offsets
5. Use template engine to generate replacement code with preserved indentation

**Critical:** Replacements must be applied in reverse order (line 141 in init.lua) to prevent line number offsets from invalidating subsequent replacements.

## Dependencies

- **plenary.nvim** - Required for async/await operations via `plenary.async`
- **Neovim Tree-sitter** with Python parser installed
- No error checking for dependencies currently implemented

## Tree-sitter Query System

Located in `lua/myrefact/init.lua`, lines 6-56.

### Query Structure

Two patterns defined in the `queries` table:
- **soften_constraint** - Finds `model.Add(x == y)` patterns (fully implemented)
- **soften_conditional_constraint** - Finds `model.Add(...).OnlyEnforceIf(...)` patterns (incomplete: has query but empty substitution template at line 49)

### Captured Nodes

Queries capture these nodes for use in templates:
- `@obj` - Object name (filtered to "model")
- `@attr` - Method name (filtered to "Add")
- `@lhs` - Left-hand side of comparison
- `@op` - Comparison operator
- `@rhs` - Right-hand side of comparison
- `@stm` - Complete statement node

### Operator Negation Mapping

Hardcoded table at lines 59-66 maps operators to logical negations:
```lua
["=="] = "!=", ["!="] = "==",
["<"] = ">=", [">="] = "<",
["<="] = ">", [">"] = "<=",
```

Used in templates as `op_not` variable.

## Template Engine (lua/template.lua)

Standalone, reusable template system with Lua-based syntax.

### Template Syntax

- `{{ expression }}` - Interpolate value (printed)
- `{% lua_code %}` - Execute Lua code
- `\{` - Escape literal brace

**Limitation:** Cannot use `[[` for multi-line strings inside templates (use `[=[` instead).

### Template Environment

Templates execute in sandboxed environment (line 145-152 in init.lua):
- All Tree-sitter captures become variables (`obj`, `attr`, `lhs`, `op`, `rhs`)
- Computed variables (e.g., `op_not`)
- Falls back to `_G` via metatable (security concern - see CODE_REVIEW.md)

### API

- `M.compile(tmpl, env)` - Compile string template with environment
- `M.compile_file(name, env)` - Compile from file

## User Command

`:Myrefact [range]` - Defined in plugin/myrefact.lua

- Works on visual selection or line ranges
- No arguments
- Hardcoded to use "soften_constraint" refactoring only
- Range handling: 0-based line numbers, end is exclusive

## Key Implementation Patterns

### Async Operations

Uses `plenary.async` wrapping pattern:
```lua
local confirm = async.wrap(function(prompt, callback)
  -- async logic with vim.on_key
  -- calls callback(result) when done
end, 2) -- param_count
```

### Visual Selection with Delay

`select_range()` function (lines 92-97) uses 200ms delay before executing callback to allow visual mode to update properly.

### Indentation Preservation

Lines 159-165: Captures indentation from original statement and applies to all generated lines except the first (which reuses the original line's position).

### Index Conventions

- Tree-sitter: 0-based line numbers
- Vim API: Mix of 0-based (`bufnr`) and 1-based (line numbers in some contexts)
- Conversion happens at replacement time (line 168)

## Extending the Plugin

### Adding a New Refactoring Pattern

1. Add entry to `queries` table (line 6-50):
   ```lua
   {
     name = "pattern_name",
     q = [[tree-sitter query string]],
     sub = [[template substitution string]]
   }
   ```

2. Query auto-parsed in `do` block (lines 52-56) at module load time

3. Update command definition to support pattern selection (currently hardcoded to "soften_constraint")

4. Ensure template variables match Tree-sitter captures

### Template Variables Available

- Any `@capture` from Tree-sitter query becomes a variable
- `op_not` (computed from `op_negations` table)
- Anything in `_G` (via metatable fallback)

## Known Issues

See CODE_REVIEW.md for comprehensive analysis. Critical issues:

- **No error handling** - No `pcall`/`xpcall` anywhere
- **No dependency validation** - Assumes plenary.async and Python parser exist
- **No buffer safety checks** - No validation before modifications
- **Incomplete code** - `soften_conditional_constraint` has empty substitution template (line 49)
- **No configuration system** - All patterns and behaviors hardcoded

## Code Style Patterns

1. **Local function encapsulation** - Helper functions as `local function` within module scope
2. **Plugin guard** - `if vim.g.loaded_myrefact == 1 then return end` at top of plugin file
3. **Query parsing at load time** - Queries compiled once, stored in `q_parsed` table
4. **Reverse iteration for replacements** - Critical pattern to maintain line offsets
