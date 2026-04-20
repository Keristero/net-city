# advertise_server

A server script that advertises your server to one or more server list APIs. It syncs server info, player counts, map data, and optionally receives mod whitelists.

## Setup

1. Copy the `advertise_server` folder into your server's `scripts/` directory.
2. Edit `data/advertisement.json` (see below).
3. Start your server — a secret key will be generated on first sync and saved to `data/secret_keys.json`.

## data/advertisement.json

```json
{
    "listservers": {
        "main": "https://example.com/server_list/"
    },
    "advertisements": [
        {
            "unique_server_id": "my_server",
            "name": "My Server",
            "address": "myserver.com:8765",
            "description": "A cool server",
            "tags": ["social"],
            "data": "",
            "color": "rgb(128,128,128)"
        }
    ]
}
```

### Required fields

| Field | Description |
|---|---|
| `unique_server_id` | Unique ID for your server on the list |
| `name` | Display name |
| `address` | Public address:port players connect to |

### Optional fields

| Field | Default | Description |
|---|---|---|
| `description` | `""` | Server description |
| `tags` | `[]` | Array of tag strings (e.g. `["pvp", "social"]`) |
| `data` | `""` | Data string included when players connect from the modsite (not yet supported) |
| `color` | `"rgb(128,128,128)"` | Display color in `rgb(r,g,b)` format |
| `icon` | none | Filename of a `.png` in the `data/` folder to use as server icon |
| `advertise_map` | `false` | If `true`, advertises a map of your server's areas and connections |
| `whitelist_collection_eid` | `null` | EID of a mod collection to use for whitelisting |
| `whitelist_text_path` | `null` | Local file path to write the received whitelist to |

## Optional features

### Map advertising

Set `"advertise_map": true` in your advertisement to publish a map of your server's areas and their connections (local warps and remote server warps). The map updates automatically when areas are added or removed.

### Map overrides

Edit `data/map_overrides.lua` to customize how map connections are detected from map objects. The default handles standard ezlibs warps (`Target Area` / `Address` / `Port` properties). Override this if your server uses different warp conventions.

The file must return a table with a `process_object(area_id, map_info, object)` function:

```lua
local overrides = {}

function overrides.process_object(area_id, map_info, object)
    local custom_p = object.custom_properties
    -- local connections:
    --   map_info.l[target_area_id] = {id=object_id}
    -- remote connections:
    --   map_info.r["address:port"] = {data=..., incoming_data=...}
    -- extra info:
    --   map_info.has_shop = true
    --   map_info.has_board = true
end

return overrides
```

### Mod whitelists

Set `whitelist_collection_eid` to a mod collection EID and `whitelist_text_path` to a local file path. The server list API will return a whitelist on each sync, and the script will write it to that file.
