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
      -- local function to truncate a string at a given length and add a suffix ellipsis to it
      local function truncate(str, len)
        if #str > len then
          return str:sub(1, len) .. "…"
        end
        return str
      end

      local conditions = require("heirline.conditions")
      local utils = require("heirline.utils")
      local mode_hl = function(self)
        local mode = vim.fn.mode(1):sub(1, 1) -- get only the first mode character
        local mode_colors = {
          n = "Session",
          i = "InsertMode",
          v = "StatusLineNC",
          V = "StatusLineNC",
        }

        return mode_colors[mode] or "StatusLineNC"
      end

      local mode_rev_hl = function(self)
        local mode = vim.fn.mode(1):sub(1, 1) -- get only the first mode character
        local mode_colors = {
          n = "Title",
          i = "DapBreakpointIcon",
          v = "SizeCap",
          V = "SizeCap",
        }

        return mode_colors[mode] or "SizeCap"
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
          mode_names = { -- change the strings if you like it vvvvverbose!
            n = "NORMAL",
            no = "Ƞ?",
            nov = "Ƞ?",
            noV = "Ƞ?",
            ["no\22"] = "Ƞ?",
            niI = "Ƞi",
            niR = "Ƞr",
            niV = "Ƞv",
            nt = "Ƞt",
            v = "VISUAL",
            vs = "󰩬 s",
            V = "LINE VISUAL",
            Vs = "REGION VISUAL",
            ["\22"] = " 󰩬 ",
            ["\22s"] = " ^󰩬 ",
            s = "S",
            S = "S_",
            ["\19"] = "^S",
            i = "INSERT",
            ic = "Ǐc",
            ix = "Ǐx",
            R = "R",
            Rc = "Rc",
            Rx = "Rx",
            Rv = "Rv",
            Rvc = "Rv",
            Rvx = "Rv",
            c = "FIND",
            cv = "Ex",
            r = "...",
            rm = "M",
            ["r?"] = "?",
            ["!"] = "!",
            t = "T",
          },
        },
        -- We can now access the value of mode() that, by now, would have been
        -- computed by `init()` and use it to index our strings dictionary.
        -- note how `static` fields become just regular attributes once the
        -- component is instantiated.
        -- To be extra meticulous, we can also add some vim statusline syntax to
        -- control the padding and make sure our string is always at least 2
        -- characters long. Plus a nice Icon.
        provider = function(self)
          return "" .. self.mode_names[self.mode] .. ""
        end,
        -- Same goes for the highlight. Now the foreground will change according to the current mode.
        hl = mode_hl,
        -- Re-evaluate the component only on ModeChanged event!
        -- Also allows the statusline to be re-evaluated when entering operator-pending mode
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
          return " " .. (vim.bo.fenc or vim.o.enc) .. " " -- :h 'enc'
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
          -- stackoverflow, compute human readable file size
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
        -- we could add a condition to check that buftype == 'terminal'
        -- or we could do that later (see #conditional-statuslines below)
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

      -- local function that receives a branche name and that returns a symbol based on the word devlop, master, feature or hotfix
      local function branch_symbol(branch)
        local symbols = {
          develo = " ",
          master = "󰟐 ",
          featur = " ",
          hotfix = "󰶯 ",
        }
        return symbols[branch] or " "
      end

      -- local function that revome any text with the slash and return what was after if there is any
      local function remove_prefix(text)
        return text:match(".*/(.*)") or text
      end

      local Git = {
        condition = conditions.is_git_repo,

        init = function(self)
          ---@diagnostic disable-next-line: undefined-field
          self.status_dict = vim.b.gitsigns_status_dict
          self.has_changes = self.status_dict.added ~= 0
            or self.status_dict.removed ~= 0
            or self.status_dict.changed ~= 0
        end,

        hl = "StatusLineNC",

        { -- git branch name
          provider = function(self)
            return ""
              .. branch_symbol(self.status_dict.head:sub(1, 6))
              .. truncate(remove_prefix(self.status_dict.head), 30)
          end,
          hl = { bold = true },
        },
        -- You could handle delimiters, icons and counts similar to Diagnostics
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

      -- We're getting minimalists here!
      local Ruler = {
        -- %l = current line number
        -- %L = number of lines in the buffer
        -- %c = column number
        -- %P = percentage through file of displayed window
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

      -- local function to shorten the lsp server names to its corresponting icons
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
          ---@diagnostic disable-next-line: unused-local
          for i, server in pairs(vim.lsp.get_active_clients({ bufnr = 0 })) do
            table.insert(names, shorten_name(server.name))
          end
          return table.concat(names, " ") .. " "
        end,
      }

      local Session = {
        hl = mode_hl,
        flexible = 1,
        { provider = vim.fn.fnamemodify(vim.fn.getcwd(), ":~") },
        { provider = vim.fn.pathshorten(vim.fn.fnamemodify(vim.fn.getcwd(), ":~")) },
        { provider = vim.fn.fnamemodify(vim.fn.getcwd(), ":t") },
      }

      local Align = { provider = "%=" }
      local Space = { provider = " " }
      local StylishSpace = { provider = "" }
      local Start = { provider = "" }
      local End = { provider = "" }
      local EncStart = { provider = "", hl = "Encoding" }
      local EncEnd = { provider = "", hl = "Encoding" }
      local LFStart = { provider = "", hl = "LineFeed" }
      local LFEnd = { provider = "", hl = "LineFeed" }
      local RulerStart = { provider = "", hl = "Ruler" }
      local RulerEnd = { provider = "", hl = "Ruler" }
      local SizeStart = { provider = "", hl = "Size" }
      local flexSession = {
        {
          hl = mode_rev_hl,
          flexible = 1,
          { provider = string.rep("", 5) },
          { provider = string.rep("", 4) },
          { provider = string.rep("", 3) },
          { provider = string.rep("", 2) },
          { provider = string.rep("", 1) },
          { provider = "" },
        },
        {
          hl = mode_hl,
          End,
          Session,
          Start,
        },
        {
          hl = mode_rev_hl,
          flexible = 1,
          { provider = string.rep("", 5) },
          { provider = string.rep("", 4) },
          { provider = string.rep("", 3) },
          { provider = string.rep("", 2) },
          { provider = string.rep("", 1) },
          { provider = "" },
        },
      }

      -- ViMode = utils.surround({ "", " " }, "black", { ViMode })

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
            MacroRec,
            EncStart,
            FileEncoding,
            EncEnd,
            LFStart,
            FileFormat,
            LFEnd,
            RulerStart,
            Ruler,
            RulerEnd,
            SizeStart,
            FileSize,
          },
          {
            MacroRec,
            EncStart,
            FileEncoding,
            EncEnd,
            RulerStart,
            Ruler,
            RulerEnd,
            SizeStart,
            FileSize,
          },
          {
            MacroRec,
            RulerStart,
            Ruler,
            RulerEnd,
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

        -- Quickly add a condition to the ViMode to only show it when buffer is active!
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

        -- the first statusline with no condition, or which condition returns true is used.
        -- think of it as a switch case with breaks to stop fallthrough.
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
