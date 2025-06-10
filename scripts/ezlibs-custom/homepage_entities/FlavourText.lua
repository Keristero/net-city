local entity = {}

entity.on_async_object_interaction = function (homepage,object,event)
    return async(function ()
        local text = object.custom_properties["text"]
        if text ~= "" then
            await(Async.message_player(event.player_id,object.custom_properties["text"]))
        end
    end)
end

return entity