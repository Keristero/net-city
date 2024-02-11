
local daily_scenarios = {}
local dialogue_generator = require("scripts/ezlibs-custom/ai/dialogue_generator")
local eznpcs = require('scripts/ezlibs-scripts/eznpcs/eznpcs')

daily_scenarios.generate_for_map = function (map_id)
    return async(function ()
        local npc_name = "FireMan.EXE"
        local npc_description = "Mr Match's burning hot net navi"
        local response = await(dialogue_generator.generate_npc_dialouge(npc_name,npc_description))
        print(response)
    end)
end

return daily_scenarios