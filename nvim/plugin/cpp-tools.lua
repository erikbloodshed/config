require("cpp-tools").setup({
    c = {
        compiler = "gcc",
    },

    cpp = {
        compiler = "g++",
        compile_opts = ".compile_flags",
    }
})
