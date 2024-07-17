local U = require('sf.util')
local C = require('sf.config')

local M = {}
local H = {}
local enabled = false
local cache = nil

local covered_group = "SfCovered"
local uncovered_group = "SfUncovered"
local covered_sign = "sf_covered"
local uncovered_sign = "sf_uncovered"

local show_covered = true
local show_uncovered = true


M.setup = function()
  if C.config.code_sign_highlight.covered.fg == "" then
    show_covered = false
  end

  if C.config.code_sign_highlight.uncovered.fg == "" then
    show_uncovered = false
  end

  H.highlight(covered_group, { fg = C.config.code_sign_highlight.covered.fg })
  H.highlight(uncovered_group, { fg = C.config.code_sign_highlight.uncovered.fg })

  vim.fn.sign_define(covered_sign, { text = "▎", texthl = covered_group, })
  vim.fn.sign_define(uncovered_sign, { text = "▎", texthl = uncovered_group, })
end

M.toggle = function()
  if enabled then
    vim.notify('Sign disabled.', vim.log.levels.INFO)
    H.unplace()
  else
    vim.notify('Sign enabled.', vim.log.levels.INFO)
    M.refresh_and_place()
  end
end

M.uncovered_jump_forward = function()
  local isForward = true
  H.uncovered_jump(isForward)
end

M.uncovered_jump_backward = function()
  local isForward = false
  H.uncovered_jump(isForward)
end

M.is_enabled = function()
  return enabled
end

M.refresh_and_place = function()
  H.unplace()
  local signs = H.parse_from_json_file()
  vim.fn.sign_placelist(signs)
  enabled = true
end

-- helpers

H.parse_from_json_file = function()
  local coverage

  if cache ~= nil then
    coverage = cache
  else
    local tbl = U.read_file_in_plugin_folder('test_result.json')
    if not tbl then
      return vim.notify('No data read from test_result.json. Empty or bad format?', vim.log.levels.WARN)
    end

    coverage = vim.tbl_get(tbl, "result", "coverage", "coverage")

    if coverage == nil then
      return vim.notify("Coverage element does not exist.", vim.log.levels.ERROR)
    end

    cache = coverage
  end

  local signs = {}
  for i, v in pairs(coverage) do
    local apex_name = v["name"] .. '.cls'

    if U.is_apex_loaded_in_buf(apex_name) then
      for line, value in pairs(v["lines"]) do
        local sign = {}
        if show_covered and value == 1 then
          sign.id = 0
          sign.name = covered_sign
          sign.group = covered_group
          sign.buffer = U.get_buf_num(apex_name)
          sign.lnum = line
          sign.priority = 1000
          table.insert(signs, sign)
        elseif show_uncovered and value == 0 then
          sign.id = 0
          sign.name = uncovered_sign
          sign.group = uncovered_group
          sign.buffer = U.get_buf_num(apex_name)
          sign.lnum = line
          sign.priority = 1000
          table.insert(signs, sign)
        end
      end
    end
  end
  return signs
end

H.invalidate_cache_and_try_place = function()
  cache = nil
  if M.is_enabled() or C.config.auto_display_code_sign then
    M.refresh_and_place()
  end
end

H.unplace = function()
  vim.fn.sign_unplace(covered_group)
  vim.fn.sign_unplace(uncovered_group)
  enabled = false
end

H.uncovered_jump = function(isForward)
  if not enabled then
    return
  end

  local placed = vim.fn.sign_getplaced("", { group = uncovered_group })
  local placed_signs = placed[1].signs

  if #placed == 0 or #placed_signs == 0 then
    return
  end

  local current_lnum = vim.fn.line(".")

  local hunks = H.get_hunks(placed_signs)

  if not isForward then
    hunks = H.revert(hunks)
  end

  for _, hunk in ipairs(hunks) do
    local hunk_start_lnum = hunk[1].lnum

    if (isForward and hunk_start_lnum > current_lnum) or (not isForward and hunk_start_lnum < current_lnum) then
      vim.fn.sign_jump(hunk[1].id, uncovered_group, "")
      return
    end
  end

  vim.fn.sign_jump(hunks[1][1].id, uncovered_group, "") -- loop back
end

H.get_hunks = function(placed_signs)
  local hunks = {}
  local current_hunk = { placed_signs[1] }

  for i = 2, #placed_signs do
    local sign = placed_signs[i]
    if sign.lnum == current_hunk[#current_hunk].lnum + 1 then
      table.insert(current_hunk, sign)
    else
      table.insert(hunks, current_hunk)
      current_hunk = { sign }
    end
  end
  table.insert(hunks, current_hunk)

  return hunks
end

H.highlight = function(group, color)
  local style = color.style and "gui=" .. color.style or "gui=NONE"
  local fg = color.fg and "guifg=" .. color.fg or "guifg=NONE"
  local bg = color.bg and "guibg=" .. color.bg or "guibg=NONE"
  local sp = color.sp and "guisp=" .. color.sp or ""
  local hl = "highlight default " .. group .. " " .. style .. " " .. fg .. " " .. bg .. " " .. sp
  vim.cmd(hl)
  if color.link then
    vim.cmd("highlight default link " .. group .. " " .. color.link)
  end
end

H.revert = function(hunks)
  table.sort(hunks, function(a, b)
    return a[1].lnum > b[1].lnum
  end)
  return hunks
end

return M
