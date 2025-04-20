vim.ui.select = function(items, opts, on_choice)
  opts = opts or {}

  local formatted_items = {}
  for idx, item in ipairs(items) do
    local text = (opts.format_item and opts.format_item(item)) or tostring(item)
    table.insert(formatted_items, {
      text = text,
      item = item,
      idx = idx,
    })
  end

  local completed = false

  require("custom_picker").pick({
    title = opts.prompt or "Select",
    items = formatted_items,
    actions = {
      confirm = function(picker, picked)
        if completed then return end
        completed = true
        picker:close()
        vim.schedule(function()
          on_choice(picked.item, picked.idx)
        end)
      end,
    },
    on_close = function()
      if completed then return end
      completed = true
      vim.schedule(function()
        on_choice(nil, nil)
      end)
    end,
  })
end
