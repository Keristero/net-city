local lua_yes_parser = require('scripts/ezlibs-custom/avatar_utils/lua_yes_parser/lib')
local base64 = require('scripts/ezlibs-custom/avatar_utils/base64')

local avatar_utils = {}

local function parse_duration(duration_str)
    local multi = 1
    if duration_str:sub(-1) == 'f' then
        --if the duration is in frames, we convert to seconds for simplicity
        duration_str = "0.00"..duration_str:sub(1, -2) -- remove the last character
        multi = 16.6
    end
    local duration = tonumber(duration_str) or 0
    return duration*multi
end

local get_arg_by_key = function (args,key,transform)
    for _, arg in ipairs(args) do
        if arg.key == key then
            --always remove " from string
            local value = arg.val:gsub('"','')
            -- ensure value is not nil
            if value == nil or value == '' then
                return nil
            end
            if transform == nil then
                return value
            end
            return transform(value)
        end
    end
    return nil
end

local assert_no_nils = function(expected_args)
    for key, value in pairs(expected_args) do
        if value == nil then
            error("Missing expected argument: " .. key)
            return true
        end
    end
    return false
end

local copy_file = function(source, destination)
    return async(function()
        local source_file = await(Async.read_file(source))
        if not source_file then
            error("Source file not found: " .. source)
        end
        await(Async.write_file(destination, source_file))
        print('copied file file',source,'to',destination)
    end)
end

function set_or_update_asset(asset_path,asset_content)
    if Net.has_asset("/server/"..asset_path) then
        Net.remove_asset("/server/"..asset_path)
    end
    Net.update_asset("/server/"..asset_path, asset_content)
end

avatar_utils.copy_player_avatar_to = function(player_id, new_texture_path, new_animation_path,mug_texture_path, mug_animation_path)
    local avatar = Net.get_player_avatar(player_id)
    local mugshot = Net.get_player_mugshot(player_id)

    --avatar
    local animation_data = Net.read_asset(avatar.animation_path)
    io.open(new_animation_path, "wb"):write(animation_data):close()

    local texture_data_b64_string = Net.read_asset(avatar.texture_path)
    local texture_data = base64.decode(texture_data_b64_string)
    io.open(new_texture_path, "wb"):write(texture_data):close()

    --mugshot
    local mugshot_animation_data = Net.read_asset(mugshot.animation_path)
    io.open(mug_animation_path, "wb"):write(mugshot_animation_data):close()

    local mugshot_texture_data_b64_string = Net.read_asset(mugshot.texture_path)
    local mugshot_texture_data = base64.decode(mugshot_texture_data_b64_string)
    io.open(mug_texture_path, "wb"):write(mugshot_texture_data):close()

    set_or_update_asset(new_texture_path,texture_data)
    set_or_update_asset(new_animation_path,animation_data)
    set_or_update_asset(mug_texture_path,mugshot_texture_data)
    set_or_update_asset(mug_animation_path,mugshot_animation_data)

    return true
end

avatar_utils.parse_animation_file = function(avatar_path)
    local avatar = {
        animations = {}
    }
    print('Parsing avatar: ' .. avatar_path)
    --check file exists
    local file = io.open(avatar_path, "r")
    if not file then
        print("Avatar file not found: " .. avatar_path)
        return nil
    end
    file:close()
    local yes_data = lua_yes_parser.parse(avatar_path)
    local currently_parsing_animation_name = nil
    for key, value in pairs(yes_data) do
        local text = value.text

        if text == "animation" then
            local expected_args = {
                name=get_arg_by_key(value.args, "state")
            }
            assert_no_nils(expected_args)
            avatar.animations[expected_args.name] = {
                frames = {},
                total_duration_ms = 0
            }
            currently_parsing_animation_name = expected_args.name
        end

        if text == "frame" then
            local expected_args = {
                duration=get_arg_by_key(value.args, "duration",parse_duration),
                x=get_arg_by_key(value.args, "x",tonumber),
                y=get_arg_by_key(value.args, "y",tonumber),
                width=get_arg_by_key(value.args, "w",tonumber),
                height=get_arg_by_key(value.args, "h",tonumber),
                originx=get_arg_by_key(value.args, "originx",tonumber),
                originy=get_arg_by_key(value.args, "originy",tonumber),
            }
            assert_no_nils(expected_args)
            local animation_table = avatar.animations[currently_parsing_animation_name]
            local frames_table = animation_table.frames
            frames_table[#frames_table + 1] = expected_args
            animation_table.total_duration_ms = animation_table.total_duration_ms + expected_args.duration
        end
    end
    return avatar
end

return avatar_utils