local helpers = require('scripts/ezlibs-scripts/helpers')
local ezmenus = require('scripts/ezlibs-scripts/ezmenus')
local homepage_bbs_color = {r=200,g=200,b=200}
local entity = {}


entity.on_async_object_interaction = function (homepage,object,event)
    return async(function ()
        local posts = {}
        local menu_color = homepage_bbs_color
        local menu_title = object.custom_properties["topic"]
        local player_safe_secret = helpers.get_safe_player_secret(event.player_id)
        local is_owner = player_safe_secret == homepage.player_safe_secret
        local public_posting = object.custom_properties["public_posting"] == "true"
        if is_owner then
            table.insert(posts, helpers.create_bbs_option("View BBS"))
            table.insert(posts, helpers.create_bbs_option("Clear BBS"))
        end

        local menu_board = ezmenus.open_menu(event.player_id, menu_title,menu_color,posts)
    end)
end

return entity