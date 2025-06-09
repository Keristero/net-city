local home_page_helpers = require('scripts/ezlibs-custom/home_page_helpers')
local entity = {}

entity.on_refresh = function (homepage,object)
    local target_code = object.custom_properties["target_code"]
    local warp_is_online = false
    if target_code ~= nil then
        if home_page_helpers.homepage_map_memory.warp_codes[target_code] then
            warp_is_online = true
        end
    end
    if warp_is_online then
        homepage:Enable_class(object.id)
    else
        homepage:Disable_class(object.id)
    end
end

entity.post_placement = function (homepage,object)
    await(Async.message_player(homepage.editor_id,"Registering page warp..."))
    local warp_code = homepage:Register_unique_page_warp(object.id)
    Net.set_object_custom_property(homepage.area_id,object.id,'warp_code',warp_code)
    await(Async.message_player(homepage.editor_id,"Warp data is:\n"..warp_code))
end

return entity