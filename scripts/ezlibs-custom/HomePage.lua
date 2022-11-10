local helpers = require('scripts/ezlibs-scripts/helpers')
local ezmemory = require('scripts/ezlibs-scripts/ezmemory')
local urlencode = require('scripts/ezlibs-scripts/urlencode')
local Direction = require("scripts/ezlibs-scripts/direction")

local net_city_map_id = 'default'
local test_net_city_homepage_exit_id = 2193

HomePage = {}
    
function HomePage:new(player_id)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    self.player_id = player_id
    local home_page_id = helpers.get_safe_player_secret(player_id) --TODO change this to a hash of the player id
    self.area_id = home_page_id
    self.player_safe_secret =  helpers.get_safe_player_secret(player_id)
    return o
end

function HomePage:Initialize_from_memory()
    local safe_secret = helpers.get_safe_player_secret(self.player_id)
    local player_memory = ezmemory.get_player_memory(safe_secret)
    Net.update_area(self.area_id, player_memory.home_page_data)
    self:Scan_and_validate()
    print('loaded home page from memory')
end

function HomePage:Initialize_from_template(template_map)
    Net.clone_area(template_map, self.area_id)
    local player_name_safe = urlencode.string(Net.get_player_name(self.player_id))
    local new_area_name = player_name_safe.." HP"
    Net.set_area_name(self.area_id,new_area_name)
    self:Save()
    print('generated new home page from base_homepage.tmx')
end

function HomePage:Finish_editing()
    self.editor_id = nil
    Net.set_object_class(self.area_id, self.home_warp_object.id, "Custom Warp")
    Net.set_object_class(self.area_id, self.city_warp_object.id, "Custom Warp")
end

function HomePage:Start_editing(player_id)
    self.editor_id = player_id
    Net.set_object_class(self.area_id, self.home_warp_object.id, "Disabled Warp")
    Net.set_object_class(self.area_id, self.city_warp_object.id, "Disabled Warp")
end

function HomePage:Cancel_editing()
    --finishes and discards changes
    HomePage:Cancel_current_operation()
    self:Finish_editing()
    self:Initialize_from_memory()
end

function HomePage:Cancel_current_operation()
    self.current_operation = nil
end

function HomePage:Edit_mode_prompt(player_id)
    return async(function ()
        local player_safe_secret = helpers.get_safe_player_secret(player_id)
        local is_owner = player_safe_secret == self.player_safe_secret
        if not is_owner then
            Net.message_player(player_id, "You dont have permission to edit this page")
            return
        end
        if self.editor_id then
            local res = await(Async.question_player(self.editor_id, "Finish Editing?"))
            if res == 1 then
                res = await(Async.question_player(player_id, "Save changes?"))
                if res == 1 then
                    self:Finish_editing()
                    self:Save()
                    await(Net.message_player(self.editor_id, "Saved"))
                elseif res == 0 then
                    await(Async.message_player(self.editor_id, "Once more"))
                    res = await(Async.question_player(player_id, "Save changes?"))
                end
                if res == 0 then
                    HomePage:Cancel_editing()
                end
            end
        else
            local res = await(Async.question_player(player_id, "Edit Homepage?"))
            if res == 1 then
                self:Start_editing(player_id)
                await(Async.message_player(self.editor_id, "You are now in edit mode"))
            end
        end
    end)
end

function HomePage:Handle_tile_interaction(event)
    local L_press = event.button == 1
    if self.current_operation then
        if self.editor_id == event.player_id then
            self.current_operation.interact_func(self,event)
            return
        end
    end
    if L_press then
        self:Edit_mode_prompt(event.player_id)
    end
end

function HomePage:Handle_player_area_transfer(event)
    if event.player_id == self.editor_id then
        self:Cancel_editing()
    end
end

function HomePage:Handle_player_disconnect(event)
    if event.player_id == self.editor_id then
        self:Cancel_editing()
    end
end

function HomePage:Handle_custom_warp(event)
    print(event.player_id, event.object_id)
    local player_area = Net.get_player_area(event.player_id)
    local object = Net.get_object_by_id(player_area,event.object_id)
    local hp_object_type = object.custom_properties["hp_object_type"]
    if hp_object_type == "home_warp" then
        Net.kick_player(event.player_id, "logging out", true)
    elseif hp_object_type == "city_warp" then
        --transfer player to their homepage
        local exit_object = Net.get_object_by_id(net_city_map_id,test_net_city_homepage_exit_id)
        local x = exit_object.x
        local y = exit_object.y
        local z = exit_object.z
        local direction = exit_object.custom_properties.direction
        Net.transfer_player(event.player_id, net_city_map_id, true, x,y,z,direction)
    end
end

function HomePage:Handle_object_interaction(event)
    local A_press = event.button == 0
    if A_press then
        if not self.current_operation then
            if self.editor_id == event.player_id then
                self:Start_moving_operation(event.object_id)
            end
        end
    end
end

function HomePage:Start_moving_operation(object_id)
    local original_object_info = Net.get_object_by_id(self.area_id, object_id)
    local temporary_object_id = Net.create_object(self.area_id, original_object_info)
    self.current_operation = {
        type="moving",
        object_id=object_id,
        temporary_object_id=temporary_object_id,
        tic_func=function(hp)
            local player_position = Net.get_player_position(hp.editor_id)
            local player_facing = Net.get_player_direction(hp.editor_id)
            local temp_object_id = hp.current_operation.temporary_object_id
            local direction_offset = Direction.to_vector(player_facing)
            local new_x = player_position.x + direction_offset.x
            local new_y = player_position.y + direction_offset.y
            local new_z = player_position.z
            Net.move_object(hp.area_id,temp_object_id,new_x,new_y,new_z)
        end,
        cancel_func=function(hp)
            local temp_object_id = hp.current_operation.temporary_object_id
            Net.remove_object(hp.area_id, temp_object_id)
        end,
        interact_func=function (hp,event)
            local A_press = event.button == 0
            if A_press then
                local object_id = hp.current_operation.object_id
                local temp_object_id = hp.current_operation.temporary_object_id
                local temp_object_info = Net.get_object_by_id(hp.area_id, temp_object_id)
                Net.remove_object(hp.area_id, temp_object_id)
                Net.move_object(hp.area_id,object_id,temp_object_info.x,temp_object_info.y,temp_object_info.z)
                print('finished moving object')
                hp.current_operation = nil
            end
        end
    }
    print('started moving object')
end

function HomePage:Handle_tick(event)
    if self.editor_id and self.current_operation then
        self.current_operation.tic_func(self)
    end
end

function HomePage:Save()
    local player_memory = ezmemory.get_player_memory(self.player_safe_secret)
    player_memory.home_page_data = Net.map_to_string(self.area_id)
    if self:Scan_and_validate() then
        ezmemory.save_player_memory(self.player_safe_secret)
    end
end

function HomePage:Scan_and_validate()
    --parses the homepage to extract all the key objects used
    local object_ids = Net.list_objects(self.area_id)
    for index, object_id in ipairs(object_ids) do
        local object = Net.get_object_by_id(self.area_id, object_id)
        if object.custom_properties["hp_object_type"] then
            if object.custom_properties["hp_object_type"] == "home_warp" then
                self.home_warp_object = object
            end
            if object.custom_properties["hp_object_type"] == "city_warp" then
                self.city_warp_object = object
            end
        end
    end
end

function HomePage:Transfer_player(player_id)
    --transfer player to their homepage
    local x = self.home_warp_object.x+1
    local y = self.home_warp_object.y+1
    local z = self.home_warp_object.z
    local direction = self.home_warp_object.custom_properties.direction
    Net.transfer_player(player_id, self.area_id, true, x,y,z,direction)
end

return HomePage