local avatar_utils = require('scripts/ezlibs-custom/avatar_utils/avatar_utils')
local helpers = require('scripts/ezlibs-scripts/helpers')

--todo
-- create special promp for choosing the idle animation
-- update the navispot with new custom properties, idle_animation, facing
-- increment homepage version


local entity = {}

entity.pre_configure = function (homepage,object)
    local player_id = homepage.editor_id
    local new_avatar_folder = 'assets/avatars/'
    local player_safe_secret = helpers.get_safe_player_secret(player_id)
    local texture_filename = new_avatar_folder..player_safe_secret..".png"
    local animation_filename = new_avatar_folder..player_safe_secret..".animation"
    local success = avatar_utils.copy_player_avatar_to(player_id,texture_filename,animation_filename)
    if success then
        print("NaviSpot: Copied player avatar to: " .. texture_filename .. " and " .. animation_filename)
        --convert paths to server paths
        Net.set_object_custom_property(homepage.area_id, object.id, "texture_path", texture_filename)
        Net.set_object_custom_property(homepage.area_id, object.id, "animation_path", animation_filename)
        Net.provide_asset(homepage.area_id, texture_filename)
        Net.provide_asset(homepage.area_id, animation_filename)
    end

end

entity.on_refresh = function (homepage,object)
    print(object)
    local texture_path = object.custom_properties["texture_path"]
    local animation_path = object.custom_properties["animation_path"]

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

    local facing = object.custom_properties["facing"]


    local new_bot_id = homepage.area_id .. "_" .. object.id
    Net.remove_bot(new_bot_id)
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
        direction=facing
    }

    print(bot_details)

    Net.create_bot(new_bot_id,bot_details)
end

return entity