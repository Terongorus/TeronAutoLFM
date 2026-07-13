# TeronAutoLFM Public API

The TeronAutoLFM Public API allows external addons to query broadcast state, subscribe to state changes, and integrate with the TeronAutoLFM broadcaster.

**Access via:** `local api = TeronAutoLFM.API`

---

## Broadcast State API

### GetBroadcastMessage()
Returns the current broadcast message being sent to chat.

```lua
function TeronAutoLFM.API.GetBroadcastMessage()
```

**Returns:**
- `string` - The broadcast message, or empty string if none

**Example:**
```lua
local msg = TeronAutoLFM.API.GetBroadcastMessage()
print("Currently broadcasting: " .. msg)
```

---

### IsBroadcasting()
Checks if the broadcaster is currently running.

```lua
function TeronAutoLFM.API.IsBroadcasting()
```

**Returns:**
- `boolean` - `true` if broadcasting is active

**Example:**
```lua
if TeronAutoLFM.API.IsBroadcasting() then
  print("TeronAutoLFM is broadcasting")
end
```

---

### GetBroadcastInterval()
Returns the current broadcast interval in seconds.

```lua
function TeronAutoLFM.API.GetBroadcastInterval()
```

**Returns:**
- `number` - Interval in seconds (30-120)

**Example:**
```lua
local interval = TeronAutoLFM.API.GetBroadcastInterval()
print("Broadcasting every " .. interval .. " seconds")
```

---

### GetMessagesSent()
Returns the number of messages sent in the current session.

```lua
function TeronAutoLFM.API.GetMessagesSent()
```

**Returns:**
- `number` - Message count

**Example:**
```lua
local count = TeronAutoLFM.API.GetMessagesSent()
print("Messages sent so far: " .. count)
```

---

## Selection State API

### GetSelectedDungeons()
Returns all currently selected dungeon names.

```lua
function TeronAutoLFM.API.GetSelectedDungeons()
```

**Returns:**
- `table` - Array of dungeon names (empty if none selected)

**Example:**
```lua
local dungeons = TeronAutoLFM.API.GetSelectedDungeons()
for i = 1, #dungeons do
  print("Selected: " .. dungeons[i])
end
```

---

### GetSelectedRaid()
Returns the currently selected raid name.

```lua
function TeronAutoLFM.API.GetSelectedRaid()
```

**Returns:**
- `string|nil` - Raid name or `nil` if no raid selected

**Example:**
```lua
local raid = TeronAutoLFM.API.GetSelectedRaid()
if raid then
  print("Raid selected: " .. raid)
end
```

---

### GetSelectedRoles()
Returns the selected roles (Tank, Heal, DPS).

```lua
function TeronAutoLFM.API.GetSelectedRoles()
```

**Returns:**
- `table` - Array of role strings: `{"TANK"}`, `{"HEAL"}`, `{"DPS"}`, or combinations

**Example:**
```lua
local roles = TeronAutoLFM.API.GetSelectedRoles()
if #roles > 0 then
  print("Selected roles: " .. table.concat(roles, ", "))
end
```

---

### GetSelectionMode()
Returns the current selection mode.

```lua
function TeronAutoLFM.API.GetSelectionMode()
```

**Returns:**
- `string` - One of:
  - `"dungeons"` - Dungeons selected
  - `"raid"` - Raid selected
  - `"quests"` - Quests selected
  - `"custom"` - Custom message mode
  - `"none"` - Nothing selected

**Example:**
```lua
local mode = TeronAutoLFM.API.GetSelectionMode()
if mode == "raid" then
  print("Raid mode active")
end
```

---

## Group State API

### GetGroupSize()
Returns the current group size.

```lua
function TeronAutoLFM.API.GetGroupSize()
```

**Returns:**
- `number` - Group size (1-40, where 1 = solo)

**Example:**
```lua
local size = TeronAutoLFM.API.GetGroupSize()
print("Group size: " .. size)
```

---

### GetGroupType()
Returns the current group type.

```lua
function TeronAutoLFM.API.GetGroupType()
```

**Returns:**
- `string` - One of:
  - `"solo"` - Playing alone
  - `"party"` - In a party (2-5 players)
  - `"raid"` - In a raid (10+ players)

**Example:**
```lua
local groupType = TeronAutoLFM.API.GetGroupType()
print("Group type: " .. groupType)
```

---

### IsGroupLeader()
Checks if the player is the group leader.

```lua
function TeronAutoLFM.API.IsGroupLeader()
```

**Returns:**
- `boolean` - `true` if player is leader (or solo)

**Example:**
```lua
if TeronAutoLFM.API.IsGroupLeader() then
  print("You are the group leader")
end
```

---

## Settings API

### IsDarkModeEnabled()
Checks if dark mode is enabled.

```lua
function TeronAutoLFM.API.IsDarkModeEnabled()
```

**Returns:**
- `boolean` - `true` if dark mode is active

**Example:**
```lua
if TeronAutoLFM.API.IsDarkModeEnabled() then
  print("Dark mode is active")
end
```

---

### IsDryRunEnabled()
Checks if dry run mode is enabled (messages not sent to chat).

```lua
function TeronAutoLFM.API.IsDryRunEnabled()
```

**Returns:**
- `boolean` - `true` if dry run mode is active

**Example:**
```lua
if TeronAutoLFM.API.IsDryRunEnabled() then
  print("Dry run mode: messages preview only, not sent")
end
```

---

### GetDungeonFilters()
Returns the dungeon difficulty filters.

```lua
function TeronAutoLFM.API.GetDungeonFilters()
```

**Returns:**
- `table` - Table with color names as keys and boolean values
  - Keys: `"GRAY"`, `"GREEN"`, `"YELLOW"`, `"ORANGE"`, `"RED"`
  - Values: `true` = visible, `false` = filtered out

**Example:**
```lua
local filters = TeronAutoLFM.API.GetDungeonFilters()
if filters["RED"] then
  print("Showing red (hardest) dungeons")
end
```

---

### GetBroadcastIntervalSetting()
Returns the broadcast interval setting from persistent storage.

```lua
function TeronAutoLFM.API.GetBroadcastIntervalSetting()
```

**Returns:**
- `number` - Interval in seconds (30-120, default 60)

**Example:**
```lua
local interval = TeronAutoLFM.API.GetBroadcastIntervalSetting()
print("User set interval to: " .. interval .. " seconds")
```

---

## Event Subscription API

### OnBroadcastStateChanged(listenerId, callback)
Subscribes to broadcast state changes.

```lua
function TeronAutoLFM.API.OnBroadcastStateChanged(listenerId, callback)
```

**Parameters:**
- `listenerId` (string) - Unique listener identifier for this subscription
- `callback` (function) - Function called when state changes: `function(newValue)`

**Returns:**
- `boolean` - `true` if subscription successful

**Example:**
```lua
TeronAutoLFM.API.OnBroadcastStateChanged("MyAddon.OnBroadcast", function(newValue)
  print("Broadcast state changed!")
end)
```

---

### OnSelectionChanged(listenerId, callback)
Subscribes to selection state changes (dungeons, raid, roles, custom message).

```lua
function TeronAutoLFM.API.OnSelectionChanged(listenerId, callback)
```

**Parameters:**
- `listenerId` (string) - Unique listener identifier for this subscription
- `callback` (function) - Function called when state changes: `function(newValue)`

**Returns:**
- `boolean` - `true` if subscription successful

**Example:**
```lua
TeronAutoLFM.API.OnSelectionChanged("MyAddon.OnSelection", function(newValue)
  print("TeronAutoLFM selection changed!")
end)
```

---

### OnGroupStateChanged(listenerId, callback)
Subscribes to group state changes (size, type, leader status).

```lua
function TeronAutoLFM.API.OnGroupStateChanged(listenerId, callback)
```

**Parameters:**
- `listenerId` (string) - Unique listener identifier for this subscription
- `callback` (function) - Function called when state changes: `function(newValue)`

**Returns:**
- `boolean` - `true` if subscription successful

**Example:**
```lua
TeronAutoLFM.API.OnGroupStateChanged("MyAddon.OnGroupChange", function(newValue)
  if TeronAutoLFM.API.GetGroupSize() >= 5 then
    print("Party is now full!")
  end
end)
```

---

### Unsubscribe(listenerId)
Unsubscribes from state changes.

```lua
function TeronAutoLFM.API.Unsubscribe(listenerId)
```

**Parameters:**
- `listenerId` (string) - Listener identifier to remove

**Returns:**
- `boolean` - `true` if unsubscription successful

**Example:**
```lua
TeronAutoLFM.API.Unsubscribe("MyAddon.OnBroadcast")
```

---

## Utility Functions

### GetSnapshot()
Returns a complete snapshot of all broadcast, selection, group, and settings state.

```lua
function TeronAutoLFM.API.GetSnapshot()
```

**Returns:**
- `table` - State snapshot with structure:
  ```lua
  {
    broadcast = {
      message = string,
      isRunning = boolean,
      interval = number,
      messagesSent = number
    },
    selection = {
      dungeons = table,
      raid = string|nil,
      roles = table,
      mode = string
    },
    group = {
      size = number,
      type = string,
      isLeader = boolean
    },
    settings = {
      darkMode = boolean,
      dryRun = boolean,
      dungeonFilters = table
    }
  }
  ```

**Example:**
```lua
local snapshot = TeronAutoLFM.API.GetSnapshot()
print("Broadcasting: " .. snapshot.broadcast.message)
print("Group size: " .. snapshot.group.size)
print("Dry run enabled: " .. tostring(snapshot.settings.dryRun))
```

---

## Integration Example

```lua
-- Example addon integrating with TeronAutoLFM

if not TeronAutoLFM or not TeronAutoLFM.API then
  return  -- TeronAutoLFM not loaded
end

-- Subscribe to selection changes
TeronAutoLFM.API.OnSelectionChanged("MyIntegration", function()
  local dungeons = TeronAutoLFM.API.GetSelectedDungeons()
  local raid = TeronAutoLFM.API.GetSelectedRaid()

  if raid then
    print("Raiding: " .. raid)
  elseif #dungeons > 0 then
    print("Running dungeons: " .. table.concat(dungeons, ", "))
  end
end)

-- Check if broadcasting before doing something
if TeronAutoLFM.API.IsBroadcasting() then
  local msg = TeronAutoLFM.API.GetBroadcastMessage()
  print("TeronAutoLFM is broadcasting: " .. msg)
end

-- Get current snapshot for diagnostics
local snapshot = TeronAutoLFM.API.GetSnapshot()
print("Full state: " .. stringify(snapshot))
```

---

## Important Notes

1. **Availability**: The API is available after PLAYER_ENTERING_WORLD event
2. **Read-Only**: The public API only provides read access and subscriptions, not command dispatch
3. **State Updates**: State is centralized in Maestro; external addons should subscribe to changes rather than polling
4. **Listener IDs**: Must be unique across all addons using the API to avoid conflicts
5. **Callbacks**: Callbacks should complete quickly to avoid blocking the addon
