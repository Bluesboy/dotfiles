--fits the window into 40% of the screen on any monitor, also after moving it
--autofit is broken on Wayland with HiDPI scale: it gets halved on a 2x monitor
--display-width is stale after moving to another monitor, so the width is
--derived from display-height assuming a 16:9 screen

local utils = require "mp.utils"

local frac = 0.4
local timer = nil

local function fit()
    local dh = mp.get_property_number("display-height")
    local vw = mp.get_property_number("dwidth")
    local vh = mp.get_property_number("dheight")
    if not (dh and vw and vh) or mp.get_property_bool("fullscreen") then
        return
    end
    local dw = dh * 16 / 9
    mp.set_property_number("window-scale", math.min(dw * frac / vw, dh * frac / vh))
end

--let mpv finish its own rescale after a monitor change before overriding it
local function fit_later()
    if timer then
        timer:kill()
    end
    timer = mp.add_timeout(0.2, fit)
end

--the window is created before mpv knows the monitor scale, so take it from
--niri for the focused output and pre-scale autofit to avoid a visible resize
mp.add_hook("on_load", 50, function()
    local r = mp.command_native({
        name = "subprocess",
        args = {"niri", "msg", "-j", "focused-output"},
        capture_stdout = true,
        playback_only = false,
    })
    local out = r.status == 0 and utils.parse_json(r.stdout)
    local scale = out and out.logical and out.logical.scale
    if scale then
        local p = frac * 100 * scale
        mp.set_property("autofit", p .. "%x" .. p .. "%")
    end
end)

mp.observe_property("display-names", "native", fit_later)
mp.observe_property("display-hidpi-scale", "number", fit_later)
mp.observe_property("dwidth", "number", fit_later)
