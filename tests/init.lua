local basepath = vim.fn.stdpath("data") .. '/' .. "lazy"

vim.opt.rtp:prepend(basepath .. '/nvim-treesitter')

require("nvim-treesitter").setup()
