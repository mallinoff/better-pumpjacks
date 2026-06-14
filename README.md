# Better Pumpjacks

Better Pumpjacks adds two upgraded pumpjack tiers and pumpjack-specific productivity research.

## Features

- Adds Pumpjack MK2.
- Adds Pumpjack MK3.
- Adds infinite pumpjack productivity research.
- Supports configurable pumpjack speed, productivity, module slots, pollution, and energy usage.
- Supports configurable productivity research bonus, max applied level, and research cost formula.
- Optionally applies pumpjack productivity research to vanilla pumpjacks.
- Updates pumpjack and technology descriptions from configured startup settings.

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

Because this uses custom hidden variants, the bonus does not appear in Factorio's standard bonus list.

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
- Entity replacement preserves health and modules, but may not preserve every possible state from other mods.
- Circuit connections, fluidbox state, or external mod references may not survive replacement in every case.

## Version

Current version: 1.4.1
