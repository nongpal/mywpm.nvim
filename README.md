![banner_image](.github/banner_plugin.png)

## Install with Lazy

```lua
{
    "slowy07/mywpm.nvim",
    configs = function()
        require("mywpm").setup({
            -- interval
            notify_interval = 60 * 1000,
            -- highest wpm
            high = 60,
            -- lowest wpm
            low = 15,

            -- highest wpm message
            high_msg = "nice keep it up 🔥",
            -- lowest wpm message
            low_message = "hahaha slowhand 🐌",

            -- show notify and virtual text
            show_virtual_text = true,
            notify = true,
        })
    end
}
```
