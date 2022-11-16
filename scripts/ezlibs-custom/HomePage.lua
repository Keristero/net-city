local helpers = require('scripts/ezlibs-scripts/helpers')
local ezmemory = require('scripts/ezlibs-scripts/ezmemory')
local urlencode = require('scripts/ezlibs-scripts/urlencode')
local home_page_decorations = require("scripts/ezlibs-custom/home_page_decorations")
local ezmenus = require('scripts/ezlibs-scripts/ezmenus')
local Direction = require("scripts/ezlibs-scripts/direction")

local net_city_map_id = 'default'
local test_net_city_homepage_exit_id = 2193

local homepage_menu_color = {r=20,g=50,b=200}
local edit_mode_color = {r=100,g=100,b=100}
local storage_menu_color = {r=40,g=150,b=40}
local direction_menu_color = {r=100,g=100,b=40}

local classes_to_disable = {"Home Warp","Custom Warp","Server Warp"}

local create_move_selection_operation = require('scripts/ezlibs-custom/homepage_operations/move_selection')
local create_store_object_operation = require('scripts/ezlibs-custom/homepage_operations/store_object')
local create_place_object_operation = require('scripts/ezlibs-custom/homepage_operations/place_object')

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
    local player_memory = ezmemory.get_player_memory(self.player_safe_secret)
    Net.update_area(self.area_id, player_memory.home_page_data)
    local validation_error = self:Scan_and_validate()
    if validation_error == nil then
        print('loaded home page from memory')
    else
        error('corrupt home page data for '..self.player_safe_secret..' error= '..validation_error)
    end
end

function HomePage:Initialize_from_template(template_map)
    Net.clone_area(template_map, self.area_id)
    local player_name_safe = urlencode.string(Net.get_player_name(self.player_id))
    local new_area_name = player_name_safe.." HP"
    Net.set_area_name(self.area_id,new_area_name)
    self:Save()
    print('generated new home page from base_homepage.tmx')
end

function HomePage:Finish_editing_and_save()
    local editor_id = self.editor_id
    self:Cancel_current_operation()
    self:Finish_editing()
    self:Save(editor_id)
end

function HomePage:Set_current_operation(operation)
    if self.current_operation then
        self.current_operation.cancel_func()
    end
    self.current_operation = operation
end

function HomePage:Enable_class(object_id)
    local object_info = Net.get_object_by_id(self.area_id, object_id)
    if object_info.class:sub(-8) == "DISABLED" then
        Net.set_object_class(self.area_id, object_id, object_info.class:sub(0,#object_info.class-8))
        print("Re Enabled ",object_info.class)
    end
end

function HomePage:Disable_class(object_id)
    local object_info = Net.get_object_by_id(self.area_id, object_id)
    if helpers.indexOf(classes_to_disable, object_info.class) ~= nil then
        Net.set_object_class(self.area_id, object_id, object_info.class.."DISABLED")
        print("disabled ",object_info.class)
    end
end

function HomePage:Finish_editing()
    self.editor_id = nil
    local area_objects = Net.list_objects(self.area_id)
    for index, object_id in ipairs(area_objects) do
        self:Enable_class(object_id)
    end
end

function HomePage:Start_editing(player_id)
    self.editor_id = player_id
    local area_objects = Net.list_objects(self.area_id)
    for index, object_id in ipairs(area_objects) do
        self:Disable_class(object_id)
    end
    --deep copy player memory so that we can restore it if they decide to cancel their edits
    self.player_memory_backup = helpers.deep_copy(ezmemory.get_player_memory(self.player_safe_secret))
end

function HomePage:Cancel_editing()
    --finishes and discards changes
    self:Cancel_current_operation()
    self:Finish_editing()
    self:Initialize_from_memory()
    if self.player_memory_backup then
        ezmemory.dangerously_override_player_memory(self.player_safe_secret, self.player_memory_backup)
        self.player_memory_backup = nil
    end
end

function HomePage:Cancel_current_operation()
    self:Set_current_operation(nil)
end

function HomePage:Open_menu(player_id)
    return async(function ()
        local posts = {}
        local menu_color = homepage_menu_color
        local menu_title = "HomePage Options"
        if self.editor_id then
            menu_color = edit_mode_color
            menu_title = "Editing"
            if self.current_operation then
                menu_title = menu_title.." ("..self.current_operation.name..")"
            end
            table.insert(posts, helpers.create_bbs_option("Move Objects"))
            table.insert(posts, helpers.create_bbs_option("Place Objects"))
            table.insert(posts, helpers.create_bbs_option("Store Objects"))
            table.insert(posts, helpers.create_bbs_option("Save Changes"))
            table.insert(posts, helpers.create_bbs_option("Discard Changes"))
        else
            table.insert(posts, helpers.create_bbs_option("Edit Homepage"))
        end
        local menu_board = ezmenus.open_menu(player_id, menu_title,menu_color,posts)
        local post_id = await(menu_board.selection_once())
        print('post_id',post_id)
        await(menu_board.close_async())
        if post_id == "Save Changes" then
            self:Finish_editing_and_save()
        elseif post_id == "Discard Changes" then
            self:Cancel_editing()
        elseif post_id == "Edit Homepage" then
            self:Start_editing(player_id)
            self:Set_current_operation(create_move_selection_operation(self))
        elseif post_id == "Move Objects" then
            self:Set_current_operation(create_move_selection_operation(self))
        elseif post_id == "Store Objects" then
            self:Set_current_operation(create_store_object_operation(self))
        elseif post_id == "Place Objects" then
            local decoration_info = await(self:Storage_menu_async_selection())
            if decoration_info then
                self:Set_current_operation(create_place_object_operation(self,decoration_info))
            end
        end
    end)
end

function HomePage:Storage_menu_async_selection()
    return async(function ()
        local player_memory = ezmemory.get_player_memory(self.player_safe_secret)
        local player_decoration_objects = {}
        local bbs_options = {}
        --Count how many of each decoration the player has
        for object_gid, decoration_object in pairs(home_page_decorations.objects) do
            local item_id = ezmemory.get_item_id_by_name(decoration_object.name)
            local item_count = 0
            if player_memory.items[item_id] then
                item_count = player_memory.items[item_id]
            end
            player_decoration_objects[object_gid] = item_count
        end
        --Create a menu for selecting a decoration object
        for object_gid, item_count in pairs(player_decoration_objects) do
            if item_count > 0 then
                local item_name = home_page_decorations.objects[object_gid].name
                local option = {id=object_gid, title=item_name.." ("..item_count..")",read=true,author=""}
                table.insert(bbs_options, option)
            end
        end
        --Open the menu and wait for a selection
        local menu = ezmenus.open_menu(self.editor_id,"Storage",storage_menu_color,bbs_options)
        local post_id = await(menu.selection_once())
        if post_id == nil then
            return nil
        end
        local place_object_gid = tonumber(post_id)
        local decoration_info = home_page_decorations.gid[place_object_gid]
        print('selected gid=',place_object_gid)
        await(menu.close_async())
        return decoration_info
    end)
end

function HomePage:Try_open_menu(event)
    --Allow owner to open the homepage menu
    local player_safe_secret = helpers.get_safe_player_secret(event.player_id)
    local is_owner = player_safe_secret == self.player_safe_secret
    if not is_owner then
        await(Async.message_player(event.player_id, "You dont have permission to manage this page"))
        return
    end
    self:Open_menu(event.player_id)
end

function HomePage:Handle_tile_interaction(event)
    local L_press = event.button == 1
    if L_press then
        self:Try_open_menu(event)
    end
    --Handle current operation
    if self.current_operation then
        if self.editor_id == event.player_id then
            self.current_operation.tile_interact_func(event)
            return
        end
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
    if hp_object_type == "city_warp" then
        --transfer player to their homepage
        local exit_object = Net.get_object_by_id(net_city_map_id,test_net_city_homepage_exit_id)
        local x = exit_object.x
        local y = exit_object.y
        local z = exit_object.z
        local direction = exit_object.custom_properties.direction
        Net.transfer_player(event.player_id, net_city_map_id, true, x,y,z,direction)
        self:Cancel_editing()
    elseif hp_object_type == "server_warp" then
        local address = object.custom_properties["address"]
        local port = tonumber(object.custom_properties["port"])
        print(object.custom_properties)
        if address and port then
            Net.transfer_server(event.player_id, address, port, true,"From Homepage")
        end
    end
end

function HomePage:Prompt_for_custom_properties(object_id)
    return async(function ()
        local object = Net.get_object_by_id(self.area_id,object_id)
        local decoration_info = home_page_decorations.objects[object.data.gid]
        for prop_name, prop_value in pairs(decoration_info.custom_properties) do
            if prop_value:sub(-7) == "_prompt" then
                local default_value = ""
                if default_value:sub(-7) == "_prompt" then
                    default_value = object.custom_properties[prop_name]
                end
                if decoration_info.custom_properties[prop_name.."_default"] then
                    default_value = decoration_info.custom_properties[prop_name.."_default"]
                end
                local new_value = default_value
                await(Async.message_player(self.editor_id, "Set " .. prop_name .. ":"))
                if prop_value:sub(0,9) == "direction" then
                    new_value = await(self:Direction_prompt())
                else
                    new_value = await(Async.prompt_player(self.editor_id,nil,default_value))
                end
                Net.set_object_custom_property(self.area_id, object_id, prop_name, new_value)
            end
        end
    end)
end

function HomePage:Direction_prompt()
    return async(function ()
        local options = {}
        local return_dir = "Up"
        table.insert(options,helpers.create_bbs_option("Use current facing"))
        for index, direction_value in ipairs(Direction.list) do
            table.insert(options,helpers.create_bbs_option(direction_value))
        end
        local direction_menu = ezmenus.open_menu(self.editor_id,"Direction",direction_menu_color,options)
        local post_id = await(direction_menu.selection_once())
        await(direction_menu.close_async())
        if post_id == "Use current facing" then
            return_dir = Net.get_player_direction(self.editor_id)
        elseif post_id ~= nil then
            return_dir = post_id
        end
        return return_dir
    end)
end

function HomePage:Handle_object_interaction(event)
    local L_press = event.button == 1
    if L_press then
        self:Try_open_menu(event)
    end

    if self.current_operation then
        if self.editor_id == event.player_id then
            self.current_operation.object_interact_func(event)
            return
        end
    end
end

function HomePage:Handle_tick(event)
    if self.editor_id and self.current_operation then
        self.current_operation.tic_func()
    end
end

function HomePage:Save(last_editor_id)
    local player_memory = ezmemory.get_player_memory(self.player_safe_secret)
    self.valitation_error = self:Scan_and_validate()
    if self.valitation_error == nil then
        player_memory.home_page_data = Net.map_to_string(self.area_id)
        ezmemory.save_player_memory(self.player_safe_secret)
    else
        self:Start_editing(last_editor_id)
        Net.message_player(last_editor_id, "Error saving homepage, resolve the following before saving again : "..self.valitation_error)
    end
end

function HomePage:Scan_and_validate()
    --parses the homepage to extract all the key objects used
    self.home_warp_object = nil
    self.city_warp_object = nil
    print('scanning and validating')
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
    if self.home_warp_object == nil then
        return "Missing home warp"
    end
    if self.city_warp_object == nil then
        return "Missing city warp"
    end
    return nil
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