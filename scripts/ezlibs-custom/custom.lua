--local home_pages = require('scripts/ezlibs-custom/home_pages')
local daily_scenarios = require('scripts/ezlibs-custom/ai/daily_scenarios')

function test()
    return async(function ()
        await(daily_scenarios.generate_for_map('default'))
    end)
end

test()

return {}