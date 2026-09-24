local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"

package.path = mp.command_native({"expand-path", "~~/scripts/a-modules/?.lua;"}) .. package.path
local input = require "user-input-module"


local function active_path()
    local path = mp.get_property("path")
    if not path or path:match("^[%a][%w+.-]*://") then
        msg.error("Tagging needs a local media file")
        return nil
    end

    if path:sub(1, 1) ~= "/" then
        path = utils.join_path(utils.getcwd(), path)
    end

    if not utils.file_info(path) then
        msg.error("Active media file does not exist: " .. path)
        return nil
    end

    return path
end


local function reload_renamed_file(path)
    local count = mp.get_property_number("playlist-count", 0)
    local position = mp.get_property_number("playlist-pos", 0)

    mp.commandv("loadfile", path, "append")
    mp.commandv("playlist-move", count, position + 1)
    mp.commandv("playlist-remove", "current")
end


local function move_file(path, new_path)
    if path == new_path then
        msg.info("Filename is unchanged")
        return true
    end

    if utils.file_info(new_path) then
        msg.error("Refusing to overwrite existing file: " .. new_path)
        return false
    end

    local success, error = os.rename(path, new_path)
    if not success then
        msg.error("Rename failed: " .. tostring(error))
        return false
    end

    reload_renamed_file(new_path)
    msg.info("Renamed to " .. new_path)
    return true
end


local function advance_after_tag()
    local advanced = false
    local function advance()
        if advanced then return end
        advanced = true
        mp.unregister_event(advance)
        mp.commandv("script-binding", "uosc/next")
    end

    mp.register_event("file-loaded", advance)
    mp.add_timeout(0.5, advance)
end


local function clean_tag(value)
    if not value then return nil end

    value = value:match("^%s*(.-)%s*$")
    if value == "" then return nil end
    value = value:gsub("%s+", "-")
    value = value:gsub("[._/\\]", "-")
    return value
end


local function annotation_parts(path)
    local directory, filename = utils.split_path(path)
    local stem, extension = filename:match("^(.*)%.([^./]+)$")
    if not stem then
        msg.error("Tagging needs a filename extension: " .. filename)
        return nil
    end

    local id = stem:match("[xsaCPS](%d%d%d%d%d%d%d?)")
    if not id then
        msg.error("No anotr-style media ID in filename: " .. filename)
        return nil
    end

    local tags = {}
    for tag in stem:gmatch("[._]([SRN][^._]*)") do
        table.insert(tags, tag)
    end

    local persistent = stem:match("[._](zX[^._]*)")
    return directory, extension, id, tags, persistent
end


local function annotated_path(path, prefix, additions, keep_tags)
    local directory, extension, id, tags, persistent = annotation_parts(path)
    if not directory then return nil end

    if not keep_tags then tags = {} end
    for _, tag in ipairs(additions or {}) do
        if tag then table.insert(tags, tag) end
    end
    if persistent then table.insert(tags, persistent) end

    local name = prefix .. id
    if #tags > 0 then name = name .. "_" .. table.concat(tags, "_") end
    return directory .. name .. "." .. extension
end


local function rename(text, error)
    if not text then
        if error ~= "cancelled" and error ~= "exitted" then msg.warn(error) end
        return
    end

    local path = active_path()
    if not path then return end

    local directory = utils.split_path(path)
    text = text:match("^%s*(.-)%s*$")
    if text == "" or text:find("[/\\]") then
        msg.error("Enter a non-empty filename without a path")
        return
    end

    move_file(path, directory .. text)
end


local function tag_file(values)
    local path = active_path()
    if not path then return end

    local surfer = clean_tag(values.surfer)
    local rating = clean_tag(values.rating)
    local notation = clean_tag(values.notation)
    local additions = {
        surfer and "S" .. surfer,
        rating and "R" .. rating,
        notation and "N" .. notation,
    }
    local new_path = annotated_path(path, "s", additions, true)
    if new_path and new_path ~= path and move_file(path, new_path) then
        advance_after_tag()
    end
end


local function request_full_tag()
    local values = {}
    input.cancel_user_input()
    input.get_user_input(function(surfer)
        if not surfer then return end
        values.surfer = surfer
        input.get_user_input(function(rating)
            if not rating then return end
            values.rating = rating
            input.get_user_input(function(notation)
                if not notation then return end
                values.notation = notation
                tag_file(values)
            end, { text = "Notation tag (optional):" })
        end, { text = "Rating tag (optional):" })
    end, { text = "Surfer tag (optional):" })
end


local function request_quick_tag()
    input.cancel_user_input()
    input.get_user_input(function(surfer)
        if not surfer then return end
        tag_file({ surfer = surfer })
    end, { text = "Surfer tag:" })
end


local function command_mode()
    input.cancel_user_input()
    input.get_user_input(function(command, error)
        if not command then
            if error ~= "cancelled" and error ~= "exitted" then msg.warn(error) end
            return
        end

        command = command:match("^%s*(.-)%s*$")
        if command == "" then return end

        local success, command_error = pcall(mp.command, command)
        if not success then msg.error("Command failed: " .. tostring(command_error)) end
    end, {
        id = "command-mode",
        text = ":",
    })
end


local function add_delete_tag()
    tag_file({ surfer = "zz" })
end


local function untag_file()
    local path = active_path()
    if not path then return end

    local new_path = annotated_path(path, "A")
    if new_path then move_file(path, new_path) end
end


local function clone_file()
    local path = active_path()
    if not path then return end

    local new_path = annotated_path(path, "C")
    if not new_path then return end
    if utils.file_info(new_path) then
        msg.error("Refusing to overwrite existing file: " .. new_path)
        return
    end

    local source, error = io.open(path, "rb")
    if not source then
        msg.error("Clone failed: " .. tostring(error))
        return
    end
    local target, target_error = io.open(new_path, "wb")
    if not target then
        source:close()
        msg.error("Clone failed: " .. tostring(target_error))
        return
    end
    while true do
        local chunk = source:read(1024 * 1024)
        if not chunk then break end
        target:write(chunk)
    end
    source:close()
    target:close()
    msg.info("Cloned to " .. new_path)
end


mp.register_event("end-file", function()
    input.cancel_user_input()
end)

mp.add_key_binding(nil, "tag-file", request_full_tag)
mp.add_key_binding(nil, "tag-file-quick", request_quick_tag)
mp.add_key_binding(nil, "command-mode", command_mode)
mp.add_key_binding(nil, "tag-file-delete", add_delete_tag)
mp.add_key_binding(nil, "untag-file", untag_file)
mp.add_key_binding(nil, "clone-tagged-file", clone_file)

-- Keep the original generic rename function available for an explicit binding.
mp.add_key_binding(nil, "rename-file", function()
    local path = active_path()
    if not path then return end
    local _, filename = utils.split_path(path)
    input.cancel_user_input()
    input.get_user_input(rename, {
        text = "Enter new filename:",
        default_input = filename,
        replace = false,
        cursor_pos = filename:find("%.%w+$") or #filename + 1,
    })
end)
