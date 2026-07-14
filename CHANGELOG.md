## [v4.3.0] 2026/07/14
- Restructure broadcast message formats:
  - Dungeons: "LF#M for X - need Tank & Healer" (dash before, lowercase "need")
  - Quests: "LFM [Quest Name] - need Tank & Healer" (previously had no "LFM" prefix at all)
  - Raids: "LF#M for X - need 2 Tanks & 3 Healers 35/40" — role text now shows a per-role headcount (with pluralization, e.g. "1 Tank" vs "2 Tanks") instead of a flat role list, since raid comps vary by raid size (unlike dungeons, which are always a fixed 1 tank / 1 heal / 3 DPS)
- Rename the "Heal" role display text to "Healer"/"Healers" everywhere it appears in broadcast messages (dungeons, quests, raids, and the custom message {ROL} variable)
- Add per-role headcount inputs next to the Tank/Heal/DPS role icons, shown only in raid mode for currently-selected roles
- Remember the headcount configured for each role, per raid, so it's restored automatically next time that raid+role combination is selected (same behavior as the existing per-raid group size memory)

## [v4.2.2] 2026/07/14
- Fix quest links breaking broadcast messages on pure vanilla 1.12.1 clients (Turtle WoW's own client supports them, but stock 1.12.1 doesn't parse quest hyperlinks in chat) — quest links added via Shift+Click are now converted to plain "[Quest Name]" text right before the message is broadcast or previewed, while still using the real clickable link internally so adding/removing a quest from the message still works normally

## [v4.2.1] 2026/07/14
- Rename the 5-man dungeon entries "Stratholme Live 5" / "Stratholme UD 5" / "Scholomance 5" to "Stratholme Live" / "Stratholme UD" / "Scholomance" (dropping the redundant "5"), to distinguish them from the 10-man raid versions which keep their "10" suffix
- Note: saved presets that selected one of these three dungeons under its old name will no longer re-select it when loaded (the rest of the preset still applies); re-save affected presets after this update

## [v4.2.0] 2026/07/14
- Variable-size raids now default to their maximum group size when first selected, instead of the minimum
- The group size chosen for a raid (via slider or edit box) is now remembered per-instance and restored automatically the next time that raid is selected, so it doesn't need to be reconfigured every time

## [v4.1.0] 2026/07/13
- Add keybinding to toggle the main window (Key Bindings > TeronAutoLFM), in addition to `/lfm`
- Add "Show Turtle WoW custom instances" setting (Settings tab) — vanilla dungeons/raids always show; TWoW custom content is hidden by default and only appears when enabled
- Classification is automatic: content is checked against a fixed list of authentic vanilla instance names, so newly added custom content requires no manual tagging to stay hidden by default

## [v4.0.0] 2026/07/13
- Rebrand: AutoLFM → TeronAutoLFM, now maintained independently as part of the Teron* addon family
- Rename addon folder and `.toc` to `TeronAutoLFM`
- Rename global namespace table `AutoLFM` → `TeronAutoLFM` across all Lua/XML files (frame names, texture paths, slash command registration)
- Update README, wiki docs, and asset filenames to match the new name
- No functional changes — behavior is identical to v3.15

## [v3.15] 2026/04/09
- Fix `Utils.ROW_HEIGHT` → `Constants.ROW_HEIGHT` in Raids UI (scroll height was nil)
- Fix `LogWarn` → `LogWarning` in AutoInvite UI, remove duplicate `OnShow` in Settings UI
- Fix 8 format string placeholders (`%s`, `%d`) appearing literally in log calls
- Fix 3 frame memory leaks: reuse measurement frame in Presets, stop orphaning rows, create EyeAnimation timer once
- Migrate messaging stats timer to centralized Ticker system (`MESSAGING_STATS`)
- Optimize Debug color lookup (hash table) and `iterativeFit` text truncation (binary search)
- Fix Maestro `SetState` validator to correctly reject truthy error strings
- Normalize code style across all 36 .lua files (separators, spacing, LuaDoc)
- Migrate documentation from `_Docs/` to `_wiki/` (flat structure, GitHub Wiki ready)
- Move screenshots and assets to `_assets/`

## [v3.14] 2026/03/23
- Update for Turtle WoW patch 1.18.1 (Nightmares of Ursol)
- Add new dungeons: Frostmane Hollow, Windhorn Canyon
- Add new raids: Tower of Karazhan, Timbermaw Hold
- Fix typo: Halteforge Quarry → Hateforge Quarry
- Reframe addon presentation as Turtle WoW addon (README, .toc, docs)

## [v3.13] 2026/03/11
- Fix stack overflow when right-clicking player names in chat with other addons (FuBar, Talented-turtle)
- Add reentrancy guard to ChatFrame_OnHyperlinkShow hook to prevent recursive loops

## [v3.12] 2026/02/10
- Fix hardcore detection unreliable at login: defer spellbook scan to SPELLS_CHANGED event
- One-time migration resets incorrectly persisted `isHardcore = false` for re-detection
- Fix conversion frame not hidden after max raid conversion attempts
- Validate dungeon/raid names against Constants when loading presets

## [v3.11] 2026/01/28
- Add centralized Ticker system (`Core/Ticker.lua`) to consolidate OnUpdate frames
- Refactor Broadcaster.lua to use Ticker instead of dedicated frames (3 frames -> 1 shared)
- Refactor AutoInvite.lua cleanup timer to use Ticker system
- Move `Trim()` and `EscapePattern()` functions to `Core/Utils.lua` for reusability
- Add preset validation schema (`PRESET_SCHEMA`) with field-level validators
- Add `sanitizePresetData()` for best-effort recovery of corrupted presets
- Corrupted presets now load with defaults for invalid fields instead of failing
- Centralize magic constants: `WORD_BREAK_THRESHOLD`, `TICKER_RESOLUTION`, `TICKER_IDS`
- Add preset validation constants: `PRESET_DEFAULTS`, `PRESET_RAID_SIZE_MIN/MAX`, `PRESET_GROUP_SIZE_MIN/MAX`
- Update dependencies: Broadcaster and AutoInvite now depend on `Core.Ticker`

## [v3.10] 2026/01/17
- Replace hardcoded `DUNGEONS_COUNT`/`RAIDS_COUNT` with dynamic calculation in `BuildLookupTables()`
- Remove unused `COLORS_COUNT` constant
- Add generic auto-invite messages (8 new messages) for more variety
- Implement exponential backoff for broadcast retries (1s -> 2s -> 4s...)
- Add per-player cooldown (5s) for auto-invite to prevent whisper spam
- Move `INVITE_COOLDOWN` to Constants.lua for consistency
- Add periodic cleanup of expired cooldown entries (prevents unbounded memory growth)
- Make cleanup timer conditional: only runs when auto-invite is enabled (saves CPU cycles)
- Clear cooldown table when auto-invite is disabled (immediate memory release)
- Create cleanup frame hidden by default, remove verbose timer logging
- Add `validatePresetData()` function to validate preset structure before loading
- Presets with corrupted data now show explicit error message instead of failing silently

## [v3.9] 2026/01/05
- Add raid assist (IsRaidOfficer) and raid leader (IsRaidLeader) support for auto-invite
- Raid assistants can now use auto-invite functions like leaders
- Listen to RAID_ROSTER_UPDATE for promotion/demotion detection
- Update UI label "Group leader" to "Leader/Assist" with white text color
- Update whisper messages to reflect leader/assist terminology

## [v3.8] 2026/01/02
- Fix duplicate Listener IDs: L05/L06 were used twice (UI panels now use L10-L12)
- Fix `API.IsDarkModeEnabled()` accessing non-existent Maestro state (now uses Storage)
- Fix Lua 5.0 compatibility: remove unused `self` parameter in `SetScript("OnUpdate")` callback
- Optimize `Selection.SetRaidSize()`: use O(1) `RAIDS_BY_NAME` lookup instead of O(n) loop
- Update documentation: correct ID counts (92 total: 24 Commands, 9 Events, 12 Listeners, 20 States, 27 Init Handlers)
- Fix documentation: Auto Invite section incorrectly listed E09-E10 (only E09 exists)
- Update ContentPanel factory comments for clarity on ID auto-assignment (I25+)

## [v3.7] 2025/12/29
- Add pre-calculated array counts (`DUNGEONS_COUNT`, `RAIDS_COUNT`, `COLORS_COUNT`) to avoid O(n) `table.getn()` calls
- Optimize broadcast timer: reuse frame with `Show()`/`Hide()` instead of recreating
- Factorize `forEachRow()` helper in RowList.lua to reduce code duplication
- Add automatic retry mechanism for failed broadcasts (max 2 retries with 1s delay)
- Add `scheduleRetry()` with dedicated frame for deferred retry execution
- Add `escapePattern()` to sanitize auto-invite keywords against Lua pattern injection
- Add `UnregisterCommand()` function to Maestro for command cleanup
- Add optional `validator` parameter to `RegisterState()` for state value validation
- `SetState()` now returns boolean indicating success/failure
- Add comprehensive inline comments for Kahn's topological sort algorithm
- Document all algorithm steps with examples and time complexity

## [v3.6] 2025/12/26
- Add `ArrayContains()` and `ShallowCopy()` utility functions in Utils.lua
- Add `SELECTION_MODES`, `ROLES`, and `VALID_ROLES` constants for type-safe mode switching
- Replace magic strings with constants in Selection.lua (`MODES.DUNGEONS`, `MODES.RAID`, etc.)
- Fix state mutation bug: create shallow copies before modifying arrays from GetState()
- Remove dead code (empty if block) in RowList.lua
- Release memory by setting `pendingStates`/`pendingInits` to nil after flush in Maestro.lua

## [v3.5] 2025/12/11
- Remove redundant Core/Settings.lua
- Remove deprecated GREEN_THRESHOLDS alias
- Remove unused `createQuestLink()` function
- Remove unused `Message.Generated` event
- Add pcall protection for SendChatMessage in Broadcaster.lua
- Add `Utils.RemoveFromArray()` utility function and refactor array removal patterns in Selection.lua and Messaging.lua
- Add configurable General channel index in lua file
- Add `migrateSettings()` to auto-add new settings to existing SavedVariables
- Move initFrame from Events.lua to Maestro.lua
- Simplify dungeon selection lookup
- Unify SOUND_PATH constant
- Renumber IDs: L01-L08, I01-I26, E07-E09

## [v3.4] 2025/12/05
- Add General channel
- Move interval slider in settings (add state info)
- Fix alignment messaging details/custom

## [v3.3] 2025/12/05
- Fix Maestro ID lists
- Fix docs files

## [v3.2] 2025/12/05
- Add quests links requirements
- Reduce space in messaging content: no more scroll in details
- Fix dungeons/raids not visible in presets list
- Add tooltip on VAR insert button for custom message
- Fix Maestro ID lists

## [v3.1] 2025/11/29
- Fix dungeons filters settings
- Rename Settings.lua and add in .toc
- Fix hover row list darkUI
- Clean texture files
- UI.ContentPanel factory pattern
- Add documentation to Core/Constants files
- Improve error messages with context
- Add API and improve documentation
- Optimize dungeon selection lookup performance
- Fix timer context issue in OnUpdate handler
- Fix `SavePreset()` to allow overwriting existing presets
- Implement `UnSubscribeState()` function
- Add cache size limit to prevent unbounded growth
- Verify `JoinChannelByName()` success
- Optimized `BuildColorLookupTable()`
- Implement Unsubscribe functionality for broadcast and group state listeners
- Enhance Maestro init logging with events and commands registry display
- Refactor Selection.lua with `setSelectionMode()` for mutual exclusivity
- Optimize registry IDs for better organization and clarity
- Reduce Save Preset popup window size and remove preset name label
- Add screenshots

## [v3.0] 2025/11/29
- Maestro, initial release.