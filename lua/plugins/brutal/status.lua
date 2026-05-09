return {
  {
    "nvim-lualine/lualine.nvim",
    enabled = false,
  },
  {
    "rebelot/heirline.nvim",
    event = { "BufReadPost", "TermOpen" },

    dependencies = {
      "lewis6991/gitsigns.nvim",
    },
    config = function()
      local function truncate(str, len)
        if vim.fn.strchars(str) > len then
          return vim.fn.strcharpart(str, 0, len) .. "…"
        end
        return str
      end

      local conditions = require("heirline.conditions")
      local utils = require("heirline.utils")
      local mode_highlights = {
        n = { hl = "Session", rev_hl = "Title" },
        i = { hl = "InsertMode", rev_hl = "DapBreakpointIcon" },
        v = { hl = "StatusLineNC", rev_hl = "SizeCap" },
        V = { hl = "StatusLineNC", rev_hl = "SizeCap" },
      }

      local function mode_highlight(kind, fallback)
        local mode = vim.fn.mode(1):sub(1, 1) -- get only the first mode character
        local highlights = mode_highlights[mode]
        return (highlights and highlights[kind]) or fallback
      end

      local mode_hl = function()
        return mode_highlight("hl", "StatusLineNC")
      end

      local mode_rev_hl = function()
        return mode_highlight("rev_hl", "SizeCap")
      end

      local ViMode = {
        -- get vim current mode, this information will be required by the provider
        -- and the highlight functions, so we compute it only once per component
        -- evaluation and store it as a component attribute
        init = function(self)
          self.mode = vim.fn.mode(1) -- :h mode()
        end,
        -- Now we define some dictionaries to map the output of mode() to the
        -- corresponding string and color. We can put these into `static` to compute
        -- them at initialisation time.
        static = {
          mode_names = {
            n = "NORMAL",
            no = "OPERATOR PENDING",
            nov = "OPERATOR PENDING CHAR",
            noV = "OPERATOR PENDING LINE",
            ["no\22"] = "OPERATOR PENDING BLOCK",
            niI = "NORMAL FROM INSERT",
            niR = "NORMAL FROM REPLACE",
            niV = "NORMAL FROM VIRTUAL REPLACE",
            nt = "TERMINAL NORMAL",
            ntT = "TERMINAL NORMAL ONCE",

            v = "VISUAL CHAR",
            vs = "VISUAL CHAR FROM SELECT",
            V = "VISUAL LINE",
            Vs = "VISUAL LINE FROM SELECT",
            ["\22"] = "VISUAL BLOCK",
            ["\22s"] = "VISUAL BLOCK FROM SELECT",

            s = "SELECT CHAR",
            S = "SELECT LINE",
            ["\19"] = "SELECT BLOCK",

            i = "INSERT",
            ic = "INSERT COMPLETION",
            ix = "INSERT CTRL-X COMPLETION",

            R = "REPLACE",
            Rc = "REPLACE COMPLETION",
            Rx = "REPLACE CTRL-X COMPLETION",
            Rv = "VIRTUAL REPLACE",
            Rvc = "VIRTUAL REPLACE COMPLETION",
            Rvx = "VIRTUAL REPLACE CTRL-X COMPLETION",

            c = "COMMAND LINE",
            cr = "COMMAND LINE OVERSTRIKE",
            cv = "EX MODE",
            cvr = "EX MODE OVERSTRIKE",

            r = "HIT ENTER PROMPT",
            rm = "MORE PROMPT",
            ["r?"] = "CONFIRM PROMPT",
            ["!"] = "EXTERNAL COMMAND",
            t = "TERMINAL",
          },
        },
        provider = function(self)
          return (self.mode_names[self.mode] or self.mode or "?") .. ""
        end,
        hl = mode_hl,
        update = {
          "ModeChanged",
          pattern = "*:*",
          callback = vim.schedule_wrap(function()
            vim.cmd("redrawstatus")
          end),
        },
      }

      local FileType = {
        provider = function()
          return string.upper(vim.bo.filetype)
        end,
      }

      local FileEncoding = {
        provider = function()
          local enc = vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding
          return " " .. enc .. " " -- :h 'enc'
        end,
        hl = "Encoding",
      }

      local FileFormat = {
        provider = function()
          return " " .. vim.bo.fileformat .. " "
        end,
        hl = "LineFeed",
      }

      local FileSize = {
        provider = function()
          local suffix = { "b ", "k ", "M ", "G ", "T ", "P ", "E " }
          local fsize = vim.fn.getfsize(vim.api.nvim_buf_get_name(0))
          fsize = (fsize < 0 and 0) or fsize
          if fsize < 1024 then
            return fsize .. suffix[1]
          end
          ---@diagnostic disable-next-line: param-type-mismatch
          local i = math.floor((math.log(fsize) / math.log(1024)))
          return (string.format("%s %.2f%s", " ", fsize / math.pow(1024, i), suffix[i + 1]))
        end,
        hl = "Size",
      }

      local TerminalName = {
        provider = function()
          local tname, _ = vim.api.nvim_buf_get_name(0):gsub(".*:", "")
          return " " .. tname
        end,
      }

      local HelpFileName = {
        condition = function()
          return vim.bo.filetype == "help"
        end,
        provider = function()
          local filename = vim.api.nvim_buf_get_name(0)
          return vim.fn.fnamemodify(filename, ":t")
        end,
      }

      local function branch_symbol(branch)
        local symbols = {
          develo = " ",
          master = "󰟐 ",
          featur = " ",
          hotfix = "󰶯 ",
        }
        return symbols[branch] or " "
      end

      local function branch_label(text)
        return text:match(".*/(.*)") or text
      end

      local Git = {
        condition = conditions.is_git_repo,

        init = function(self)
          ---@diagnostic disable-next-line: undefined-field
          self.status_dict = vim.b.gitsigns_status_dict or {}
          self.has_changes = (self.status_dict.added or 0) ~= 0
            or (self.status_dict.removed or 0) ~= 0
            or (self.status_dict.changed or 0) ~= 0
        end,

        hl = "StatusLineNC",

        { -- git branch name
          provider = function(self)
            local head = self.status_dict.head or ""
            return ""
              .. branch_symbol(head:sub(1, 6))
              .. truncate(branch_label(head), 30)
          end,
          hl = { bold = true },
        },
        {
          condition = function(self)
            return self.has_changes
          end,
          provider = "(",
        },
        {
          provider = function(self)
            local count = self.status_dict.added or 0
            return count > 0 and ("+" .. count)
          end,
          hl = "DiffAdd",
        },
        {
          provider = function(self)
            local count = self.status_dict.removed or 0
            return count > 0 and ("-" .. count)
          end,
          hl = "DiffDelete",
        },
        {
          provider = function(self)
            local count = self.status_dict.changed or 0
            return count > 0 and ("~" .. count)
          end,
          hl = "diffChanged",
        },
        {
          condition = function(self)
            return self.has_changes
          end,
          provider = ")",
        },
        {
          provider = "",
        },
      }

      local Ruler = {
        provider = " %l:%c %P ",
        hl = "Ruler",
      }

      local MacroRec = {
        condition = function()
          return vim.fn.reg_recording() ~= "" and vim.o.cmdheight == 0
        end,
        provider = " ",
        utils.surround({ "[", "]" }, nil, {
          provider = function()
            return vim.fn.reg_recording()
          end,
        }),
        update = {
          "RecordingEnter",
          "RecordingLeave",
        },
      }

      local function shorten_name(name)
        local icon = {
          volar = "",
          eslint = "󰱺",
          copilot = "",
          vtsls = "",
          emmet_language_server = "󰅒",
          lua_ls = "",
          nil_ls = "",
          clangd = "󰙱",
          marksman = "",
          cssls = "",
        }
        return icon[name] or name
      end

      local LSPActive = {
        condition = conditions.lsp_attached,
        update = { "LspAttach", "LspDetach" },
        hl = "Ruler",
        provider = function()
          local names = {}
          local clients = vim.lsp.get_clients or vim.lsp.get_active_clients
          ---@diagnostic disable-next-line: unused-local
          for i, server in pairs(clients({ bufnr = 0 })) do
            table.insert(names, shorten_name(server.name))
          end
          return table.concat(names, " ") .. " "
        end,
      }

      local Session = {
        hl = mode_hl,
        update = { "DirChanged" },
        flexible = 1,
        {
          provider = function()
            return vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
          end,
        },
        {
          provider = function()
            return vim.fn.pathshorten(vim.fn.fnamemodify(vim.fn.getcwd(), ":~"))
          end,
        },
        {
          provider = function()
            return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
          end,
        },
      }

      local Align = { provider = "%=" }
      local Space = { provider = " " }
      local StylishSpace = { provider = "" }
      local function segment(provider, hl)
        return { provider = provider, hl = hl }
      end

      local Start = segment("")
      local End = segment("")
      local EncStart = segment("", "Encoding")
      local EncEnd = segment("", "Encoding")
      local LFStart = segment("", "LineFeed")
      local LFEnd = segment("", "LineFeed")
      local RulerStart = segment("", "Ruler")
      local RulerEnd = segment("", "Ruler")
      local SizeStart = segment("", "Size")

      local function session_spacer()
        return {
          hl = mode_rev_hl,
          flexible = 1,
          { provider = string.rep("", 5) },
          { provider = string.rep("", 4) },
          { provider = string.rep("", 3) },
          { provider = string.rep("", 2) },
          { provider = string.rep("", 1) },
          { provider = "" },
        }
      end

      local flexSession = {
        session_spacer(),
        {
          hl = mode_hl,
          End,
          Session,
          Start,
        },
        session_spacer(),
      }

      local DefaultStatusline = {
        {
          flexible = 20,
          {
            ViMode,
            Git,
            RulerStart,
            LSPActive,
            RulerEnd,
          },
          {
            ViMode,
            Git,
          },
          {
            ViMode,
          },
        },
        Align,
        flexSession,
        Align,
        {
          flexible = 10,
          {
            RulerStart,
            Ruler,
            RulerEnd,
            MacroRec,
            EncStart,
            FileEncoding,
            EncEnd,
            LFStart,
            FileFormat,
            LFEnd,
            SizeStart,
            FileSize,
          },
          {
            RulerStart,
            Ruler,
            RulerEnd,
            MacroRec,
            EncStart,
            FileEncoding,
            EncEnd,
            SizeStart,
            FileSize,
          },
          {
            RulerStart,
            Ruler,
            RulerEnd,
            MacroRec,
            SizeStart,
            FileSize,
          },
          {
            MacroRec,
            RulerStart,
            Ruler,
          },
        },
      }

      local InactiveStatusline = {
        condition = conditions.is_not_active,
        provider = "",
      }

      local SpecialStatusline = {
        condition = function()
          return conditions.buffer_matches({
            buftype = { "nofile", "prompt", "help", "quickfix" },
            filetype = { "^git.*", "fugitive" },
          })
        end,

        FileType,
        Space,
        HelpFileName,
        Align,
      }

      local TerminalStatusline = {

        condition = function()
          return conditions.buffer_matches({ buftype = { "terminal" } })
        end,

        hl = "Error",

        { condition = conditions.is_active, ViMode, StylishSpace },
        FileType,
        Space,
        TerminalName,
        Align,
      }

      local StatusLines = {

        hl = function()
          if conditions.is_active() then
            return "StatusLine"
          else
            return "StatusLineNC"
          end
        end,

        fallthrough = false,

        SpecialStatusline,
        TerminalStatusline,
        InactiveStatusline,
        DefaultStatusline,
      }

      require("heirline").setup({
        statusline = StatusLines,
      })
    end,
  },
}
