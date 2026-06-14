local max_productivity_level = settings.startup["bpj-max-productivity-level"].value
local max_migration_scan_level = 500
local productivity_affects_vanilla = settings.startup["bpj-productivity-affects-vanilla"].value
local productivity_bonus_per_level = settings.startup["bpj-productivity-research-bonus"].value
local replacements_per_tick = 10
local scans_per_tick = 5

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

  if not tech then
    return 0
  end

  local level = 0

  if tech.level and tech.level > 1 then
    level = tech.level - 1
  elseif tech.researched then
    level = 1
  end

  for staged_level = 2, max_migration_scan_level do
    local staged_tech = force.technologies["bpj-pumpjack-output-" .. staged_level]

    if staged_tech then
      if staged_tech.researched then
        level = math.max(level, staged_level)
      end

      if staged_tech.level and staged_tech.level > staged_level then
        level = math.max(level, staged_tech.level - 1)
      end
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

local function get_update_queue()
  storage.bpj_update_queue = storage.bpj_update_queue or {}
  storage.bpj_update_queue_index = storage.bpj_update_queue_index or 1
  return storage.bpj_update_queue
end

local function get_scan_queue()
  storage.bpj_scan_queue = storage.bpj_scan_queue or {}
  storage.bpj_scan_queue_index = storage.bpj_scan_queue_index or 1
  return storage.bpj_scan_queue
end

local function queue_pumpjack_update(entity)
  if not entity or not entity.valid then return end

  local target_name = get_target_name(entity)
  if not target_name or entity.name == target_name then return end

  table.insert(get_update_queue(), entity)
end

local function queue_all_pumpjacks(force, scan_level)
  scan_level = scan_level or max_productivity_level
  storage.bpj_scan_queue = {}
  storage.bpj_scan_queue_index = 1
  storage.bpj_update_queue = {}
  storage.bpj_update_queue_index = 1

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

  if #names == 0 then return end

  for _, surface in pairs(game.surfaces) do
    table.insert(get_scan_queue(), {
      force_name = force.name,
      surface_index = surface.index,
      names = names,
      name_index = 1
    })
  end
end

local function process_scan_queue()
  local queue = get_scan_queue()
  local queue_index = storage.bpj_scan_queue_index

  for _ = 1, scans_per_tick do
    local task = queue[queue_index]

    if not task then
      storage.bpj_scan_queue = {}
      storage.bpj_scan_queue_index = 1
      return
    end

    local force = game.forces[task.force_name]
    local surface = game.surfaces[task.surface_index]
    local name = task.names[task.name_index]

    if force and surface and name then
      local entities = surface.find_entities_filtered({
        force = force,
        name = name
      })

      for _, entity in pairs(entities) do
        queue_pumpjack_update(entity)
      end
    end

    task.name_index = task.name_index + 1

    if not task.names[task.name_index] then
      queue_index = queue_index + 1
    end
  end

  storage.bpj_scan_queue_index = queue_index
end

local function process_update_queue()
  local queue = get_update_queue()
  local queue_index = storage.bpj_update_queue_index

  for _ = 1, replacements_per_tick do
    local entity = queue[queue_index]

    if not entity then
      storage.bpj_update_queue = {}
      storage.bpj_update_queue_index = 1
      return
    end

    replace_pumpjack(entity)
    queue_index = queue_index + 1
  end

  storage.bpj_update_queue_index = queue_index
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
    queue_all_pumpjacks(event.research.force)
    print_productivity_status(event.research.force)
  end
end)

commands.add_command("bpj-refresh", "Refresh Better Pumpjacks productivity variants and print current productivity status.", function(command)
  local player = command.player_index and game.get_player(command.player_index)
  local force = player and player.force or game.forces.player

  queue_all_pumpjacks(force, max_migration_scan_level)
  print_productivity_status(force)
end)

commands.add_command("bpj-level", "Print the current Better Pumpjacks productivity level and bonus.", function(command)
  local player = command.player_index and game.get_player(command.player_index)
  local force = player and player.force or game.forces.player

  print_productivity_status(force)
end)

script.on_configuration_changed(function()
  for _, force in pairs(game.forces) do
    queue_all_pumpjacks(force, max_migration_scan_level)
  end
end)

script.on_event(defines.events.on_tick, function()
  process_scan_queue()
  process_update_queue()
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
