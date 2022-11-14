local helpers = require('scripts/ezlibs-scripts/helpers')
local ezmemory = require('scripts/ezlibs-scripts/ezmemory')
local urlencode = require('scripts/ezlibs-scripts/urlencode')

local net_city_map_id = 'default'
local test_net_city_homepage_exit_id = 2193

local homepage_menu_color = {r=20,g=50,b=200}
local edit_mode_color = {r=100,g=100,b=100}

local create_move_selection_operation = require('scripts/ezlibs-custom/homepage_operations/move_selection')
local create_store_object_operation = require('scripts/ezlibs-custom/homepage_operations/store_object')
local crate_place_object_operation = require('scripts/ezlibs-custom/homepage_operations/place_object')

HomePage = {}

local function create_bbs_option(text)
    return {id= text, read= true, title=text, author= ""}
end
    
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
    self:Cancel_current_operation()
    self:Finish_editing()
    self:Save()
end

function HomePage:Set_current_operation(operation)
    if self.current_operation then
        self.current_operation.cancel_func()
    end
    self.current_operation = operation
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
    local posts = {}
    local menu_color = homepage_menu_color
    local menu_title = "HomePage Options"
    if self.editor_id then
        menu_color = edit_mode_color
        menu_title = "Editing"
        if self.current_operation then
            menu_title = menu_title.." ("..self.current_operation.name..")"
        end
        table.insert(posts, create_bbs_option("Move Objects"))
        table.insert(posts, create_bbs_option("Place Objects"))
        table.insert(posts, create_bbs_option("Store Objects"))
        table.insert(posts, create_bbs_option("Save Changes"))
        table.insert(posts, create_bbs_option("Discard Changes"))
    else
        table.insert(posts, create_bbs_option("Edit Homepage"))
    end
    local menu_board = Net.open_board(player_id, menu_title,menu_color,posts)
    menu_board:on("post_selection", function (post)
        print('postselection',post)
        Net.close_bbs(player_id)
        if post.post_id == "Save Changes" then
            self:Finish_editing_and_save()
        elseif post.post_id == "Discard Changes" then
            self:Cancel_editing()
        elseif post.post_id == "Edit Homepage" then
            self:Start_editing(player_id)
            self:Set_current_operation(create_move_selection_operation(self))
        elseif post.post_id == "Move Objects" then
            self:Set_current_operation(create_move_selection_operation(self))
        elseif post.post_id == "Store Objects" then
            self:Set_current_operation(create_store_object_operation(self))
        elseif post.post_id == "Place Objects" then
            self:Set_current_operation(crate_place_object_operation(self))
        end
    end)
end

function HomePage:Handle_tile_interaction(event)
    --Allow owner to open the homepage menu
    local player_safe_secret = helpers.get_safe_player_secret(event.player_id)
    local is_owner = player_safe_secret == self.player_safe_secret
    local L_press = event.button == 1
    if L_press then
        if not is_owner then
            await(Async.message_player(event.player_id, "You dont have permission to manage this page"))
            return
        end
        self:Open_menu(event.player_id)
        return
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

function HomePage:Save()
    local player_memory = ezmemory.get_player_memory(self.player_safe_secret)
    player_memory.home_page_data = Net.map_to_string(self.area_id)
    local valitation_error = self:Scan_and_validate()
    if valitation_error == nil then
        ezmemory.save_player_memory(self.player_safe_secret)
    else
        Net.message_player(self.editor_id, "Error saving homepage, resolve the following before saving again : "..valitation_error)
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