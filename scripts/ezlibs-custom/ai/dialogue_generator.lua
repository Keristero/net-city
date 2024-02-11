local helpers = require('scripts/ezlibs-scripts/helpers')
local dialogue_types = require('scripts/ezlibs-scripts/eznpcs/dialogue_types')
local chatgpt = require('scripts/ezlibs-custom/ai/chatgpt')
local json = require('scripts/ezlibs-scripts/json')

local dialogue_generator = {}

--make a list of ai supported dialogue types
local ai_functions = {}
local ai_function_name_mappings = {}
local main_prompt_text = "You are a system for generating Mega Man Battle Network NPC dialogue using function calls"
for key, dialogue_type in pairs(dialogue_types) do
    if dialogue_type.ai_info then
        table.insert(ai_functions,dialogue_type.ai_info)
        ai_function_name_mappings[dialogue_type.ai_info.name] = dialogue_type.name
    end
end

local function response_is_valid(response)
    if response ~= nil and response["choices"] ~= nil and response["choices"][1] ~= nil and response["choices"][1]["finish_reason"] == "function_call" then
        return true
    end
    return false
end


dialogue_generator.generate_npc_dialouge = function(npc_name, npc_description,npc_surroundings)
    print("[dialogue_generator] generating dialogue for npc")
    local max_nodes = 5
    local state
    state = {
        generated_count = 0,
        generated_dialogues = {},
        add_node = function (node)
            state.generated_count = state.generated_count + 1
            node.id = state.generated_count
            table.insert(state.generated_dialogues,node)
            print('added node!',node)
        end,
        generate_node_async = function (options)
            return async(function ()
                if state.generated_count >= max_nodes then
                    return nil
                end
                local context_messages = {}
                --always include main context
                local main_system_context_message = {
                    role="system",
                    content=main_prompt_text.." you are currently role playing as NPC:("..npc_name..") description:("..npc_description..")"
                }
                table.insert(context_messages,main_system_context_message)
                if options.type == "standard" then
                    table.insert(context_messages,{
                        role="user",
                        content="say something this character might say on their day to day business"
                    })
                end
                if options.type == "follow_up" then
                    table.insert(context_messages,{
                        role="user",
                        content="say something this character would say after saying ("..options.previous..")"
                    })
                end
                if options.type == "question_answer_yes" then
                    table.insert(context_messages,{
                        role="assistant",
                        content=options.previous
                    })
                    table.insert(context_messages,{
                        role="user",
                        content="Yes"
                    })
                end
                if options.type == "question_answer_no" then
                    table.insert(context_messages,{
                        role="assistant",
                        content=options.previous
                    })
                    table.insert(context_messages,{
                        role="user",
                        content="No"
                    })
                end
                local response = await(chatgpt.call_function_from_prompt(ai_functions,context_messages))
                if response_is_valid(response) then
                    local call = response.choices[1].message.function_call
                    call.arguments = json.decode(call.arguments)
                    local type_name = ai_function_name_mappings[call.name]
                    print("doing ai function call for ",type_name)
                    local dialogue_type_object = dialogue_types[type_name]
                    if dialogue_type_object then
                        print('ai called',call)
                        return await(dialogue_type_object.ai_function_call(call,state))
                    end
                end
            end)
        end
    }
    return async(function ()
        local options = {
            type = "standard"
        }
        state.generate_node_async(options)
        print('==============')
        print('done generating, here are all the dialogues',generated_dialogues)
    end)
end

return dialogue_generator