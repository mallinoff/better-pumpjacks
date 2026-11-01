# Better Pumpjacks

Better Pumpjacks adds two upgraded pumpjack tiers, pumpjack-specific productivity research, and a dashboard for monitoring oil field output.

Requires **Factorio 2.1** and **base >= 2.1**.

## Features

- Adds Pumpjack MK2.
- Adds Pumpjack MK3.
- Adds infinite pumpjack productivity research.
- Supports configurable pumpjack speed, productivity, module slots, pollution, and energy usage.
- Supports configurable productivity research bonus, max applied level, and research cost formula.
- Optionally applies pumpjack productivity research to vanilla pumpjacks.
- Updates pumpjack and technology descriptions from configured startup settings.
- Adds a dashboard showing per-surface fluid/s estimates, pumpjack counts, average yield, and low-output warnings.
- Supports upgrade planner and Q-key ghost placement for all pumpjack tiers.
- Exposes dashboard stats and output thresholds via remote interface for other mods.

## Pumpjack Tiers

Default values:

- Pumpjack MK2: 1.5 base mining speed, 4 module slots, +30% base productivity, 180 kW energy usage.
- Pumpjack MK3: 2 base mining speed, 8 module slots, +60% base productivity, 300 kW energy usage.

These values can be changed in startup settings.

## Productivity Research

Pumpjack productivity research applies directly to eligible pumpjacks through Factorio 2.1 local effects. It does not replace machines or affect regular miners. Tier base productivity remains a prototype base effect; research adds a separate local productivity bonus. Repeated refreshes update the existing contribution instead of stacking it.

Default values:

- Productivity bonus per level: +10%.
- Max applied productivity level: 500.
- Research cost formula: `1000 + (L * 1000) + (L^2 * 37.996)`.
- Level 500 costs **10,000,000 of each required science pack**, with default cost settings.
- Vanilla pumpjacks affected: disabled by default.

Productivity settings use fractions: `0.1` means +10%. Research level `L` starts at 1. Costs grow quadratically; set Quadratic Growth to `0` to restore the previous linear formula. Changing the base or level cost also changes the level-500 cost. Research remains available beyond the maximum applied level and still costs science, but adds no further pumpjack productivity.

The custom research bonus does not appear in Factorio's standard force bonus list. Machine and technology descriptions show configured base tier values; check the game's productivity stat for the applied total, including research, modules, beacons, and normal mining research. Inventory item descriptions are generic.

Old productivity variants migrate to standard pumpjacks on load using JSON entity-name migrations. Research updates no longer destroy or recreate entities, preserving their identity, quality, modules, connections, and operating state. Existing local effect fields and productivity contributions are retained when this mod updates its tracked bonus.

## Dashboard

Open the dashboard with the toolbar shortcut button or the keybind (default: none). The dashboard shows:

- Current productivity level and total bonus.
- Total fluid/s estimate and total pumpjack count across all visible surfaces.
- Per-fluid breakdown with fluid/s, pumpjack counts by tier, and configurable low-output warning thresholds.
- Per-surface breakdown with productivity, pumpjack counts by tier, average yield, and fluid/s.

### Surface Manager

Click **Manage** in the dashboard footer to open the surface visibility manager. From there you can show or hide individual surfaces from the dashboard and assign custom display names.

Visibility, nicknames, surface ordering, the selected surface, and warning thresholds use stable surface IDs, so renaming a surface preserves its settings. Existing name-based settings migrate automatically.

### Low-Output Warnings

Select a surface from the dashboard dropdown to configure per-fluid warning thresholds. When a fluid's estimated output falls below its threshold, a chat warning is printed. Warning repeat rate and scan interval are configurable in runtime settings.

Fluids with saved thresholds remain listed on the selected surface even after their last producer is removed, so you can change or clear the warning.

## Upgrade Planner & Ghost Placement

All pumpjack tiers support the upgrade planner. Bots will automatically promote pumpjacks to the next tier when queued. Pressing Q on any placed pumpjack returns the correct item for ghost placement.

## Remote Interface

Other mods can read dashboard data via `remote.call`:

```lua
-- Get fluid/s stats for a force
remote.call("better_pumpjacks", "get_output_stats", "player")

-- Get all warning thresholds for a surface
remote.call("better_pumpjacks", "get_output_thresholds", "player", "nauvis")

-- Get a specific threshold
remote.call("better_pumpjacks", "get_output_threshold", "player", "nauvis", "crude-oil")

-- Check if a fluid is below its threshold
remote.call("better_pumpjacks", "is_output_below_threshold", "player", "nauvis", "crude-oil")

-- Get all tracked entity names
remote.call("better_pumpjacks", "get_known_entity_names")
```

## Startup Settings

- MK2/MK3 mining speed.
- MK2/MK3 base productivity.
- MK2/MK3 module slots.
- MK2/MK3 pollution.
- MK2/MK3 energy usage.
- Productivity research bonus per level.
- Max productivity research level applied to entities.
- Whether productivity research affects vanilla pumpjacks.
- Productivity research base science cost.
- Productivity research per-level science cost.
- Productivity research quadratic growth coefficient.

## Console Testing

Research the base productivity technology:

```lua
/c game.player.force.technologies["bpj-pumpjack-output"].researched = true
```

If Space Exploration or another mod stages the infinite technology, research staged levels like this:

```lua
/c game.player.force.technologies["bpj-pumpjack-output-2"].researched = true
/c game.player.force.technologies["bpj-pumpjack-output-3"].researched = true
```

After changing research with console commands, run:

```text
/bpj-refresh
```

This queues direct research-bonus updates for placed pumpjacks and prints the current productivity level and bonus. Updates are processed two per tick.

To check the current pumpjack productivity level without refreshing pumpjacks, run:

```text
/bpj-level
```

Normal research does not need `/bpj-refresh`; the mod updates pumpjacks automatically when research completes.

Research reversal, force resets, force merges, cloning, and configuration changes automatically synchronize pumpjack bonuses. Use `/bpj-refresh` after manual changes that do not raise the relevant events, such as another script silently changing an individual entity's force without raising an event.

## Compatibility Notes

- Productivity no longer creates hidden mining-drill prototypes, so planners see only the normal pumpjack tiers.
- The remote `get_target_name` function returns the canonical tier name, independent of research level.
- Space Exploration staged productivity technologies are supported by matching `bpj-pumpjack-output-N` research names.
- Space Exploration final fixes update staged research costs and science packs.

## Known Limitations

- Pumpjack productivity does not appear in Factorio's standard bonus list.
- Custom descriptions show base tier values; the game's productivity stat shows the effective total.
- Mods sharing `local_effect` should preserve existing values when editing it. A mod that overwrites the entire effect can remove this mod's contribution; automatic coordination with arbitrary external writes is not possible.
- Reducing module-slot startup settings on existing saves is not covered by a module-recovery mechanism.

## Version

Current version: 1.7.0
