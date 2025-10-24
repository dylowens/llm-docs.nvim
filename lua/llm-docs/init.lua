-- ~/.local/share/nvim/lazy/llm-docs.nvim/lua/llm-docs/init.lua
local M = {}
local Popup = require("nui.popup")

-- Capture visual selection properly
local function get_visual_selection()
  local _, ls, cs = unpack(vim.fn.getpos("'<"))
  local _, le, ce = unpack(vim.fn.getpos("'>"))
  if ls == 0 or le == 0 then return "" end
  local lines = vim.fn.getline(ls, le)
  if #lines == 0 then return "" end
  lines[#lines] = string.sub(lines[#lines], 1, ce)
  lines[1] = string.sub(lines[1], cs)
  return table.concat(lines, "\n")
end

-- Option 1: Basic native floating window
local function show_basic_popup(response)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(response, "\n"))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 2,
    col = 2,
    width = 70,
    height = 10,
    style = "minimal",
    border = "rounded",
  })
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end, { buffer = buf, nowait = true })
end

-- Option 2: NUI popup window
local function show_nui_popup(response)
  local popup = Popup({
    enter = true,
    border = { style = "rounded", text = { top = "LLM Docs", top_align = "center" } },
    position = "50%",
    size = { width = "80%", height = "30%" },
  })
  popup:mount()
  popup:map("n", "q", function() popup:unmount() end)
  popup:map("n", "<Esc>", function() popup:unmount() end)
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, vim.split(response, "\n"))
end

-- Option 3: Bottom split (keeps original buffer on top, opens 1/3 height)
local function show_split_window(response)
  -- Save current window
  local current_win = vim.api.nvim_get_current_win()

  -- Open horizontal split below
  vim.cmd("belowright split")

  -- Make the bottom split roughly 1/3 of the total editor height
  local total_height = vim.o.lines
  local split_height = math.floor(total_height / 3)
  vim.cmd("resize " .. split_height)

  -- Create buffer for the split
  local split_win = vim.api.nvim_get_current_win()
  local split_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(split_win, split_buf)

  -- Write the response into the split
  vim.api.nvim_buf_set_lines(split_buf, 0, -1, false, vim.split(response, "\n"))

  -- Configure buffer behavior
  vim.bo[split_buf].buftype = "nofile"
  vim.bo[split_buf].bufhidden = "wipe"
  vim.bo[split_buf].swapfile = false
  vim.bo[split_buf].modifiable = false

  -- Keymaps to close the split and return to previous window
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(split_win) then vim.api.nvim_win_close(split_win, true) end
    vim.api.nvim_set_current_win(current_win)
  end, { buffer = split_buf, nowait = true })

  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(split_win) then vim.api.nvim_win_close(split_win, true) end
    vim.api.nvim_set_current_win(current_win)
  end, { buffer = split_buf, nowait = true })
end

-- Popup to choose display type
local function choose_display_option(response)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = {
    "Choose LLM Response Display:",
    "1. Basic Floating Popup",
    "2. NUI Popup (Styled)",
    "3. Bottom Split Window",
    "",
    "Press 1, 2, or 3 to select. Press q or Esc to cancel.",
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = 40,
    height = #lines,
    row = 5,
    col = 10,
    style = "minimal",
    border = "rounded",
  })

  local function close()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end

  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "1", function() close(); show_basic_popup(response) end, { buffer = buf })
  vim.keymap.set("n", "2", function() close(); show_nui_popup(response) end, { buffer = buf })
  vim.keymap.set("n", "3", function() close(); show_split_window(response) end, { buffer = buf })
end

-- Prompt window for input
function M.show_input_window(context)
  context = context or ""
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "prompt")
  vim.fn.prompt_setprompt(buf, "Ask LLM: ")

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 1,
    width = 50,
    height = 1,
    style = "minimal",
    border = "rounded",
  })
  vim.api.nvim_set_current_win(win)
  vim.cmd("startinsert")

  vim.keymap.set("i", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
  end, { buffer = buf, nowait = true })

  vim.fn.prompt_setcallback(buf, function(input)
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end

    local response = string.format(
      "Context:\n%s\n\nLLM Response:\nThis is a simulated paragraph of documentation based on your query: '%s'.",
      context ~= "" and context or "(none)",
      input or "(empty input)"
    )
    choose_display_option(response)
  end)
end

-- Entry points
function M.open()
  M.show_input_window()
end

function M.open_visual()
  local context = get_visual_selection()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  M.show_input_window(context)
end

function M.setup(opts)
  M.opts = opts or {}
end

return M
