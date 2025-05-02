local api = vim.api
local fn = vim.fn

local M = {}

local signs = {
  error = { text = 'E', hl = 'DiagnosticSignError' },
  warning = { text = 'W', hl = 'DiagnosticSignWarn' },
  info = { text = 'I', hl = 'DiagnosticSignInfo' },
  hint = { text = 'H', hl = 'DiagnosticSignHint' },
}

local namespace = api.nvim_create_namespace('custom_qf')
local show_multiple_lines = false
local max_filename_length = 0
local filename_truncate_prefix = '[...]'

local function pad_right(string, pad_to)
  local new = string

  if pad_to == 0 then
    return string
  end

  for _ = fn.strwidth(string), pad_to do
    new = new .. ' '
  end

  return new
end

local function trim_path(path)
  local fname = fn.fnamemodify(path, ':p:.')
  local len = fn.strchars(fname)

  if max_filename_length > 0 and len > max_filename_length then
    fname = filename_truncate_prefix
      .. fn.strpart(fname, len - max_filename_length, max_filename_length, 1)
  end

  return fname
end

local function list_items(info)
  if info.quickfix == 1 then
    return fn.getqflist({ id = info.id, items = 1, qfbufnr = 1 })
  else
    return fn.getloclist(info.winid, { id = info.id, items = 1, qfbufnr = 1 })
  end
end

local function apply_highlights(bufnr, highlights)
  for _, hl in ipairs(highlights) do
    vim.highlight.range(
      bufnr,
      namespace,
      hl.group,
      { hl.line, hl.col },
      { hl.line, hl.end_col }
    )
  end
end

function M.format(info)
  local list = list_items(info)
  local qf_bufnr = list.qfbufnr
  local raw_items = list.items
  local lines = {}
  local pad_to = 0
  local type_mapping = {
    E = signs.error,
    W = signs.warning,
    I = signs.info,
    N = signs.hint,
  }

  local items = {}
  local show_sign = false

  -- If we're adding a new list rather than appending to an existing one, we
  -- need to clear existing highlights.
  if info.start_idx == 1 then
    api.nvim_buf_clear_namespace(qf_bufnr, namespace, 0, -1)
  end

  for i = info.start_idx, info.end_idx do
    local raw = raw_items[i]

    if raw then
      local item = {
        type = raw.type,
        text = raw.text,
        location = '',
        path_size = 0,
        line_col_size = 0,
        index = i,
      }

      if type_mapping[item.type] then
        show_sign = true
      end

      if raw.bufnr > 0 then
        item.location = trim_path(fn.bufname(raw.bufnr))
        item.path_size = #item.location
      end

      if raw.lnum and raw.lnum > 0 then
        local lnum = raw.lnum

        if raw.end_lnum and raw.end_lnum > 0 and raw.end_lnum ~= lnum then
          lnum = lnum .. '-' .. raw.end_lnum
        end

        if #item.location > 0 then
          item.location = item.location .. ' ' .. lnum
        else
          item.location = tostring(lnum)
        end

        -- Column numbers without line numbers make no sense, and may confuse
        -- the user into thinking they are actually line numbers.
        if raw.col and raw.col > 0 then
          local col = raw.col

          if raw.end_col and raw.end_col > 0 and raw.end_col ~= col then
            col = col .. '-' .. raw.end_col
          end

          item.location = item.location .. ':' .. col
        end

        item.line_col_size = #item.location - item.path_size
      end

      local size = fn.strwidth(item.location)

      if size > pad_to then
        pad_to = size
      end

      table.insert(items, item)
    end
  end

  local highlights = {}

  for _, item in ipairs(items) do
    local line_idx = item.index - 1

    -- Quickfix items only support singe-line messages, and show newlines as
    -- funny characters. In addition, many language servers (e.g.
    -- rust-analyzer) produce super noisy multi-line messages where only the
    -- first line is relevant.
    --
    -- To handle this, we only include the first line of the message in the
    -- quickfix line.
    local text = vim.split(item.text, '\n')[1]
    local location = item.location

    -- Optionally show multiple lines joined with single space
    if show_multiple_lines then
      text = fn.substitute(item.text, '\n\\s*', ' ', 'g')
    end

    text = fn.trim(text)

    if text ~= '' then
      location = pad_right(location, pad_to)
    end

    local sign_conf = type_mapping[item.type]
    local sign = ' '
    local sign_hl = nil

    if sign_conf then
      sign = sign_conf.text
      sign_hl = sign_conf.hl
    end

    local prefix = show_sign and sign .. ' ' or ''
    local line = prefix .. location .. text

    -- If a line is completely empty, Vim uses the default format, which
    -- involves inserting `|| `. To prevent this from happening we'll just
    -- insert an empty space instead.
    if line == '' then
      line = ' '
    end

    if show_sign and sign_hl then
      table.insert(
        highlights,
        { group = sign_hl, line = line_idx, col = 0, end_col = #sign }
      )
    end

    if item.path_size > 0 then
      table.insert(highlights, {
        group = 'Directory',
        line = line_idx,
        col = #prefix,
        end_col = #prefix + item.path_size,
      })
    end

    if item.line_col_size > 0 then
      local col_start = #prefix + item.path_size

      table.insert(highlights, {
        group = 'Number',
        line = line_idx,
        col = col_start,
        end_col = col_start + item.line_col_size,
      })
    end

    table.insert(lines, line)
  end

  -- Applying highlights has to be deferred, otherwise they won't apply to the
  -- lines inserted into the quickfix window.
  vim.schedule(function()
    apply_highlights(qf_bufnr, highlights)
  end)

  return lines
end

function M.setup(opts)
  opts = opts or {}

  if opts.signs then
    assert(type(opts.signs) == 'table', 'the "signs" option must be a table')
    signs = vim.tbl_deep_extend('force', signs, opts.signs)
  end

  if opts.show_multiple_lines then
    show_multiple_lines = true
  end

  if opts.max_filename_length then
    max_filename_length = opts.max_filename_length
    assert(
      type(max_filename_length) == 'number',
      'the "max_filename_length" option must be a number'
    )
  end

  if opts.filename_truncate_prefix then
    filename_truncate_prefix = opts.filename_truncate_prefix
    assert(
      type(filename_truncate_prefix) == 'string',
      'the "filename_truncate_prefix" option must be a string'
    )
  end

  vim.opt.quickfixtextfunc = "v:lua.require'custom_qf'.format"
end

return M
