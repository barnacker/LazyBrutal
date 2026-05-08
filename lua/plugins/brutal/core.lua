-- At default, neovim only display tabline when there are at least two tab pages. If you want always display tabline:
vim.o.showtabline = 2

-- Helper to get sessions list
local function get_sessions()
  local ok, possession = pcall(require, "possession")
  if not ok or not possession then
    return {}
  end

  local list_ok, sessions = pcall(possession.list)
  if not list_ok or not sessions or type(sessions) ~= "table" then
    return {}
  end

  local session_items = {}

  -- Sort by last modified
  pcall(function()
    table.sort(sessions, function(a, b)
      return (a.mtime or 0) > (b.mtime or 0)
    end)
  end)

  -- Take top 5 most recent sessions
  for i, session in ipairs(sessions) do
    if i > 5 then
      break
    end

    if session and session.name then
      local icon = " "
      local key = tostring(i)
      local desc = session.name

      -- Check if this is the current session
      if possession.session_name and possession.session_name == session.name then
        icon = " "
        desc = desc .. " (current)"
      end

      table.insert(session_items, {
        icon = icon,
        key = key,
        desc = desc,
        action = function()
          vim.cmd("PossessionLoad " .. session.name)
        end,
      })
    end
  end

  return session_items
end

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "brutal",
    },
  },
  {
    "jedrzejboczar/possession.nvim",
    event = "VimEnter", -- Load on startup so dashboard can use commands
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    keys = {
      { "<leader>ps", "<cmd>Telescope possession list<cr>", desc = "Session List" },
      { "<leader>pl", "<cmd>PossessionLoad<cr>", desc = "Load Session" },
      { "<leader>pd", "<cmd>PossessionDelete<cr>", desc = "Delete Session" },
      { "<leader>pc", "<cmd>PossessionClose<cr>", desc = "Close Session" },
      { "<leader>pn", "<cmd>PossessionSave<cr>", desc = "Save New Session" },
      { "<leader>pr", "<cmd>PossessionRename<cr>", desc = "Rename Session" },
      { "<leader>pu", "<cmd>PossessionSave<cr>", desc = "Update Session" },
    },
    config = function()
      require("possession").setup({
        autosave = {
          current = true, -- save current session on VimExit
        },
        plugins = {
          delete_hidden_buffers = false,
          nvim_tree = true,
          neo_tree = true,
          tabby = true,
          dap = true,
        },
      })

      -- Load telescope extension with error handling
      local ok, telescope = pcall(require, "telescope")
      if ok then
        pcall(telescope.load_extension, "possession")
      end
    end,
  },
  {
    "snacks.nvim",
    priority = 100, -- Load before LazyVim defaults
    opts = function(_, opts)
      -- Clear any existing dashboard config completely
      opts.dashboard = nil

      -- Build fresh dashboard config
      opts.dashboard = {
        enabled = true,
        width = 60,
        row = nil,
        col = nil,
        pane_gap = 4,
        autokeys = "1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
        preset = {
          pick = function(cmd, picker_opts)
            return LazyVim.pick(cmd, picker_opts)()
          end,
          header = [[
     ...     ..                       .    .         s                      ..
  .=*8888x <"?88h.                   888> 888       :8                x .d88"
 X>  '8888H> '8888      .u    .      `8'  `8'      .88                 5888R
'88h. `8888   8888    .d88B :@8c     :.    .      :888ooo       u      '888R
'8888 '8888    "88>  ="8888f8888r  .@88k  z8Nu  -*8888888    us888u.    888R
 `888 '8888.xH888x.    4888>'88"  ~`8888 ^888E    8888    .@88 "8888"   888R
   X" :88*~  `*8888>   4888> '      8888  888E    8888    9888  9888    888R
 ~"   !"`      "888>   4888>        9888  888E    8888    9888  9888    888R
  .H8888h.      ?88   .d888L .+     9888  888E   .8888Lu= 9888  9888    888R
 :"^"88888h.    '!    ^"8888*"      @888 .888&   ^%888*   9888  9888   .888B .
 ^    "88888hx.+"        "Y"       "8888% 8888"    'Y"    "888*""888"  ^*888%
        ^"**""                       Y"   'YP              ^Y"   ^Y'     "%
 ]],
          -- stylua: ignore
          keys = (function()
            local main_keys = {
              -- Sessions Section
              { icon = " ", key = "s", desc = "Browse All Sessions", action = ":Telescope possession list" },
              { icon = " ", key = "S", desc = "Save New Session", action = ":PossessionSave" },
              { action = false }, -- separator

              -- File Operations
              { icon = " ", key = "f", desc = "Find File", action = function() LazyVim.pick("files")() end },
              { icon = " ", key = "w", desc = "Find Word", action = function() LazyVim.pick("live_grep")() end },
              { icon = " ", key = "r", desc = "Recent Files", action = function() LazyVim.pick("oldfiles")() end },
              { icon = " ", key = "e", desc = "New File", action = ":ene | startinsert" },
              { action = false }, -- separator

              -- Git & Projects
              { icon = " ", key = "g", desc = "Git Status (Neogit)", action = ":Neogit" },
              { icon = " ", key = "b", desc = "Git Branches", action = ":Telescope git_branches" },
              { action = false }, -- separator

              -- Config & Management
              { icon = " ", key = "c", desc = "Config Files", action = function() LazyVim.pick("files", { cwd = vim.fn.stdpath("config") })() end },
              { icon = " ", key = "d", desc = "Debug UI", action = ":lua require('dapui').toggle()" },
              { icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
              { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
              { icon = " ", key = "h", desc = "Health Check", action = ":checkhealth" },
            }

            -- Add recent sessions dynamically
            local sessions = get_sessions()
            if #sessions > 0 then
              table.insert(main_keys, { action = false }) -- separator
              for _, session in ipairs(sessions) do
                table.insert(main_keys, session)
              end
            end

            table.insert(main_keys, { action = false }) -- separator
            table.insert(main_keys, { icon = " ", key = "q", desc = "Quit", action = ":qa" })

            return main_keys
          end)(),
        },
        sections = {
          { section = "header" },
          { section = "keys", padding = 1 },
          {
            pane = 2,
            icon = " ",
            title = "Git Status",
            section = "terminal",
            enabled = function()
              return Snacks.git.get_root() ~= nil
            end,
            cmd = "git status --short --branch --renames",
            height = 5,
            padding = 1,
            ttl = 5 * 60,
            indent = 3,
          },
          { section = "startup" },
        },
      }

      return opts
    end,
  },
}
