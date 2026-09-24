local assdraw = require "mp.assdraw"
local options = require "mp.options"

local info_active = true
local o = {
    font_size = 20,
    font_color = "000000",
    border_size = 1.0,
    border_color = "000000",
    margin_right = 18,
    margin_bottom = 18,
}
options.read_options(o)

function get_formatting()
    return string.format(
        "{\\fs%d}{\\b1}{\\1c&H%s&}{\\bord%f}{\\3c&H%s&}",
        o.font_size, o.font_color,
        o.border_size, o.border_color
    )
end

function timestamp(duration)
    -- mpv may return nil before exiting.
    if not duration then return "" end
    local hours = duration / 3600
    local minutes = duration % 3600 / 60
    local seconds = duration % 60
    return string.format("%02d:%02d:%06.03f", hours, minutes, seconds)
end

function get_info()
    return string.format(
        "%s%s  %s  %s",
        get_formatting(),
        mp.get_property("filename", ""),
        timestamp(mp.get_property_native("time-pos")),
        os.date("%H:%M")
    )
end

function render_info()
    local width, height = mp.get_osd_size()
    local ass = assdraw.ass_new()
    ass:an(3)
    ass:pos(width - o.margin_right, height - o.margin_bottom)
    ass:append(get_info())
    mp.set_osd_ass(width, height, ass.text)
end

function clear_info()
    mp.set_osd_ass(0, 0, "")
end

function toggle_info()
    if info_active then
        clear_info()
    else
        render_info()
    end
    info_active = not info_active
end

local function update_info()
    if info_active then render_info() end
end

mp.observe_property("time-pos", "native", update_info)
mp.register_event("file-loaded", update_info)
mp.add_periodic_timer(1, update_info)
mp.add_key_binding("TAB", mp.get_script_name(), toggle_info)
