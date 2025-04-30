require("cpp-tools").setup({
    c = {
        compiler = "gcc",
    },

    cpp = {
        compiler = "g++-15",
        compile_opts = ".compile_flags",
    }
})
