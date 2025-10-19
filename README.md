# mywpm.nvim
show your wpm on neovim

## Install with Lazy

```lua
{
    "slowy07/mywpm.nvim",
    opts = {
        -- config options
        -- 1 minute
        notify_interval = 60 * 1000,
        -- high wpm (default)
        high = 60,
        -- low wpm (default)
        low = 15,

        virtual_text = function(wpm)
            return ("Speed: %0.f WPM"):format(wpm)
        end,

        virtual_text_pos = "right_align"
    }
}
```
