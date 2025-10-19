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
local options = {
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


local function overridingOptions(opts)
  opts = opts or {}
  options.notify_interval = opts.notify_interval or options.notify_interval
  options.high = opts.high or options.high
  options.high_msg = opts.high_msg or options.high_msg
  options.show_virtual_text = opts.show_virtual_text or options.show_virtual_text
  options.notify = opts.notify or options.notify
  options.update_time = opts.update_time or options.update_time
  options.virt_text = opts.virt_text or options.virt_text
  options.virt_text_pos = opts.virt_text_pos or options.virt_text_pos
end

local function checkNofity(wpm)
  local now = uv.now()
  if last_notif_time == 0 then
    last_notif_time = now
    return
  end

  if now - last_notif_time < options.notify_interval then
    return
  end

  if wpm > options.high then
    vim.notify(options.high_msg, vim.log.levels.INFO)
    last_notif_time = now
  end

  if wpm < options.low then
    vim.notify(options.low_message, vim.log.levels.WARN)
    last_notif_time = now
  end
end

local function render(wpm)
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(0, ns, 0, 0, {
    virt_text = { { options.virt_text(wpm), "Comment" } },
    virt_text_pos = options.virt_text_pos,
  })
  if options.notify then
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

  _G.mywpm_current_wpm = wpm

  if options.show_virtual_text then
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
  stats.timer:start(0, options.update_time, vim.schedule_wrap(tick))
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
  overridingOptions(opts)
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
