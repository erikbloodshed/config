require("cpp-tools").setup({
    c = {
        compiler = "gcc-15",
        compile_opts = ".compile_flags"
    },

    cpp = {
        compiler = "g++-15",
        compile_opts = ".compile_flags",
    }
})
