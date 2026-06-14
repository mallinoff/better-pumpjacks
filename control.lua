local max_productivity_level = settings.startup["bpj-max-productivity-level"].value
local max_migration_scan_level = 500
local productivity_affects_vanilla = settings.startup["bpj-productivity-affects-vanilla"].value
local productivity_bonus_per_level = settings.startup["bpj-productivity-research-bonus"].value

local function format_number(value)
  local rounded = math.floor(value * 100 + 0.5) / 100
  local text = string.format("%.2f", rounded)
  return text:gsub("%.?0+$", "")
end

local function format_percent(value)
  return format_number(value * 100) .. "%"
end

local function get_productivity_level(force)
  local tech = force.technologies["bpj-pumpjack-output"]

  if not tech or not tech.researched then
    return 0
  end

  local level = tech.level - 1

  for staged_level = 2, max_migration_scan_level do
    local staged_tech = force.technologies["bpj-pumpjack-output-" .. staged_level]

    if staged_tech and staged_tech.researched then
      level = math.max(level, staged_level - 1)
    end
  end

  if level < 0 then
    level = 0
  end

  if level > max_productivity_level then
    level = max_productivity_level
  end

  return level
end

local function get_base_name(name)
  if productivity_affects_vanilla
    and (name == "pumpjack" or string.match(name, "^pumpjack%-prod%-%d+$")) then
    return "pumpjack"
  end

  if name == "pumpjack-mk2" or string.match(name, "^pumpjack%-mk2%-prod%-%d+$") then
    return "pumpjack-mk2"
  end

  if name == "pumpjack-mk3" or string.match(name, "^pumpjack%-mk3%-prod%-%d+$") then
    return "pumpjack-mk3"
  end

  return nil
end

local function get_target_name(entity)
  local base_name = get_base_name(entity.name)
  if not base_name then return nil end

  local level = get_productivity_level(entity.force)

  if level <= 0 then
    return base_name
  end

  return base_name .. "-prod-" .. level
end

local function replace_pumpjack(entity)
  if not entity or not entity.valid then return end

  local target_name = get_target_name(entity)

  if not target_name or entity.name == target_name then
    return
  end

  local surface = entity.surface
  local position = entity.position
  local direction = entity.direction
  local force = entity.force
  local health = entity.health

  local modules = {}
  local module_inventory = entity.get_module_inventory()

  if module_inventory then
    for i = 1, #module_inventory do
      local stack = module_inventory[i]
      if stack and stack.valid_for_read then
        table.insert(modules, {name = stack.name, count = stack.count})
      end
    end
  end

  entity.destroy({raise_destroy = false})

  local new_entity = surface.create_entity({
    name = target_name,
    position = position,
    direction = direction,
    force = force,
    fast_replace = true,
    create_build_effect_smoke = false,
    raise_built = false
  })

  if new_entity and new_entity.valid then
    new_entity.health = health

    local new_module_inventory = new_entity.get_module_inventory()
    if new_module_inventory then
      for _, module in pairs(modules) do
        new_module_inventory.insert(module)
      end
    end
  end
end

local function update_all_pumpjacks(force, scan_level)
  scan_level = scan_level or max_productivity_level

  for _, surface in pairs(game.surfaces) do
    local names = {}

    local function add_entity_name(name)
      if prototypes.entity[name] then
        table.insert(names, name)
      end
    end

    add_entity_name("pumpjack-mk2")
    add_entity_name("pumpjack-mk3")

    if productivity_affects_vanilla then
      add_entity_name("pumpjack")
    end

    for level = 1, scan_level do
      if productivity_affects_vanilla then
        add_entity_name("pumpjack-prod-" .. level)
      end

      add_entity_name("pumpjack-mk2-prod-" .. level)
      add_entity_name("pumpjack-mk3-prod-" .. level)
    end

    if #names > 0 then
      local entities = surface.find_entities_filtered({
        force = force,
        name = names
      })

      for _, entity in pairs(entities) do
        replace_pumpjack(entity)
      end
    end
  end
end

local function is_pumpjack_productivity_research(name)
  return name == "bpj-pumpjack-output"
    or string.match(name, "^bpj%-pumpjack%-output%-%d+$")
end

local function print_productivity_status(force)
  local level = get_productivity_level(force)
  local bonus = productivity_bonus_per_level * level
  local targets = productivity_affects_vanilla
    and "vanilla pumpjacks, Pumpjack MK2, and Pumpjack MK3"
    or "Pumpjack MK2 and Pumpjack MK3"

  force.print(
    "Pumpjack productivity level "
    .. level
    .. ": +"
    .. format_percent(bonus)
    .. " productivity applied to "
    .. targets
    .. "."
  )
end

script.on_event(defines.events.on_research_finished, function(event)
  if is_pumpjack_productivity_research(event.research.name) then
    update_all_pumpjacks(event.research.force)
    print_productivity_status(event.research.force)
  end
end)

commands.add_command("bpj-refresh", "Refresh Better Pumpjacks productivity variants and print current productivity status.", function(command)
  local player = command.player_index and game.get_player(command.player_index)
  local force = player and player.force or game.forces.player

  update_all_pumpjacks(force, max_migration_scan_level)
  print_productivity_status(force)
end)

script.on_configuration_changed(function()
  for _, force in pairs(game.forces) do
    update_all_pumpjacks(force, max_migration_scan_level)
  end
end)

local function on_built(event)
  local entity = event.created_entity or event.entity

  if entity and entity.valid then
    replace_pumpjack(entity)
  end
end

script.on_event(defines.events.on_built_entity, on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)
script.on_event(defines.events.script_raised_built, on_built)
script.on_event(defines.events.script_raised_revive, on_built)
