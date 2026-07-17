## [v4.5.3] 2026/07/17
- Fix the addon list Title not following the "Teron's `<Thing>`" branding used by every other addon in the portfolio: was `TeronAutoLFM` (with the LFM lettering colored), now `Teron's Auto LFM` with the same coloring kept on the LFM letters.

## [v4.5.2] 2026/07/15
- Fix a disabled dungeon role checkbox still being toggleable by clicking its icon: the icon is a separate button that was never itself disabled, and forcing a click through to the checkbox via `:Click()` bypasses the checkbox's own disabled state (unlike a real mouse click on it). The icon click now checks `IsEnabled()` on the checkbox first.
- Fix the Settings "My Role" row overflowing the panel: the Healer/DPS checkboxes and labels were positioned with fixed offsets that didn't account for the actual label text width, pushing the DPS checkbox/label partly or fully outside the visible panel. Each checkbox is now anchored off the previous label's real right edge instead.

## [v4.5.1] 2026/07/14
- Fix "My Role" not persisting through `/reload`: `Selection.MyRole` state was declared but never actually loaded from saved settings at startup, so it silently reset to unset every reload (which also made the dungeon checkbox-disable logic look broken, since it correctly re-enabled once the role was "forgotten").
- Fix the Settings "My Role" checkboxes not being mutually exclusive: clicking a role dispatched the change correctly, but the checkboxes' visuals were never resynced afterward, so WoW's native per-checkbox toggle let all three end up checked at once even though only one role was actually stored.
- Add: a dungeon role checkbox (and its icon, dimmed) now stays disabled once that role has been filled by a player who joined - not just when it's the leader's own role. Tracked separately from the live headcount so it survives the role being auto-removed from selection, and clears again if that player later leaves.

## [v4.5.0] 2026/07/14
- Add "My Role": pick your own role (Tank/Healer/DPS) in Settings, or from a one-time prompt shown when a dungeon/raid is first selected without one set. Once picked, it's automatically accounted for in what still needs recruiting - re-clicking the same role clears it back to unspecified.
  - Dungeons (fixed 1 tank/1 healer/3 DPS): the leader's own role directly reduces that role's quota - Tank or Healer becomes fully covered (0 needed, checkbox disabled) since a standard 5-man only wants one of each; DPS reduces from 3 to 2 since there's room for more.
  - Raids (dynamic, leader-configured headcounts): the leader's own role doesn't force any specific role's count down - instead the *shared pool* every role's headcount is capped against shrinks by 1 (scaled raid size minus 1), since the leader already occupies one of the raid's slots. Each role still starts at its normal default and the leader remains free to manually recruit more of their own role too.
  - Quests are unaffected - no fixed comp there, so no self-role accounting applies.

## [v4.4.5] 2026/07/14
- Fix clicking a role headcount edit box not selecting its existing text: `SetFocus()` alone doesn't survive the native click-to-place-cursor behavior that also runs on `OnMouseDown`, overriding any highlight set from `OnEditFocusGained`. Added `HighlightText()` to `OnMouseDown` itself (after `SetFocus()`), matching the raid group-size edit box's already-working pattern.

## [v4.4.4] 2026/07/14
- Fix confirming a role headcount resetting every *other* role's count to 1: `Core.Utils.ShallowCopy` used `table.getn()` + a numeric loop, which only copies array-style (sequential integer-keyed) tables. `Selection.RoleCounts` is a dictionary (`{TANK = 3, HEAL = 1, DPS = 1}`, string keys), so `table.getn()` returned 0 and every copy silently produced an empty table — meaning every `Selection.SetRoleCount`/`DecrementRoleCount`/`IncrementRoleCount` call was discarding every role except the one just edited. `ShallowCopy` now uses `pairs()`, which correctly handles both array and dictionary tables (and is a strict improvement for its existing array use cases too, not just a special case for this one).

## [v4.4.3] 2026/07/14
- Fix the raid group-size edit box getting permanently stuck focused after selecting a raid, unable to be released by clicking elsewhere:
  - The role headcount edit boxes never got the `OnMouseDown` → `SetFocus()` handler the raid size edit box already had (`SizeControl.lua`), so clicking them didn't reliably win focus away from an already-focused edit box. Added the matching handler to all three.
  - More generally, WoW only releases an edit box's keyboard focus via `ClearFocus()`, Escape, or another edit box stealing it — clicking a checkbox, switching tabs, or clicking blank space does nothing on its own. Added a shared focus tracker (`Core.Utils.SetFocusedEditBox`/`ClearFocusedEditBox`) and wired it into the raid size box, the role count boxes, the main window's background click, the role/dungeon/raid checkboxes, and tab switching — so clicking essentially anywhere in the addon now releases a focused edit box, not just clicking another edit box.

## [v4.4.2] 2026/07/14
- Fix the Role Assign popup never appearing for dungeons: `Selection.ToggleRaid` backfills role headcounts for already-checked roles when a raid is selected, but `Selection.ToggleDungeon` never got the same treatment. If roles were checked in a way that didn't line up with dungeon mode already being active, `Selection.RoleCounts` stayed empty and the popup's trigger condition silently failed. Dungeon selection now backfills the fixed 1/1/3 quota for any already-checked roles, same as raids.
- Fix cosmetic debug-registry ID collisions on `Components/RoleAssignPopup.lua`'s listener/init IDs (was reusing L10/I25, already used by `UI/Content/Dungeons.lua`'s `listenerId`/`initId`, which an earlier case-sensitive ID scan missed). These didn't affect functionality — Maestro registers by name, not by the numeric label — but are renumbered to L13/I28 for a clean debug log.
- Fix Role Assign popup never firing for group members who joined *before* broadcasting started: the join-diff only detects players joining after tracking begins, so pre-existing party/raid members were silently skipped. Now, starting a broadcast queues every current group member (except the leader) for role assignment, exactly as if they'd just joined.
- Fix an ambiguous broadcast message: if roles were checked but no dungeon/raid/quest/custom content was selected, the message fell back to a bare "Need Tank & Healer" with no context on what you're actually recruiting for. Now produces no message at all in that case, matching the existing "no channels selected" style guard.
- Fix a C stack overflow crash when committing a raid role headcount edit box: `OnRoleCountChanged` unconditionally called `ClearFocus()`, which re-fires `OnEditFocusLost`, which called `OnRoleCountChanged` again, forming infinite mutual recursion. `ClearFocus()` is now only called from `OnEnterPressed`'s own script, matching the pattern `SizeControl.lua` already uses.
- Add automatic role headcount restoration: if a player who'd been assigned a role via the Role Assign popup leaves the group, that role's headcount is incremented back (and re-added to the broadcast message if it had been fully filled and dropped). Roster changes are now diffed for both joins and leaves, and per-player role assignments are tracked so leaving correctly reverses what joining decremented. If someone leaves before the leader gets to their popup entry, they're removed from the queue instead of leaving a stale prompt for someone no longer in the group.

## [v4.4.0] 2026/07/14
- Add a Role Assign popup: while actively broadcasting as the group leader, a small dialog appears whenever a new player joins, letting you assign their role (Tank/Healer/DPS/Skip) with one click. Assigning a role decrements that role's remaining headcount automatically — no more manually editing counters as your group fills up.
  - Works for both raids (decrements the configured per-role headcount) and dungeons (uses the fixed 1 tank / 1 healer / 3 DPS composition, but only for roles you've actually checked — nothing is auto-selected)
  - Once a role's count reaches 0, it's fully filled and automatically dropped from the broadcast message
  - Handles multiple players joining at nearly the same time via a queue, so simultaneous invites are never missed — the popup processes them one at a time
  - Only fires for the group leader while a broadcast is running for a dungeon or raid with roles selected; does nothing otherwise

## [v4.3.1] 2026/07/14
- Fix the new raid role headcount edit boxes being unclickable: they were missing `enableMouse="true"` and sat at the same frame level as the role icon buttons behind them, so clicks never reached the edit box. Matches the fix already used by the existing raid group-size edit box (`SizeControl.lua`).
- Cap raid role headcounts so Tank + Healer + DPS can never sum past the raid's current (scaled) target size — allocating 3 Tanks on a 20-scaled raid leaves at most 17 for the other roles combined, not 37. Uses the same scaled `Selection.RaidSize` value everywhere (input clamping and role defaults), not the raid's true unscaled maximum, so the cap always matches what the raid is actually scaled to. Purely an input-allocation limit — it doesn't change the broadcast message's own headcount, which was already independent of role counts.
- Safeguard: if the raid's size is rescaled while role counts are already allocated, reset every role's count back to 1 instead of leaving a now-potentially-over-allocated total from the previous size.

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