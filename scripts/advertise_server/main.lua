local json = require('scripts/advertise_server/json')
local base64 = require('scripts/advertise_server/base64')
local urlencode = require('scripts/advertise_server/urlencode')
local map_overrides = require('scripts/advertise_server/data/map_overrides')
local folder_path = "scripts/advertise_server/data/"
local advertisement_json_path = folder_path.."advertisement.json"
local secret_keys_json_path = folder_path.."secret_keys.json"
local minimum_sync_interval = 5
local maximum_sync_interval = 60*60
local public_info = {
    pending_fields={},
    time_since_last_sync={}
}
local listservers = {}
local secret_keys = {}
local server_ids = {}
local last_map_list = {}
local whitelist_text_paths = {} --[server_id] = path or nil

--trackers for live updates
local player_maps = {} --[hashed_id] = map_id
local player_id_hashes = {} --[player_id] = hashed_id

local function hash_id(str)
    local h1 = 0x7A6D
    local h2 = 0xCB2F
    for i = 1, #str do
        local b = string.byte(str, i)
        h1 = (h1 * 31 + b) % 0xFFFFFF
        h2 = (h2 * 37 + b) % 0xFFFFFF
    end
    return string.format("%06x%06x", h1, h2)
end

local function count_player_maps()
    local count = 0
    for _ in pairs(player_maps) do
        count = count + 1
    end
    return count
end

--shorthands for async stuff.
local function async(p)
    local co = coroutine.create(p)
    return Async.promisify(co)
end
local function await(v) return Async.await(v) end
local function load_image_data(path)
    print('[advertise_server] loading icon ',path)
    local f = io.open(path, "rb")
    local icon_data = f:read("*a")
    f:close()
    return icon_data
end
local function save_image_data(path,data)
    local f = io.open(path, "wb")
    f:write(data)
    f:flush()
    f:close()
end

local function sync_player_info_for_all_servers()
    set_pending_field_for_all_servers("player_maps",player_maps)
    set_pending_field_for_all_servers("online_players",count_player_maps())
end

--Event handlers
Net:on("player_connect", function(event)
    local hashed = hash_id(event.player_id)
    player_id_hashes[event.player_id] = hashed
    player_maps[hashed] = 'default'--when a landing script transfers the player this will be immediately overwritten correctly (i think)
    sync_player_info_for_all_servers()
end)

Net:on("player_disconnect", function(event)
    local hashed = player_id_hashes[event.player_id]
    if hashed then
        player_maps[hashed] = nil
        player_id_hashes[event.player_id] = nil
    end
    sync_player_info_for_all_servers()
end)

Net:on("player_area_transfer", function(event)
    local hashed = player_id_hashes[event.player_id]
    if hashed then
        local player_area = Net.get_player_area(event.player_id)
        player_maps[hashed] = player_area
        sync_player_info_for_all_servers()
    end
end)

function set_pending_field_for_all_servers(field_name,value)
    for server_id, _ in pairs(public_info.time_since_last_sync) do
        set_pending_field(server_id,field_name,value)
    end
end

function set_pending_field(server_id,field_name,value)
    if not public_info.pending_fields[server_id] then
        public_info.pending_fields[server_id] = {}
    end
    public_info.pending_fields[server_id][field_name] = value
    public_info.time_since_last_sync[server_id] = maximum_sync_interval+1
end

function clear_pending_fields(server_id)
    public_info.pending_fields[server_id] = {}
end

function get_whitelist_text_path(server_id)
    return whitelist_text_paths[server_id]
end

function write_whitelist_file(path, content)
    local temp_path = path .. ".tmp"
    local ok, err = pcall(function()
        local f = io.open(temp_path, "w")
        if f then
            f:write(content)
            f:flush()
            f:close()
            os.rename(temp_path, path)
            print('[advertise_server] whitelist written to '..path)
        else
            print('[advertise_server] ERROR: could not open whitelist file for writing: '..temp_path)
        end
    end)
    if not ok then
        print('[advertise_server] ERROR: failed to write whitelist: '..tostring(err))
    end
end

function build_payload(server_id)
    local payload = {
        server_id=server_id,
        fields={}
    }
    for field_name, value in pairs(public_info.pending_fields[server_id]) do
        payload.fields[field_name] = value
    end
    clear_pending_fields(server_id)
    return payload
end

function get_secret_key(server_id,listserver_name)
    if not secret_keys[listserver_name] then
        return nil
    end
    if not secret_keys[listserver_name][server_id] then
        return nil
    end
    return secret_keys[listserver_name][server_id]
end

function save_secret_key(file_path,server_id,listserver_name,secret_key)
    return async(function ()
        if not secret_keys[listserver_name] then
            secret_keys[listserver_name] = {}
        end
        if not secret_keys[listserver_name][server_id] then
            secret_keys[listserver_name][server_id] = {}
        end
        secret_keys[listserver_name][server_id] = secret_key
        await(Async.write_file(file_path,json.encode(secret_keys)))
    end)
end

function sync_to_servers(server_id)
    return async(function ()
        print('[advertise_server] syncing '..server_id..' to server lists...')
        local payload = build_payload(server_id)
        local headers = {}
        headers["Content-Type"] = "application/json"
        --for each serverlist server
        for listserver_name, url in pairs(listservers) do
            payload.secret_key = get_secret_key(server_id,listserver_name)
            local res = await(Async.request(url, {
                method = "POST",
                headers = headers,
                body = json.encode(payload)
            }))
            if res then
                local data = json.decode(res.body)
                if data and data.secret_key ~= nil then
                    await(save_secret_key(secret_keys_json_path,server_id,listserver_name,data.secret_key))
                end
                -- Handle whitelist response
                if data and data.whitelist ~= nil then
                    local whitelist_path = get_whitelist_text_path(server_id)
                    if whitelist_path then
                        write_whitelist_file(whitelist_path, data.whitelist)
                    end
                end
            end
        end
        public_info.time_since_last_sync[server_id] = 0
    end)
end

local function read_json(file_path)
    return async(function ()
        local data = {}
        pcall(function()
            data = json.decode(await(Async.read_file(file_path)))
            if data == nil then
                data = {}
            end
        end)
        return data
    end)
end

local function load_all_images_for_advertisements(advertisements)
    return async(function ()
        for i, advertisement in ipairs(advertisements) do
            if advertisement.icon then
                local image_path = "./"..folder_path..advertisement.icon
                local image_data = load_image_data(image_path)
                set_pending_field(advertisement.unique_server_id,"b64_image",base64.encode(image_data))
            end
        end
    end)
end

local function initialize_pending_fields_from_advertisements(advertisements)
    for i, advertisement in ipairs(advertisements) do
        --Some ephemral fields need defaults
        local server_id = advertisement.unique_server_id
        for field_name, value in pairs(advertisement) do
            set_pending_field(server_id,field_name,value)
        end
        --Reset player count to 0 since the server just started
        set_pending_field(server_id,"player_maps",player_maps)
        set_pending_field(server_id,"online_players",0)
        --Capture whitelist text path for this server
        if advertisement.whitelist_text_path then
            whitelist_text_paths[server_id] = advertisement.whitelist_text_path
        end
    end
end

local function build_server_map(areas)
    local server_map = {}
    for i, area_id in ipairs(areas) do
        local area_p = Net.get_area_custom_properties(area_id)
        if not server_map[area_id] then
            --initialize server map
            server_map[area_id] = {
                name=area_p["Name"],
                l={},--local connections (same server)
                r={}--remote connections (other servers)
            }
        end
        local map_info = server_map[area_id]
        local objects = Net.list_objects(area_id)
        for j, object_id in ipairs(objects) do
            local object = Net.get_object_by_id(area_id,object_id)
            map_overrides.process_object(area_id, map_info, object)
        end
    end
    return server_map
end

function advertise_map_if_it_changed(advertisements)
    local areas = Net.list_areas()
    if #areas == #last_map_list then
        last_map_list = areas
        return
    end
    local server_map = build_server_map(areas)
    for i, advertisement in ipairs(advertisements) do
        if advertisement.advertise_map then
            set_pending_field(advertisement.unique_server_id,"map",server_map)
        end
    end
    last_map_list = areas
end

--load configuration
async(function()
    print('[advertise_server] loading...')
    --load secret keys
    secret_keys = await(read_json(secret_keys_json_path))
    --load advertisements
    local data = await(read_json(advertisement_json_path))
    local advertisements = data.advertisements
    listservers = data.listservers
    initialize_pending_fields_from_advertisements(advertisements)
    --load images
    await(load_all_images_for_advertisements(advertisements))
    --load sever map
    advertise_map_if_it_changed(advertisements)
    while true do
        --every minimum_sync_interval, we send all the batched changes
        await(Async.sleep(minimum_sync_interval))
        advertise_map_if_it_changed(advertisements)
        for unique_server_id, time in pairs(public_info.time_since_last_sync) do
            if time > maximum_sync_interval then
                sync_to_servers(unique_server_id)
            else
                public_info.time_since_last_sync[unique_server_id] = time + 10
            end
        end
    end
end)