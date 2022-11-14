local Direction = require("scripts/ezlibs-scripts/direction")

local function create_operation(hp, area_id,object_id)
    local original_object_info = Net.get_object_by_id(area_id, object_id)
    local temporary_object_id = Net.create_object(area_id, original_object_info)
    local previous_operation = hp.current_operation

    local function finish_moving()
        local temp_object_info = Net.get_object_by_id(hp.area_id, temporary_object_id)
        Net.remove_object(hp.area_id, temporary_object_id)
        Net.move_object(hp.area_id,object_id,temp_object_info.x,temp_object_info.y,temp_object_info.z)
        print('finished moving object')
        hp:Set_current_operation(previous_operation)
    end

    return {
        name="moving",
        tic_func=function()
            local player_position = Net.get_player_position(hp.editor_id)
            local player_facing = Net.get_player_direction(hp.editor_id)
            local direction_offset = Direction.to_vector(player_facing)
            local new_x = player_position.x + direction_offset.x
            local new_y = player_position.y + direction_offset.y
            local new_z = player_position.z
            Net.move_object(hp.area_id,temporary_object_id,new_x,new_y,new_z)
        end,
        tile_interact_func=function(event)
            local A_press = event.button == 0
            if A_press then
                finish_moving()
            end
        end,
        object_interact_func=function(event)
            local A_press = event.button == 0
            if A_press then
                finish_moving()
            end
        end,
        cancel_func=function()
            Net.remove_object(hp.area_id, temporary_object_id)
        end,
    }
end

return create_operation