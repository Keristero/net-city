local avatar_utils = require('scripts/ezlibs-custom/avatar_utils/avatar_utils')

--todo
-- create special promp for choosing the idle animation
-- copy the avatar files and save the new paths to the objects custom properties (texture_path, animation_path)
-- update the navispot with new custom properties, idle_animation, facing
-- increment homepage version


local entity = {}
entity.on_refresh = function (homepage,object)
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
    local bot_details = {
        name=homepage.player_name,
        area_id=homepage.area_id,
        warp_in=true,
        texture_path=texture_path,
        animation_path=animation_path,
        animation=idle_animation,
        x=object.x,
        y=object.y,
        z=object.z,
        direction=facing
    }

    Net.create_bot(new_bot_id,bot_details)
end

return entity