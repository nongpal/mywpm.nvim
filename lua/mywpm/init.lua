local M = {}

local ns = vim.api.nvim_create_namespace("mywpm")
local stats = { start_words = 0, time = 0, timer = nil }
local last_notif_time = 0
local uv = vim.uv

local options = {
  notify_interval = 60 * 1000,
  high = 60,
  low = 15,
  high_msg = "nice keep it up",
  low_message = "hahaha slowhand",
  show_virtual_text = true,
  notify = true,
  update_time = 300,
  virtual_text = function(wpm)
    return ("Speed: %.0f WPM"):format(wpm)
  end,
  virtual_text_pos = "right_align",
}

local function overridingOptions(opts)
  opts = opts or {}
  options.notify_interval = opts.notify_interval or options.notify_interval
  options.high = opts.high or options.high
  options.high_msg = opts.high_msg or options.high_msg
  options.show_virtual_text = opts.show_virtual_text or options.show_virtual_text
  options.notify = opts.notify or options.notify
  options.update_time = opts.update_time or options.update_time
  options.virtual_text = opts.virtual_text or options.virtual_text
  options.virtual_text_pos = opts.virtual_text_pos or options.virtual_text_pos
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

local function visual(wpm)
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(0, ns, 0, 0, {
    virtual_text = { { options.virtual_text(wpm), "Comment" } },
    virtual_text_pos = options.virtual_text_pos,
  })
  if options.notify then
    checkNofity(wpm)
  end
end

local function tick()
  local now = uv.now()
  local date_time = (now - stats.time) / 1000

  if date_time <= 0 then
    return
  end

  local words = vim.fn.wordcount().words
  local typed = words - stats.start_words
  local wpm = typed / (date_time / 60)

  if options.show_virtual_text then
    visual(wpm)
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
  local date_time = (now - stats.time) / 1000
  if date_time <= 0 then
    return 0
  end

  local words = vim.fn.wordcount().words
  local typed = words - stats.start_words
  local wpm = typed / (date_time / 60)
  return wpm
end

return M
