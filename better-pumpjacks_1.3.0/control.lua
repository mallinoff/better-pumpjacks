local max_productivity_level = 50

local function get_productivity_level(force)
  local tech = force.technologies["bpj-pumpjack-output"]

  if not tech or not tech.researched then
    return 0
  end

  local level = tech.level - 1

  if level < 0 then
    level = 0
  end

  if level > max_productivity_level then
    level = max_productivity_level
  end

  return level
end

local function get_base_name(name)
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

local function update_all_pumpjacks(force)
  for _, surface in pairs(game.surfaces) do
    local names = {
      "pumpjack-mk2",
      "pumpjack-mk3"
    }

    for level = 1, max_productivity_level do
      table.insert(names, "pumpjack-mk2-prod-" .. level)
      table.insert(names, "pumpjack-mk3-prod-" .. level)
    end

    local entities = surface.find_entities_filtered({
      force = force,
      name = names
    })

    for _, entity in pairs(entities) do
      replace_pumpjack(entity)
    end
  end
end

script.on_event(defines.events.on_research_finished, function(event)
  if event.research.name == "bpj-pumpjack-output" then
    update_all_pumpjacks(event.research.force)
  end
end)

script.on_configuration_changed(function()
  for _, force in pairs(game.forces) do
    update_all_pumpjacks(force)
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