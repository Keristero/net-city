local home_page_helpers = require("scripts/ezlibs-custom/home_page_helpers")
local ezmemory = require('scripts/ezlibs-scripts/ezmemory')
local Direction = require("scripts/ezlibs-scripts/direction")

local function create_operation(hp,decoration_info)
    --TODO pop up a menu here with the list of objects in the player's storage that they can place, this operation will become an operation for placing that object until it is depleted
    local temporary_object_id = home_page_helpers.create_object_from_gid(hp.area_id, decoration_info.gid, 0,0,0)
    hp:Disable_class(temporary_object_id)

    local function finish_placing()
        local temp_object_info = Net.get_object_by_id(hp.area_id, temporary_object_id)
        local x = temp_object_info.x-1
        local y = temp_object_info.y-1
        local z = temp_object_info.z
        hp:Replace_tile(temp_object_info.data.gid,x,y,z)
        Net.remove_object(hp.area_id, temporary_object_id)
        print('finished placing tile')
        local object_count = ezmemory.count_player_item(hp.editor_id, decoration_info.name)
        local next_operation = nil
        if object_count > 0 then
            --if the player still has more of this item, repeat the place operation
            next_operation = create_operation(hp,decoration_info)
        end
        hp:Set_current_operation(next_operation)
    end

    return {
        name="place tile",
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
            if A_press then
                finish_placing()
            end
        end,
        object_interact_func=function(event)
            local A_press = event.button == 0
            if A_press then
                finish_placing()
            end
        end,
        cancel_func=function()
            if temporary_object_id then
                Net.remove_object(hp.area_id, temporary_object_id)
            end
        end
    }
end

return create_operation