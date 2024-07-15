local U = require('sf.util')
local C = require('sf.config')

local M = {}
local enabled = false
local cache = nil
local sign_group = "SfUncovered"

local highlight = function(group, color)
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

M.setup = function()
  highlight(sign_group, { fg = "#F07178" })
  vim.fn.sign_define("sf_uncovered", { text = "▎", texthl = "SfUncovered", })
  -- vim.fn.sign_placelist({
  --   {
  --     id = 0,
  --     group = "",
  --     name = "sf_uncovered",
  --     buffer = vim.fn.bufname("%"),
  --     lnum = 2,
  --     priority = 10
  --   },
  --   {
  --     id = 0,
  --     group = "",
  --     name = "sf_uncovered",
  --     buffer = vim.fn.bufname("%"),
  --     lnum = 1,
  --     priority = 10
  --   }
  -- })
end

M.parse_from_json_file = function()
  M.setup()

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
        if value == 0 then
          local sign = {}

          sign.id = 0
          sign.name = "sf_uncovered"
          sign.buffer = U.get_buf_num(apex_name)
          sign.lnum = line
          sign.group = "SfUncovered"
          sign.priority = 1000

          table.insert(signs, sign)
        end
      end
    end
  end
  return signs
end

M.invalidate_cache_and_try_place = function()
  cache = nil
  if M.is_enabled() or C.config.auto_display_sign then
    M.refresh_and_place()
  end
end

M.refresh_and_place = function()
  M.unplace()
  local signs = M.parse_from_json_file()
  vim.fn.sign_placelist(signs)
  enabled = true
end

M.unplace = function()
  vim.fn.sign_unplace(sign_group)
  enabled = false
end

M.is_enabled = function()
  return enabled
end

M.toggle = function()
  if enabled then
    vim.notify('Sign disabled.', vim.log.levels.INFO)
    M.unplace()
  else
    vim.notify('Sign enabled.', vim.log.levels.INFO)
    M.refresh_and_place()
  end
end

--- Jumps to a sign of the given type in the given direction.
--- @param sign_type? "covered"|"uncovered" Defaults to "covered"
--- @param direction? -1|1 Defaults to 1 (forward)
M.jump = function(sign_type, direction)
  if not enabled or cached_signs == nil then
    return
  end
  local placed = vim.fn.sign_getplaced("", { group = config.opts.sign_group })
  if #placed == 0 then
    return
  end
  local current_lnum = vim.fn.line(".")
  local sign_name = M.name("covered")
  if sign_type ~= nil then
    sign_name = M.name(sign_type)
  end
  direction = direction or 1

  local placed_signs = placed[1].signs
  if direction < 0 then
    table.sort(placed_signs, function(a, b)
      return a.lnum > b.lnum
    end)
  end

  for _, sign in ipairs(placed_signs) do
    if direction > 0 and sign.lnum > current_lnum and sign_name == sign.name then
      vim.fn.sign_jump(sign.id, config.opts.sign_group, "")
      return
    elseif direction < 0 and sign.lnum < current_lnum and sign_name == sign.name then
      vim.fn.sign_jump(sign.id, config.opts.sign_group, "")
      return
    end
  end
end

--- Returns a new covered sign in the format used by sign_placelist.
--- @param buffer string|integer buffer name or id
--- @param lnum integer line number
--- @return SignPlace
M.new_covered = function(buffer, lnum)
  return {
    buffer = buffer,
    group = config.opts.sign_group,
    lnum = lnum,
    name = M.name("covered"),
    priority = config.opts.signs.covered.priority or default_priority,
  }
end

--- Returns a new uncovered sign in the format used by sign_placelist.
--- @param buffer string|integer buffer name or id
--- @param lnum integer line number
--- @return SignPlace
M.new_uncovered = function(buffer, lnum)
  return {
    buffer = buffer,
    group = config.opts.sign_group,
    lnum = lnum,
    name = M.name("uncovered"),
    priority = config.opts.signs.uncovered.priority or default_priority,
  }
end

return M
