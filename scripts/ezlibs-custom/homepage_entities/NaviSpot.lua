local avatar_utils = require('scripts/ezlibs-custom/avatar_utils/avatar_utils')
local helpers = require('scripts/ezlibs-scripts/helpers')
local Direction = require("scripts/ezlibs-scripts/direction")
local ezmenus = require('scripts/ezlibs-scripts/ezmenus')
local animation_bbs_color = {r=100,g=100,b=200}

--todo
-- create special promp for choosing the idle animation
-- update the navispot with new custom properties, idle_animation, facing
-- increment homepage version


local entity = {}

entity.pre_configure = function (homepage,object)
    return async(function ()
        local player_id = homepage.editor_id
        local new_avatar_folder = 'assets/avatars/'
        local player_safe_secret = helpers.get_safe_player_secret(player_id)
        local texture_filename = new_avatar_folder.."sheet/"..player_safe_secret..".png"
        local animation_filename = new_avatar_folder.."sheet/"..player_safe_secret..".animation"
        local mug_texture_filename = new_avatar_folder.."mug/"..player_safe_secret..".png"
        local mug_animation_filename = new_avatar_folder.."mug/"..player_safe_secret..".animation"
        local success = avatar_utils.copy_player_avatar_to(player_id,texture_filename,animation_filename,mug_texture_filename,mug_animation_filename)
        if not success then
            print("NaviSpot: Failed to copy player avatar for player_id: " .. player_id)
        end

        --convert paths to server paths
        Net.set_object_custom_property(homepage.area_id, object.id, "texture_path", texture_filename)
        Net.set_object_custom_property(homepage.area_id, object.id, "animation_path", animation_filename)
        Net.set_object_custom_property(homepage.area_id, object.id, "mug_texture_path", mug_texture_filename)
        Net.set_object_custom_property(homepage.area_id, object.id, "mug_animation_path", mug_animation_filename)

        local avatar = avatar_utils.parse_animation_file(animation_filename)
        if avatar == nil then
            print("NaviSpot: Failed to parse avatar from animation path: " .. animation_filename)
            return
        end

        local posts = {}
        local menu_title = "Select Idle Animation"
        --for each animation in avatar.animations table
        for animation_name, animation_data in pairs(avatar.animations) do
            table.insert(posts, helpers.create_bbs_option(animation_name))
        end

        local menu_board = ezmenus.open_menu(homepage.editor_id, menu_title,animation_bbs_color,posts)
        local post_id = await(menu_board.selection_once())
        await(menu_board.close_async())
        Net.set_object_custom_property(homepage.area_id, object.id, "idle_animation", post_id)

    end)
end

entity.on_async_object_interaction = function (homepage,object,event)
    return async(function ()
        local text = object.custom_properties["chat"]
        local bot_id = homepage.area_id .. "_" .. object.id
        if text ~= "" then
            --get direction to the player
            if object.custom_properties["eye_contact"] == "true" then
                local player_pos = Net.get_player_position(event.player_id)
                local object_pos = Net.get_bot_position(bot_id)
                local direction = Direction.from_points(object_pos, player_pos)
                Net.animate_bot(bot_id,"IDLE_D",false)
                Net.set_bot_direction(bot_id, direction or "Down")
            end
            await(Async.message_player(event.player_id,text,"/server/"..object.custom_properties["mug_texture_path"],"/server/"..object.custom_properties["mug_animation_path"]))
            Net.animate_bot(bot_id, object.custom_properties["idle_animation"],true)
        end
    end)
end

entity.on_disable = function (homepage,object)
    local bot_id = homepage.area_id .. "_" .. object.id
    Net.remove_bot(bot_id)
    Net.set_object_visibility(homepage.area_id, object.id, true)
end

entity.on_enable = function (homepage,object)
    Net.set_object_visibility(homepage.area_id, object.id, false)
end

entity.on_refresh = function (homepage,object)
    local texture_path = object.custom_properties["texture_path"]
    local animation_path = object.custom_properties["animation_path"]
    local mug_texture_path = object.custom_properties["mug_texture_path"]
    local mug_animation_path = object.custom_properties["mug_animation_path"]

    if texture_path == nil or animation_path == nil then
        print("NaviSpot: Missing custom properties 'texture_path' or 'animation_path'")
        return
    end

    local avatar = avatar_utils.parse_animation_file(animation_path)
    if avatar == nil then
        print("NaviSpot: Failed to parse avatar from animation path: " .. animation_path)
        return
    end

    local idle_animation = object.custom_properties["idle_animation"]
    if not idle_animation or not avatar.animations[idle_animation] then
        idle_animation = nil
    end

    local new_bot_id = homepage.area_id .. "_" .. object.id
    Net.remove_bot(new_bot_id)
    
    --Net.provide_asset(homepage.area_id, texture_path)
    --Net.provide_asset(homepage.area_id, animation_path)
    --Net.provide_asset(homepage.area_id, mug_texture_path)
    --Net.provide_asset(homepage.area_id, mug_animation_path)
    local bot_details = {
        name=homepage.player_name,
        area_id=homepage.area_id,
        warp_in=true,
        texture_path="/server/"..texture_path,
        animation_path="/server/"..animation_path,
        animation=idle_animation,
        x=object.x,
        y=object.y,
        z=object.z,
        direction="Down"
    }

    Net.create_bot(new_bot_id,bot_details)
end

return entity