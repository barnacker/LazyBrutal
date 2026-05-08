-- Tabby tab management configuration
-- Theme highlight groups (defined in colors/brutal.lua)
local theme = {
  fill = "TabLineFill",
  win = "TabLine",
  current_win_ok = "TabLineOK",
  current_win_error = "TabLineErrSel",
  other_win_error = "TabLineErr",
  current_win_warn = "TabLineWarnSel",
  other_win_warn = "TabLineWarn",
  tab = "TabLine",
  current_tab = "TabLineSel",
  tail = "TabLineSel",
  bgb = { bg = "#000000" },
}

-- Diagnostic severity constants (vim.diagnostic.severity.*)
local SEVERITY = {
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  HINT = 4,
  NONE = 5,
}

-- Diagnostic configuration: severity level -> display properties
local DIAGNOSTIC_CONFIG = {
  [SEVERITY.ERROR] = {
    suffix = " ",
    icon = "",
    hl_active = theme.current_win_error,
    hl_inactive = theme.other_win_error,
  },
  [SEVERITY.WARN] = {
    suffix = " ",
    icon = "",
    hl_active = theme.current_win_warn,
    hl_inactive = theme.other_win_warn,
  },
  [SEVERITY.INFO] = {
    suffix = " ",
    icon = "",
    hl_active = theme.current_tab,
    hl_inactive = theme.tab,
  },
  [SEVERITY.HINT] = {
    suffix = "",
    icon = "󰌵",
    hl_active = theme.current_tab,
    hl_inactive = theme.tab,
  },
  [SEVERITY.NONE] = {
    suffix = "",
    icon = "",
    hl_active = theme.current_tab,
    hl_inactive = theme.tab,
  },
}

-- Aggregates diagnostics across all windows in a tab
-- Returns diagnostic info with suffix, highlights for active/inactive states
local function tab_diagnostics(tab)
  if not tab or not tab.id then
    return DIAGNOSTIC_CONFIG[SEVERITY.NONE]
  end

  local min_severity = SEVERITY.NONE
  local wins = require("tabby.module.api").get_tab_wins(tab.id)

  for _, win_id in pairs(wins) do
    local buf_id = vim.api.nvim_win_get_buf(win_id)
    local diagnostics = vim.diagnostic.get(buf_id)

    for _, diagnostic in ipairs(diagnostics) do
      if diagnostic.severity < min_severity then
        min_severity = diagnostic.severity
      end
    end
  end

  return DIAGNOSTIC_CONFIG[min_severity] or DIAGNOSTIC_CONFIG[SEVERITY.NONE]
end

-- Checks if any buffer in the tab has unsaved modifications
local function tab_modified(tab)
  if not tab or not tab.id then
    return ""
  end

  local wins = require("tabby.module.api").get_tab_wins(tab.id)

  for _, win_id in pairs(wins) do
    local buf_id = vim.api.nvim_win_get_buf(win_id)
    if vim.bo[buf_id].modified then
      return "●"
    end
  end

  return ""
end

-- Checks if a single buffer has unsaved modifications
local function buf_modified(buf)
  return vim.bo[buf].modified and "●" or ""
end

-- Aggregates LSP diagnostics for a buffer
-- Returns diagnostic counts with formatted display string and highlights
local function lsp_diag(buf)
  if not buf then
    return {
      error = false,
      display = function()
        return ""
      end,
      hlaActive = function()
        return theme.current_win_ok
      end,
      hlInactive = function()
        return theme.win
      end,
    }
  end

  local diagnostics = vim.diagnostic.get(buf)
  local count = { 0, 0, 0, 0 }

  -- Count diagnostics by severity
  for _, diagnostic in ipairs(diagnostics) do
    local severity = diagnostic.severity
    if severity >= SEVERITY.ERROR and severity <= SEVERITY.HINT then
      count[severity] = count[severity] + 1
    end
  end

  -- Build diagnostic display string
  local diag_parts = {}
  for severity = SEVERITY.ERROR, SEVERITY.HINT do
    if count[severity] > 0 then
      local config = DIAGNOSTIC_CONFIG[severity]
      table.insert(diag_parts, string.format("%d%s", count[severity], config.icon))
    end
  end

  -- Determine highest severity for highlight selection
  local function get_active_highlight()
    if count[SEVERITY.ERROR] > 0 then
      return theme.current_win_error
    end
    if count[SEVERITY.WARN] > 0 then
      return theme.current_win_warn
    end
    return theme.current_win_ok
  end

  local function get_inactive_highlight()
    if count[SEVERITY.ERROR] > 0 then
      return theme.other_win_error
    end
    if count[SEVERITY.WARN] > 0 then
      return theme.other_win_warn
    end
    return theme.win
  end

  return {
    error = true,
    display = function()
      if #diag_parts == 0 then
        return ""
      end
      return table.concat(diag_parts, " ")
    end,
    hlaActive = get_active_highlight,
    hlInactive = get_inactive_highlight,
  }
end

-- Shortens special buffer names for display
local function buffer_name(buf)
  if not buf then
    return ""
  end
  return string.find(buf, "NvimTree") and "NvimTree" or buf
end

return {
  {
    "akinsho/bufferline.nvim",
    enabled = false,
  },
  {
    "nanozuki/tabby.nvim",
    event = { "BufReadPost", "TermOpen" },
    keys = function()
      local keys = {
        { "<leader>tn", "<cmd>$tabnew<cr>", desc = "new tab" },
        { "<leader>to", "<cmd>tabonly<cr>", desc = "close all other tabs" },
        { "<leader>tx", "<cmd>tabclose<cr>", desc = "close this tab" },
        { "<A-w>", "<cmd>tabclose<cr>", desc = "Close Tab" },
        { "-", "<cmd>Tabby pick_window<cr>", desc = "Select Window" },
        { "<M-`>", "<cmd>Tabby jump_to_tab<cr>", desc = "Jump to Tab" },
        { "<A-,>", "<cmd>tabp<cr>", desc = "Previous Tab" },
        { "<A-.>", "<cmd>tabn<cr>", desc = "Next Tab" },
        { "<C-A-,>", "<cmd>-tabmove<cr>", desc = "Move Tab Back" },
        { "<C-A-.>", "<cmd>+tabmove<cr>", desc = "Move Tab Forward" },
        { "<C-n>", "<cmd>$tabnew<cr>", desc = "New tab" },
      }

      -- Generate Alt+1-9 for quick tab switching
      for i = 1, 9 do
        table.insert(keys, { "<A-" .. i .. ">", "<cmd>tabn " .. i .. "<cr>", desc = "Go to tab " .. i })
      end

      return keys
    end,
    config = function()
      require("tabby").setup({
        line = function(line)
          return {
            {
              { "󰚌 ", hl = theme.fill },
            },
            line.tabs().foreach(function(tab)
              local diag = tab_diagnostics(tab)
              local hl = (tab.is_current() and diag.hl_active) or diag.hl_inactive
              return {
                line.sep("", theme.bgb, hl),
                not tab.is_current() and (tab.in_jump_mode() and tab.jump_key() or tab.number()) or "",
                tab_modified(tab),
                vim.fs.basename(tab.name()) .. diag.suffix,
                tab.close_btn(""),
                line.sep("", theme.bgb, hl),
                hl = hl,
                margin = " ",
              }
            end),
            line.truncate_point(),
            line.sep("", theme.bgb, theme.tail),
            line.spacer(),

            line.sep("", theme.bgb, theme.tail),
            line.wins_in_tab(line.api.get_current_tab()).foreach(function(win)
              local diag = lsp_diag(win.buf().id)
              local hl = win.is_current() and diag.hlaActive() or diag.hlInactive()
              if win.buf().type() == "nofile" then
                return {}
              else
                return {
                  line.sep("", theme.bgb, hl),
                  buf_modified(win.buf().id),
                  buffer_name(win.buf_name()),
                  diag.display(),
                  line.sep("", theme.bgb, hl),
                  hl = hl,
                  margin = " ",
                }
              end
            end),
            {
              { "  ", hl = theme.fill },
            },
            hl = theme.fill,
          }
        end,
        option = {
          tab_name = {
            name_fallback = function(tabid)
              local api = require("tabby.module.api")
              local tab_name = require("tabby.feature.tab_name")
              local wins = api.get_tab_wins(tabid)
              local cur_win = api.get_tab_current_win(tabid)
              local buf_name = require("tabby.feature.buf_name").get(cur_win)
              local name = ""
              if api.is_float_win(cur_win) then
                name = "[Floating]"
              elseif buf_name == "dbui" then
                name = "DadBod"
                tab_name.set(tabid, name)
                return ""
              else
                name = buf_name
              end
              if #wins > 1 then
                name = string.format("%s[%d+]", name, #wins - 1)
              end
              return name
            end,
          },
          buf_name = {
            mode = "shorten",
          },
        },
      })
    end,
  },
}
