local luasnip = require("luasnip")
local snippet = luasnip.snippet
local insert = luasnip.insert_node
local format = require("luasnip.extras.fmt").fmt

return {
    snippet(
        "main",
        format( [[
        int main()
        {{
            {}
            return 0;
        }}
        ]], {insert(0)})
    ),
}
