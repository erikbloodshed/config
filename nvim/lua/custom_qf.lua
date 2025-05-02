local api = vim.api
local fn = vim.fn

local signs = vim.g.custom_qf_signs or {
    error = { text = 'E', hl = 'DiagnosticSignError' },
    warning = { text = 'W', hl = 'DiagnosticSignWarn' },
    info = { text = 'I', hl = 'DiagnosticSignInfo' },
    hint = { text = 'H', hl = 'DiagnosticSignHint' },
}

local show_multiple_lines = vim.g.custom_qf_show_multiple_lines or false
local max_filename_length = vim.g.custom_qf_max_filename_length or 0
local filename_truncate_prefix = vim.g.custom_qf_filename_truncate_prefix or '[...]'

local namespace = api.nvim_create_namespace('custom_qf')

local function pad_right(str, pad_to)
    if pad_to == 0 then return str end
    local new = str
    for _ = fn.strwidth(str), pad_to do new = new .. ' ' end
    return new
end

local function trim_path(path)
    local fname = fn.fnamemodify(path, ':p:.')
    local len = fn.strchars(fname)
    if max_filename_length > 0 and len > max_filename_length then
        fname = filename_truncate_prefix .. fn.strpart(fname, len - max_filename_length, max_filename_length, 1)
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
        vim.highlight.range(bufnr, namespace, hl.group, { hl.line, hl.col }, { hl.line, hl.end_col })
    end
end

function _G.custom_qf_format(info)
    local list = list_items(info)
    local qf_bufnr, raw_items = list.qfbufnr, list.items
    local lines, highlights = {}, {}
    local pad_to, show_sign = 0, false

    local type_mapping = {
        E = signs.error,
        W = signs.warning,
        I = signs.info,
        N = signs.hint,
    }

    if info.start_idx == 1 then
        api.nvim_buf_clear_namespace(qf_bufnr, namespace, 0, -1)
    end

    local items = {}
    for i = info.start_idx, info.end_idx do
        local raw = raw_items[i]
        if raw then
            local item = {
                type = raw.type, text = raw.text, index = i,
                location = '', path_size = 0, line_col_size = 0,
            }

            if type_mapping[item.type] then show_sign = true end
            if raw.bufnr > 0 then
                item.location = trim_path(fn.bufname(raw.bufnr))
                item.path_size = #item.location
            end

            if raw.lnum and raw.lnum > 0 then
                local lnum = raw.lnum
                if raw.end_lnum and raw.end_lnum > 0 and raw.end_lnum ~= lnum then
                    lnum = lnum .. '-' .. raw.end_lnum
                end
                item.location = (#item.location > 0 and item.location .. ' ' or '') .. lnum
                if raw.col and raw.col > 0 then
                    local col = raw.col
                    if raw.end_col and raw.end_col > 0 and raw.end_col ~= col then
                        col = col .. '-' .. raw.end_col
                    end
                    item.location = item.location .. ':' .. col
                end
                item.line_col_size = #item.location - item.path_size
            end

            pad_to = math.max(pad_to, fn.strwidth(item.location))
            table.insert(items, item)
        end
    end

    for _, item in ipairs(items) do
        local line_idx = item.index - 1
        local text = fn.trim((show_multiple_lines and fn.substitute(item.text, '\n\\s*', ' ', 'g')) or vim.split(item.text, '\n')[1])
        local location = text ~= '' and pad_right(item.location, pad_to) or item.location
        local sign_conf = type_mapping[item.type]
        local sign = (show_sign and sign_conf and sign_conf.text) or ' '
        local sign_hl = sign_conf and sign_conf.hl
        local prefix = show_sign and sign .. ' ' or ''
        local line = prefix .. location .. text
        if line == '' then line = ' ' end

        if show_sign and sign_hl then
            table.insert(highlights, { group = sign_hl, line = line_idx, col = 0, end_col = #sign })
            if text ~= '' then
                table.insert(highlights, {
                    group = sign_hl,
                    line = line_idx,
                    col = #prefix + #location,
                    end_col = #line,
                })
            end
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
            table.insert(highlights, {
                group = 'Number',
                line = line_idx,
                col = #prefix + item.path_size,
                end_col = #prefix + item.path_size + item.line_col_size,
            })
        end

        table.insert(lines, line)
    end

    vim.schedule(function()
        apply_highlights(qf_bufnr, highlights)
    end)

    return lines
end

vim.opt.quickfixtextfunc = "v:lua.custom_qf_format"
