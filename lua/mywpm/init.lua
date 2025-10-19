--- @module "mypwm"
--- track realtime words per minute (WPM) during coding

local M = {}

--- neovim namespace for virtual text extmarks
local ns = vim.api.nvim_create_namespace("mywpm")

--- internal state tracking type session
--- @class stat
--- @field start_words number word count sessions start
--- @field time number start time in millisecond (check on vim.uv.now())
--- @field timer? uv.uv_timer_t timer handler
local stats = { start_words = 0, time = 0, timer = nil }

--- timestamp last notif (to get enforce cooldown)
local last_notif_time = 0

--- alias
local uv = vim.uv

--- default plugin options
--- @class wpm_option
--- @field notify_interval integer time (ms) between from notification
--- @field high integer wpm threshold for "high speed" notification (default: 60)
--- @field low integer wpm threshold for "low speed" notification (default: 15)
--- @field high_msg string message show when wpm got high
--- @field low_message string message when wpm got low
--- @field show_virtual_text boolean whether to show wpm as virtual text (default: true)
--- @field notify boolean whether to show notification at all (default: true)
--- @field virt_text fun(wpm: number): string function to format virtual text
--- @field virt_text_pos string position of virtual text
local DEFAULT_OPTS = {
  notify_interval = 60 * 1000,
  high = 60,
  low = 15,
  high_msg = "nice keep it up 🔥",
  low_message = "hahaha slowhand 🐌",
  show_virtual_text = true,
  notify = true,
  update_time = 300,
  virt_text = function(wpm)
    return ("👨‍💻 Speed: %.0f WPM"):format(wpm)
  end,
  virt_text_pos = "right_align",
}

local config = {}

local function merge_options(user_opts)
  local merged = vim.deepcopy(DEFAULT_OPTS)

  if not user_opts then
    return merged
  end

  if type(user_opts) ~= "table" then
    vim.notify(
      "mywpm: Invalid options type provided to setup() - expect table, got " .. type(user_opts), vim.log.levels.WARN
    )
    return merged
  end

  for key, value in pairs(user_opts) do
    if merged[key] ~= nil then
      merged[key] = value
    else
      vim.notify(
        "mywpm: Unknown config key '" .. tostring(key) .. "' provide to setup()", vim.log.levels.WARN
      )
    end
  end

  return merged
end

--- check whether wpm-based notification should be shown
---
--- this function enforcing min time between notification
--- and only trigger one notification per cooldown window
--- even if both high and low threshold are crossed (which shouldn't happen)
---
--- @param wpm number current word per minute value
--- @return nil
local function checkNofity(wpm)
  local now = uv.now()
  if last_notif_time == 0 then
    last_notif_time = now
    return
  end

  -- enforcing notification cooldown: skip if too shown since last alert
  local elapsed = now - last_notif_time
  if elapsed < config.notify_interval then
    return
  end

  -- notofication for high typing speed
  if wpm > config.high then
    vim.notify(config.high_msg, vim.log.levels.INFO)
    last_notif_time = now -- reset cooldown
    return                -- preventing low-speed notification in same window
  end

  if wpm < DEFAULT_OPTS.low then
    vim.notify(DEFAULT_OPTS.low_message, vim.log.levels.WARN)
    last_notif_time = now
  end
end

--- rendering current WPM as virtual text in the active buffer
--- virtual text appears as non-intrusive update to reflect real-time changer
---
--- @param wpm number current wpm to display
--- @return nil
local function render(wpm)
  if not config.show_virtual_text then
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(0, ns, 0, 0, {
    virt_text = { { config.virt_text(wpm), "Comment" } },
    virt_text_pos = config.virt_text_pos,
    priority = 10,
  })

  -- conditional trigger notification logic if enabled
  if config.notify then
    checkNofity(wpm)
  end
end

local function tick()
  local now = uv.now()
  local dt = (now - stats.time) / 1000

  if dt <= 0 then
    return
  end

  local words = vim.fn.wordcount().words
  local typed = words - stats.start_words
  local wpm = typed / (dt / 60)

  if config.show_virtual_text then
    render(wpm)
  end
end

local function start_timer()
  if stats.timer then
    return
  end

  stats.timer = uv.new_timer()
  stats.time = uv.now()
  stats.start_words = vim.fn.wordcount().words
  stats.timer:start(0, config.update_time, vim.schedule_wrap(tick))
end

local function stop_timer()
  if stats.timer then
    stats.timer:stop()
    stats.timer:close()
    stats.timer = nil
  end
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
end

function M.setup(opts)
  config = merge_options(opts)
  local group = vim.api.nvim_create_augroup("mywpm", { clear = true })
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = start_timer,
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = stop_timer,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = stop_timer,
  })
end

function M.get_wpm()
  if not stats.timer then
    return 0
  end

  local now = vim.uv.now()
  local dt = (now - stats.time) / 1000
  if dt <= 0 then
    return 0
  end

  local words = vim.fn.wordcount().words
  local typed = words - stats.start_words
  local wpm = typed / (dt / 60)
  return wpm
end

return M
