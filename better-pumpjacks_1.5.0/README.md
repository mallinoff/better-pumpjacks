# Better Pumpjacks

Better Pumpjacks adds two upgraded pumpjack tiers, pumpjack-specific productivity research, and a dashboard for monitoring oil field output.

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

- Pumpjack MK2: 1.5x mining speed, 4 module slots, +10% base productivity, 180 kW energy usage.
- Pumpjack MK3: 2x mining speed, 8 module slots, +20% base productivity, 300 kW energy usage.

These values can be changed in startup settings.

## Productivity Research

Pumpjack productivity research is pumpjack-specific. It is implemented by replacing placed pumpjacks with hidden productivity variants that have higher `base_productivity`.

Default values:

- Productivity bonus per level: +10%.
- Max applied productivity level: 50.
- Research cost formula: `1000 + (L * 1000)`.
- Vanilla pumpjacks affected: disabled by default.

Because this uses custom hidden variants, the bonus does not appear in Factorio's standard bonus list. Placed pumpjacks show the correct combined productivity in their tooltip; items in inventory show only the base tier productivity.

## Dashboard

Open the dashboard with the toolbar shortcut button or the keybind (default: none). The dashboard shows:

- Current productivity level and total bonus.
- Total fluid/s estimate and total pumpjack count across all visible surfaces.
- Per-fluid breakdown with fluid/s, pumpjack counts by tier, and configurable low-output warning thresholds.
- Per-surface breakdown with productivity, pumpjack counts by tier, average yield, and fluid/s.

### Surface Manager

Click **Manage** in the dashboard footer to open the surface visibility manager. From there you can show or hide individual surfaces from the dashboard and assign custom display names.

### Low-Output Warnings

Select a surface from the dashboard dropdown to configure per-fluid warning thresholds. When a fluid's estimated output falls below its threshold, a chat warning is printed. Warning repeat rate and scan interval are configurable in runtime settings.

## Upgrade Planner & Ghost Placement

All pumpjack tiers support the upgrade planner. Bots will automatically promote pumpjacks to the next tier when queued. Pressing Q on any placed pumpjack returns the correct item for ghost placement.

## Remote Interface

Other mods can read dashboard data via `remote.call`:

```lua
-- Get fluid/s stats for a force
remote.call("better-pumpjacks", "get_output_stats", "player")

-- Get all warning thresholds for a surface
remote.call("better-pumpjacks", "get_output_thresholds", "player", "nauvis")

-- Get a specific threshold
remote.call("better-pumpjacks", "get_output_threshold", "player", "nauvis", "crude-oil")

-- Check if a fluid is below its threshold
remote.call("better-pumpjacks", "is_output_below_threshold", "player", "nauvis", "crude-oil")

-- Get all tracked entity names
remote.call("better-pumpjacks", "get_known_entity_names")
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

This refreshes placed pumpjacks and prints the current pumpjack productivity level and bonus.

To check the current pumpjack productivity level without refreshing pumpjacks, run:

```text
/bpj-level
```

Normal research does not need `/bpj-refresh`; the mod updates pumpjacks automatically when research completes.

## Compatibility Notes

- Hidden productivity variants are real mining-drill prototypes. Some planner mods may list them if they do not ignore hidden prototypes.
- Oil Outpost Planner may show hidden productivity variants because it scans mining-drill prototypes directly.
- Space Exploration staged productivity technologies are supported by matching `bpj-pumpjack-output-N` research names.
- Space Exploration final fixes update staged research costs and science packs.

## Known Limitations

- Pumpjack productivity does not appear in Factorio's standard bonus list.
- Item tooltips show only the tier's base productivity; placed pumpjack tooltips show the full combined value.
- Entity replacement preserves health and modules, but may not preserve every possible state from other mods.
- Circuit connections, fluidbox state, or external mod references may not survive replacement in every case.
- Modules that do not fit after replacement (e.g. due to a settings change reducing module slots) are spilled on the ground.

## Version

Current version: 1.5.0
