local token = require("scripts/ezlibs-custom/ai/test_token")
local json = require('scripts/ezlibs-scripts/json')

local chatgpt = {}

chatgpt.call_function_from_prompt = function(functions,context_messages)
    return async(function()
        local url = "https://api.openai.com/v1/chat/completions"
        local headers = {}
        headers["Content-Type"] = "application/json"
        headers["Authorization"] = "Bearer "..token
        --prepare the request
        local body = {
            model = 'gpt-3.5-turbo',
            messages = context_messages,
            functions = functions
        }
        --send request and await response
        --print('[CHATGPT] sending req',body)
        local response = await(Async.request(url, {
            method = "POST",
            headers = headers,
            body = json.encode(body)
        }))
        --return response
        local data = json.decode(response.body)
        --append message history
        data.message_history = context_messages
        return data
    end)
end


return chatgpt