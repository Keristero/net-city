local entity = {}

entity.post_placement = function (homepage,object)
    await(Async.message_player(homepage.editor_id,"Registering page warp..."))
    local warp_code = homepage:Register_unique_page_warp(object.id)
    Net.set_object_custom_property(homepage.area_id,object.id,'warp_code',warp_code)
    await(Async.message_player(homepage.editor_id,"Warp data is:\n"..warp_code))
end

return entity