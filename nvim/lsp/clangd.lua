return {
    cmd = {
        "clangd",
        "--background-index",
        "--clang-tidy",
        "--completion-style=bundled",
        "--function-arg-placeholders=0",
        "--header-insertion=never",
        "--offset-encoding=utf-16",
    },
    root_markers = { ".clangd" },
    filetypes = { "c", "cpp" },
}
