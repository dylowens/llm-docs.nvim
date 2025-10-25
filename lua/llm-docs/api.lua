-- ~/.local/share/nvim/lazy/llm-docs.nvim/lua/llm-docs/api.lua
local Job = require("plenary.job")

local M = {}

-- Simple logger
local function log(msg, opts)
  opts = opts or {}
  local log_path = vim.fn.stdpath("data") .. "/llm-docs.log"
  local f = io.open(log_path, "a")
  if f then
    f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
    f:close()
  end
  if opts.notify then
    vim.schedule(function()
      vim.notify(msg, vim.log.levels.INFO, { title = "LLM-Docs" })
    end)
  end
end

-- Preprompt
local SYSTEM_PROMPT = [[
You are a precise documentation retrieval assistant.
When given a programming context and a query, return only official-style reference information
about functions, classes, or methods — concise and factual.
Include:
- A brief summary (purpose)
- Parameters and types
- Return values
- Example usage if essential
Exclude commentary, opinions, or unrelated explanations.
]]

local function build_messages(context, input)
  local messages = {
    { role = "system", content = SYSTEM_PROMPT },
  }

  if context and context:match("%S") then
    table.insert(messages, {
      role = "user",
      content = string.format("Context:\n%s", context),
    })
  end

  table.insert(messages, {
    role = "user",
    content = string.format("User Query:\n%s", input or ""),
  })

  return messages
end

function M.query(context, input, callback)
  local key = os.getenv("OPENAI_API_KEY")
  if not key or key == "" then
    vim.schedule(function()
      callback("[Error] Missing OPENAI_API_KEY environment variable.")
    end)
    return
  end

  local payload = vim.fn.json_encode({
    model = "gpt-4o-mini",
    messages = build_messages(context, input),
  })

  log("Sending API request to OpenAI...", { notify = true })

  Job:new({
    command = "curl",
    args = {
      "-s",
      "https://api.openai.com/v1/chat/completions",
      "-H", "Content-Type: application/json",
      "-H", "Authorization: Bearer " .. key,
      "-d", payload,
    },
    on_exit = function(j, return_val)
      local raw = j:result()
      local output = table.concat(raw, "")
      output = output:gsub("^%s+", ""):gsub("%s+$", "")

      log("Raw API output:\n" .. output)

      if return_val ~= 0 then
        vim.schedule(function()
          callback(string.format("[Error] curl exited with %d", return_val))
        end)
        return
      end

      -- Safely decode JSON inside the main event loop
      vim.schedule(function()
        local ok, decoded = pcall(vim.fn.json_decode, output)
        if not ok or not decoded then
          log("JSON decode failed: " .. tostring(decoded))
          callback("[Error] Failed to decode JSON response.")
          return
        end

        local text = decoded.choices
          and decoded.choices[1]
          and decoded.choices[1].message
          and decoded.choices[1].message.content
          or "[Empty LLM response]"

        log("LLM response received successfully.")
        callback(text)
      end)
    end,
  }):start()
end

return M
