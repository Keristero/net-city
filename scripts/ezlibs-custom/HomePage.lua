local helpers = require('scripts/ezlibs-scripts/helpers')
local ezmemory = require('scripts/ezlibs-scripts/ezmemory')
local urlencode = require('scripts/ezlibs-scripts/urlencode')
local home_page_helpers = require("scripts/ezlibs-custom/home_page_helpers")
local ezmenus = require('scripts/ezlibs-scripts/ezmenus')
local Direction = require("scripts/ezlibs-scripts/direction")

local net_city_map_id = 'default'
local test_net_city_homepage_exit_id = 2431

local homepage_menu_color = {r=20,g=50,b=200}
local edit_mode_color = {r=100,g=100,b=100}
local storage_menu_color = {r=40,g=150,b=40}
local direction_menu_color = {r=100,g=100,b=40}

local classes_to_disable = {"Home Warp","Custom Warp","Server Warp"}

--Operations
local create_move_selection_operation = require('scripts/ezlibs-custom/homepage_operations/move_selection')
local create_store_object_operation = require('scripts/ezlibs-custom/homepage_operations/store_object')
local create_place_object_operation = require('scripts/ezlibs-custom/homepage_operations/place_object')
local create_place_tile_operation = require('scripts/ezlibs-custom/homepage_operations/place_tile')
local create_store_tile_operation = require('scripts/ezlibs-custom/homepage_operations/store_tile')
local create_configure_object_operation = require('scripts/ezlibs-custom/homepage_operations/configure_object')
local create_inspect_object_operation = require('scripts/ezlibs-custom/homepage_operations/inspect_object')

--Entities
local PageWarp = require('scripts/ezlibs-custom/homepage_entities/PageWarp')
local FlavourText = require('scripts/ezlibs-custom/homepage_entities/FlavourText')
local NaviSpot = require('scripts/ezlibs-custom/homepage_entities/NaviSpot')
local BBS = require('scripts/ezlibs-custom/homepage_entities/BBS')
local ServerWarp = require('scripts/ezlibs-custom/homepage_entities/ServerWarp')
local home_page_entities = {
    page_warp = PageWarp,
    flavour_text = FlavourText,
    navi_spot = NaviSpot,
    bbs = BBS,
    server_warp = ServerWarp
}


--[[ local page_warps = {}

local function load_global_homepage_data()
    local all_player_memory = ezmemory.get_all_player_memory()
    for safe_secret, player_memory in pairs(all_player_memory) do
        if player_memory.hp_page_warps then
            for warp_secret_code, warp_object_id in pairs(player_memory.hp_page_warps) do
                page_warps[warp_secret_code] = warp_object_id
            end
        else
            player_memory.hp_page_warps = {}
        end
    end
end

load_global_homepage_data() ]]

HomePage = {}
    
function HomePage:new(player_safe_secret)
    local o = {}
    local home_page_id = player_safe_secret --TODO change this to a hash of the player id
    o.area_id = home_page_id
    o.player_safe_secret =  player_safe_secret
    self.__index = self
    return setmetatable(o, self)
end

function HomePage:Initialize_from_memory()
    local player_memory = ezmemory.get_player_memory(self.player_safe_secret)
    local validation_error = "failed to load home page from memory"
    pcall(function()
        Net.update_area(self.area_id, player_memory.home_page_data)
        validation_error = self:Scan_and_validate()
    end)
    if validation_error == nil then
        self:Upgrade(home_page_helpers.base_homepage_map_id)
        --print('loaded home page from memory')
        self:Update_public_status()
    else
        error('corrupt home page data for '..self.player_safe_secret..' error= '..validation_error)
        return false
    end
    return true
end

function HomePage:Register_unique_page_warp(object_id)
    --TODO this will eventually run out of codes and get stuck forever
    local new_random_code_string = tostring(math.random(100000,999999))
    while home_page_helpers.homepage_map_memory.warp_codes[new_random_code_string] do
        new_random_code_string = tostring(math.random(100000,999999))
    end
    home_page_helpers.homepage_map_memory.warp_codes[new_random_code_string] = {area_id=self.area_id,object_id=object_id}
    ezmemory.save_area_memory(home_page_helpers.base_homepage_map_id)
    return new_random_code_string
end

function HomePage:Remove_unique_page_warp(object)
    --TODO this will eventually run out of codes and get stuck forever
    local code_to_remove = object.custom_properties.warp_code
    home_page_helpers.homepage_map_memory.warp_codes[code_to_remove] = nil
    ezmemory.save_area_memory(home_page_helpers.base_homepage_map_id)
end

function HomePage:Initialize_from_template(template_map)
    Net.clone_area(template_map, self.area_id)
    self:Refresh_page_elements()
    self:Save()
end

function HomePage:Upgrade(template_map)
    print("[Homepage] checking if HP needs upgrade")
    --deep copy player memory so that we can restore it if they decide to cancel their edits
    local player_memory = ezmemory.get_player_memory(self.player_safe_secret)
    self.player_memory_backup = helpers.deep_copy(player_memory)
    
    local latest_tilesets = Net.list_tilesets(template_map)
    local current_tilesets = Net.list_tilesets(self.area_id)
    if #current_tilesets ~= #latest_tilesets then
        print("[Homepage] starting HP upgrade")
        local latest_hp = Net.map_to_string(home_page_helpers.base_homepage_map_id)
        player_memory.home_page_data = home_page_helpers.upgrade_homepage_xml(player_memory.home_page_data,latest_hp)
        ezmemory.save_player_memory(self.player_safe_secret)
        Net.update_area(self.area_id, player_memory.home_page_data)
    end
end

function HomePage:Finish_editing_and_save()
    local editor_id = self.editor_id
    self:Cancel_current_operation()
    self:Finish_editing()
    self:Refresh_page_elements()
    self:Save(editor_id)
end

function HomePage:Set_current_operation(operation)
    if self.current_operation then
        self.current_operation.cancel_func()
    end
    self.current_operation = operation
end

function HomePage:Enable_class(object_id)
    local object = Net.get_object_by_id(self.area_id, object_id)
    if object.class:sub(-8) == "DISABLED" then
        Net.set_object_class(self.area_id, object_id, object.class:sub(0,#object.class-8))
        if object.custom_properties["enabled_frame_index"] then
            local tileset = Net.get_tileset_for_tile(self.area_id, object.data.gid)
            local first_gid = tileset.first_gid
            object.data.gid = first_gid+tonumber(object.custom_properties["enabled_frame_index"])
            Net.set_object_data(self.area_id, object_id, object.data)
        end
    end
end

function HomePage:Disable_class(object_id)
    local object = Net.get_object_by_id(self.area_id, object_id)
    if helpers.indexOf(classes_to_disable, object.class) ~= nil then
        Net.set_object_class(self.area_id, object_id, object.class.."DISABLED")
        if object.custom_properties["disabled_frame_index"] then
            local tileset = Net.get_tileset_for_tile(self.area_id, object.data.gid)
            local first_gid = tileset.first_gid
            object.data.gid = first_gid+tonumber(object.custom_properties["disabled_frame_index"])
            Net.set_object_data(self.area_id, object_id, object.data)
        end
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
    self:Refresh_page_elements()
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
            table.insert(posts, helpers.create_bbs_option("Place Tiles"))
            table.insert(posts, helpers.create_bbs_option("Store Objects"))
            table.insert(posts, helpers.create_bbs_option("Store Tiles"))
            table.insert(posts, helpers.create_bbs_option("Configure Objects"))
            table.insert(posts, helpers.create_bbs_option("Save Changes"))
            table.insert(posts, helpers.create_bbs_option("Discard Changes"))
            table.insert(posts, helpers.create_bbs_option("Inspect Objects"))
        else
            table.insert(posts, helpers.create_bbs_option("Edit Homepage"))
        end
        local menu_board = ezmenus.open_menu(player_id, menu_title,menu_color,posts)
        local post_id = await(menu_board.selection_once())
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
        elseif post_id == "Store Tiles" then
            local removal_cursor_info = home_page_helpers.gid[home_page_helpers.name_to_gid["RemovalCursor"]]
            self:Set_current_operation(create_store_tile_operation(self,removal_cursor_info))
        elseif post_id == "Place Tiles" then
            local decoration_info = await(self:Storage_menu_async_selection(home_page_helpers.tiles))
            if decoration_info then
                self:Set_current_operation(create_place_tile_operation(self,decoration_info))
            end
        elseif post_id == "Place Objects" then
            local decoration_info = await(self:Storage_menu_async_selection(home_page_helpers.objects))
            if decoration_info then
                self:Set_current_operation(create_place_object_operation(self,decoration_info))
            end
        elseif post_id == "Configure Objects" then
            self:Set_current_operation(create_configure_object_operation(self))
        elseif post_id == "Inspect Objects" then
            self:Set_current_operation(create_inspect_object_operation(self))
        end
    end)
end

function HomePage:Storage_menu_async_selection(decoration_collection)
    return async(function ()
        local player_memory = ezmemory.get_player_memory(self.player_safe_secret)
        local player_decoration_objects = {}
        local bbs_options = {}
        --Count how many of each decoration the player has
        for object_gid, decoration_object in pairs(decoration_collection) do
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
                local item_name = decoration_collection[object_gid].name
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
        local decoration_info = home_page_helpers.gid[place_object_gid]
        await(menu.close_async())
        return decoration_info
    end)
end

function HomePage:Replace_tile(new_tile_gid,x,y,z,flipped_h,flipped_v,rotated)
    local new_tile_info = home_page_helpers.gid[tonumber(new_tile_gid)]
    local existing_tile = Net.get_tile(self.area_id, x, y, z)
    local existing_decoration_info = home_page_helpers.gid[tonumber(existing_tile.gid)]
    if tonumber(existing_tile.gid) == tonumber(new_tile_gid) then
        return
    end
    if new_tile_info then
        ezmemory.remove_player_item(self.editor_id, new_tile_info.name, 1)
    end
    Net.set_tile(self.area_id, x, y, z, new_tile_gid,flipped_h,flipped_v,rotated)
    if existing_decoration_info then
        ezmemory.give_player_item(self.editor_id, existing_decoration_info.name, 1)
    end
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

function HomePage:Handle_object_placement(new_object_id,is_reconfigure)
    return async(function()
        local object = Net.get_object_by_id(self.area_id,new_object_id)
        local hp_object_type = object.custom_properties["hp_object_type"]
        local HomePageEntity = nil
        if hp_object_type then
            HomePageEntity = home_page_entities[object.custom_properties["hp_object_type"]]
        end
        if HomePageEntity and HomePageEntity.pre_configure then
            print("[Homepage] pre_configure for object: " .. hp_object_type)
            HomePageEntity.pre_configure(self, object)
        end
        await(self:Prompt_for_custom_properties(new_object_id))
        if not is_reconfigure then
            if HomePageEntity and HomePageEntity.post_placement then
                print("[Homepage] post_placement for object: " .. hp_object_type)
                HomePageEntity.post_placement(self, object)
            end
        end
    end)
end

function HomePage:List_object_properties_to_player(new_object_id)
    return async(function()
        local object = Net.get_object_by_id(self.area_id,new_object_id)
        for prop_name, prop_value in pairs(object.custom_properties) do
            if prop_name == "hp_object_type" or prop_name == "disabled_frame_index" or prop_name == "enabled_frame_index" then
                goto continue
            end
            if object.custom_properties[prop_name.."_default"] then
                goto continue
            end
            await(Async.message_player(self.editor_id,prop_name.."="..prop_value))
            ::continue::
        end
    end)
end

function HomePage:Handle_custom_warp(event)
    local object = Net.get_object_by_id(self.area_id,event.object_id)
    local hp_object_type = object.custom_properties["hp_object_type"]
    if hp_object_type == "city_warp" then
        --transfer player to net city
        local exit_object = Net.get_object_by_id(net_city_map_id,test_net_city_homepage_exit_id)
        local x = exit_object.x
        local y = exit_object.y
        local z = exit_object.z
        local direction = exit_object.custom_properties.direction
        Net.transfer_player(event.player_id, net_city_map_id, true, x,y,z,direction)
        self:Cancel_editing()
        return
    elseif hp_object_type == "server_warp" then
        local address = object.custom_properties["address"]
        local port = tonumber(object.custom_properties["port"])
        local data = object.custom_properties["data"]
        if address and port then
            Net.transfer_server(event.player_id, address, port, true,data)
        end
        return
    elseif hp_object_type == "page_warp" then
        local target_code = object.custom_properties["target_code"]
        home_page_helpers.transfer_player_to_correct_homepage(event.player_id,target_code)
        return
    end
    --Or default back to warping the player to their entrance
    home_page_helpers.transfer_player_to_correct_homepage(event.player_id)
end

function HomePage:Prompt_for_custom_properties(object_id)
    return async(function ()
        local object = Net.get_object_by_id(self.area_id,object_id)
        local tileset = Net.get_tileset_for_tile(self.area_id, object.data.gid)
        local first_gid = tileset.first_gid
        local decoration_info = home_page_helpers.objects[first_gid]
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
                elseif prop_value:sub(0,4) == "bool" then
                    new_value = await(Async.quiz_player(self.editor_id,"true","false"))
                elseif prop_value:sub(0,6) == "friend" then
                    new_value = await(self:Friend_prompt())
                else
                    new_value = await(Async.prompt_player(self.editor_id,nil,default_value))
                    --sanatize the input so it does not break XML
                    new_value = home_page_helpers.sanatize_user_input(new_value)
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
    local A_press = event.button == 0
    if L_press then
        self:Try_open_menu(event)
        return
    end

    if self.current_operation then
        if self.editor_id == event.player_id then
            self.current_operation.object_interact_func(event)
            return
        end
    end

    if A_press then
        self:Async_object_interaction(event)
        return
    end
end

function HomePage:Async_object_interaction(event)
    return async(function ()
        local object = Net.get_object_by_id(self.area_id,event.object_id)
        if object.custom_properties["hp_object_type"] then
            local HomePageEntity = home_page_entities[object.custom_properties["hp_object_type"]]
            if HomePageEntity and HomePageEntity.on_async_object_interaction then
                HomePageEntity.on_async_object_interaction(self, object, event)
            end
        end
    end)
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
        --update area name
        local player_name_safe = urlencode.string(ezmemory.get_player_name_from_safesecret(self.player_safe_secret))
        local new_area_name = player_name_safe.." HP"
        Net.set_area_name(self.area_id,new_area_name)
        --save area
        player_memory.home_page_data = Net.map_to_string(self.area_id)
        ezmemory.save_player_memory(self.player_safe_secret)
    else
        error("[Homepage] validation error saivng homepage with no last_editor_id!")
        self:Start_editing(last_editor_id)
        Net.message_player(last_editor_id, "Error saving homepage, resolve the following before saving again : "..self.valitation_error)
    end
end

function HomePage:Update_public_status()
    if self.city_warp_object == nil then
        --No city warp object, so no public homepage
        home_page_helpers.public_homepages_by_area_id[self.area_id] = nil
        return
    end
    local public_name = self.city_warp_object.custom_properties["public_name"]
    local player_name_safe = urlencode.string(ezmemory.get_player_name_from_safesecret(self.player_safe_secret))
    self.player_name = player_name_safe
    local should_be_public = (public_name ~= nil and public_name ~= "" and player_name_safe ~= nil and player_name_safe ~= "")
    print('should be public: ',should_be_public,public_name,player_name_safe)
    if should_be_public then
        home_page_helpers.public_homepages_by_area_id[self.area_id] = {
            title = public_name,
            author = player_name_safe
        }
    else 
        home_page_helpers.public_homepages_by_area_id[self.area_id] = nil
    end
end

function HomePage:Refresh_page_elements()
    if self.editor_id ~= nil then
        --Dont refresh the page while it is being edited
        return
    end
    local object_ids = Net.list_objects(self.area_id)
    for index, object_id in ipairs(object_ids) do
        local object = Net.get_object_by_id(self.area_id, object_id)
        if object.custom_properties["hp_object_type"] then
            local HomePageEntity = home_page_entities[object.custom_properties["hp_object_type"]]
            if HomePageEntity and HomePageEntity.on_refresh then
                HomePageEntity.on_refresh(self, object)
            end
        end
    end
    --make area public again (if it should be)
    self:Update_public_status()
end

function HomePage:Scan_and_validate()
    --parses the homepage to extract all the key objects used
    self.home_warp_object = nil
    self.city_warp_object = nil
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

function HomePage:Transfer_player(player_id,target_object_id)
    --default to home page entry
    local target_object = self.home_warp_object
    if target_object_id then
        --if an object_id is specified, warp to that
        target_object = Net.get_object_by_id(self.area_id,target_object_id)
    end
    --transfer player to target object
    local x = target_object.x+1
    local y = target_object.y+1
    local z = target_object.z
    local direction = target_object.custom_properties.direction
    self:Refresh_page_elements()--Refresh the page before transfering a player in
    Net.transfer_player(player_id, self.area_id, true, x,y,z,direction)
end

return HomePage