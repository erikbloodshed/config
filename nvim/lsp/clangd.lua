return {
    cmd = {
        "clangd",
        "--background-index",
        "--clang-tidy",
        "--compile_args_from=lsp",
        "--completion-style=bundled",
        "--enable-config",
        "--function-arg-placeholders=0",
        "--header-insertion=never",
        "--offset-encoding=utf-16",
    },
    root_markers = { ".clangd" },
    filetypes = { "c", "cpp" },
}
