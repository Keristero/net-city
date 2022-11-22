local home_page_decorations = require("scripts/ezlibs-custom/home_page_decorations")
local ezmemory = require('scripts/ezlibs-scripts/ezmemory')
local Direction = require("scripts/ezlibs-scripts/direction")

local function create_operation(hp,removal_cursor_info)
    local temporary_object_id = home_page_decorations.create_object_from_gid(hp.area_id, removal_cursor_info.gid, 0,0,0)
    return {
        name="store tile",
        tic_func=function()
            if not temporary_object_id then
                return
            end
            local temp_object = Net.get_object_by_id(hp.area_id,temporary_object_id)
            local player_position = Net.get_player_position(hp.editor_id)
            local player_facing = Net.get_player_direction(hp.editor_id)
            local direction_offset = Direction.to_vector(player_facing)
            local new_x = math.ceil(player_position.x + direction_offset.x)
            local new_y = math.ceil(player_position.y + direction_offset.y)
            local new_z = player_position.z
            if temp_object.x ~= new_x or temp_object.y ~= new_y or temp_object.z ~= new_z then
                Net.move_object(hp.area_id,temporary_object_id,new_x,new_y,new_z)
                print('moved cursor',new_x,new_y,new_z)
            end
        end,
        tile_interact_func=function(event)
            local A_press = event.button == 0
            local temp_object = Net.get_object_by_id(hp.area_id, temporary_object_id)
            if A_press then
                local x = temp_object.x -1
                local y = temp_object.y -1
                local z = temp_object.z
                hp:Replace_tile(0,x,y,z)
            end
        end,
        object_interact_func=function(event)
            return nil
        end,
        cancel_func=function()
            if temporary_object_id then
                Net.remove_object(hp.area_id, temporary_object_id)
            end
        end
    }
end

return create_operation