--
-- Net City map connection overrides for advertise_server
-- Customized for net-city's warp style (city_warp, lowercase property names, warp_code)
--

local overrides = {}

function overrides.process_object(area_id, map_info, object)
    local custom_p = object.custom_properties

    --local connections (ezlibs warps)
    if custom_p["Target Area"] then
        map_info.l[custom_p["Target Area"]] = {id=custom_p["Target Object"]}
    end

    --local connections (city warps back to default)
    if custom_p["hp_object_type"] == "city_warp" then
        map_info.l["default"] = {id=1}
    end

    --remote connections (server warps with lowercase properties and warp_code)
    local address = custom_p["address"]
    local port = custom_p["port"]
    if address and port then
        map_info.r[address..":"..port] = {data=custom_p["data"],incoming_data=custom_p["warp_code"]}
    end

    --extra map info
    if object.class == "Shop" then
        map_info.has_shop = true
    elseif object.class == "Board" then
        map_info.has_board = true
    end
end

return overrides
