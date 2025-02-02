local luasnip = require("luasnip")
local snippet = luasnip.snippet
local insert = luasnip.insert_node
local format = require("luasnip.extras.fmt").fmt

return {
    snippet({ trig = "main", desc = "main function" },
        format([[
        #include <stdio.h>
        #include <stdlib.h>
        {}
        int main(void)
        {{
            {}
            return EXIT_SUCCESS;
        }}
        ]], { insert(1), insert(0) })
    )
}
