local max_productivity_level = settings.startup["bpj-max-productivity-level"].value
local max_migration_scan_level = 500
local productivity_affects_vanilla = settings.startup["bpj-productivity-affects-vanilla"].value
local productivity_bonus_per_level = settings.startup["bpj-productivity-research-bonus"].value
local replacements_per_tick = 2
local function are_output_warnings_enabled()
  local setting = settings.global["bpj-output-warnings-enabled"]
  return not setting or setting.value
end

local function get_warning_repeat_interval()
  local setting = settings.global["bpj-warning-repeat-rate"]
  local seconds = setting and setting.value or 60

  if seconds < 1 then
    seconds = 1
  end

  return seconds * 60
end

local function get_warning_check_interval()
  local setting = settings.global["bpj-warning-sampling-rate"]
  local seconds = setting and setting.value or 60

  if seconds < 1 then
    seconds = 1
  end

  return seconds * 60
end

local warning_check_interval = get_warning_check_interval()
local warning_repeat_interval = get_warning_repeat_interval()
local mod_gui = require("__core__/lualib/mod-gui")
local dashboard_button_name = "bpj-dashboard-button"
local dashboard_frame_name = "bpj-dashboard-frame"
local surface_manager_frame_name = "bpj-surface-manager-frame"

local function format_number(value)
  local rounded = math.floor(value * 100 + 0.5) / 100
  local text = string.format("%.2f", rounded)
  return text:gsub("%.?0+$", "")
end

local function format_percent(value)
  return format_number(value * 100) .. "%"
end

local function get_output_thresholds(force_name, surface_name)
  storage.bpj_output_thresholds = storage.bpj_output_thresholds or {}
  storage.bpj_output_thresholds[force_name] = storage.bpj_output_thresholds[force_name] or {}
  storage.bpj_output_thresholds[force_name][surface_name] = storage.bpj_output_thresholds[force_name][surface_name] or {}

  return storage.bpj_output_thresholds[force_name][surface_name]
end

local function get_output_threshold(force_name, surface_name, fluid_name)
  local thresholds = get_output_thresholds(force_name, surface_name)
  return thresholds[fluid_name]
end

local function set_output_threshold(force_name, surface_name, fluid_name, value)
  local thresholds = get_output_thresholds(force_name, surface_name)

  if value and value >= 0 then
    thresholds[fluid_name] = value
  else
    thresholds[fluid_name] = nil
  end
end

local function has_output_thresholds(surface_thresholds)
  for _, fluid_thresholds in pairs(surface_thresholds or {}) do
    for _, threshold in pairs(fluid_thresholds) do
      if threshold then
        return true
      end
    end
  end

  return false
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

local function get_pumpjack_entity_names(scan_level)
  scan_level = scan_level or max_productivity_level

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

  return names
end

local function get_dashboard_base_name(name)
  if name == "pumpjack" or string.match(name, "^pumpjack%-prod%-%d+$") then
    return "pumpjack"
  end

  return get_base_name(name)
end

local function get_dashboard_pumpjack_entity_names(scan_level)
  scan_level = scan_level or max_productivity_level

  local names = {}

  local function add_entity_name(name)
    if prototypes.entity[name] then
      table.insert(names, name)
    end
  end

  add_entity_name("pumpjack")
  add_entity_name("pumpjack-mk2")
  add_entity_name("pumpjack-mk3")

  for level = 1, scan_level do
    add_entity_name("pumpjack-prod-" .. level)
    add_entity_name("pumpjack-mk2-prod-" .. level)
    add_entity_name("pumpjack-mk3-prod-" .. level)
  end

  return names
end

local cached_pumpjack_entity_names = nil
local cached_dashboard_pumpjack_entity_names = nil

local function get_cached_pumpjack_entity_names()
  if not cached_pumpjack_entity_names then
    cached_pumpjack_entity_names = get_pumpjack_entity_names(max_migration_scan_level)
  end
  return cached_pumpjack_entity_names
end

local function get_cached_dashboard_pumpjack_entity_names()
  if not cached_dashboard_pumpjack_entity_names then
    cached_dashboard_pumpjack_entity_names = get_dashboard_pumpjack_entity_names(max_migration_scan_level)
  end
  return cached_dashboard_pumpjack_entity_names
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

local function get_known_pumpjacks()
  storage.bpj_known_pumpjacks = storage.bpj_known_pumpjacks or {}
  return storage.bpj_known_pumpjacks
end

local function register_pumpjack(entity)
  if entity and entity.valid and entity.unit_number and get_base_name(entity.name) then
    get_known_pumpjacks()[entity.unit_number] = entity
  end
end

local function clear_queues()
  storage.bpj_update_queue = {}
  storage.bpj_update_queue_index = 1
end

local function replace_pumpjack(entity)
  if not entity or not entity.valid then return end

  local target_name = get_target_name(entity)

  if not target_name or entity.name == target_name then
    register_pumpjack(entity)
    return entity
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
        local inserted = new_module_inventory.insert(module)
        if inserted < module.count then
          new_entity.surface.spill_item_stack(
            new_entity.position,
            {name = module.name, count = module.count - inserted},
            true
          )
        end
      end
    end
  end

  register_pumpjack(new_entity)
  return new_entity
end

local function get_update_queue()
  storage.bpj_update_queue = storage.bpj_update_queue or {}
  storage.bpj_update_queue_index = storage.bpj_update_queue_index or 1
  return storage.bpj_update_queue
end

local function queue_pumpjack_update(entity)
  if not entity or not entity.valid then return end
  register_pumpjack(entity)

  local target_name = get_target_name(entity)
  if not target_name or entity.name == target_name then return end

  table.insert(get_update_queue(), entity)
end

local function queue_all_pumpjacks(force, scan_level)
  local names = scan_level and get_pumpjack_entity_names(scan_level) or get_cached_pumpjack_entity_names()

  if #names == 0 then return end

  for _, surface in pairs(game.surfaces) do
    local entities = surface.find_entities_filtered({
      force = force,
      name = names
    })

    for _, entity in pairs(entities) do
      queue_pumpjack_update(entity)
    end
  end
end

local function get_runtime_effect(entity, effect_name)
  local ok, effects = pcall(function() return entity.effects end)

  if ok and effects and effects[effect_name] then
    return effects[effect_name]
  end

  return 0
end

local function get_optional_runtime_effect(entity, effect_name)
  local ok, effects = pcall(function() return entity.effects end)

  if ok and effects and effects[effect_name] then
    return effects[effect_name]
  end

  return nil
end

local function get_entity_bonus(entity, bonus_name)
  local ok, bonus = pcall(function() return entity[bonus_name] end)

  if ok and bonus then
    return bonus
  end

  return nil
end

local function get_resource_normal_amount(resource)
  local ok, normal_amount = pcall(function()
    return resource.prototype.normal_resource_amount
  end)

  if ok and normal_amount and normal_amount > 0 then
    return normal_amount
  end

  return 100
end

local function is_infinite_resource(resource)
  local ok, infinite_resource = pcall(function()
    return resource.prototype.infinite_resource
  end)

  return ok and infinite_resource or false
end

local function get_resource_yield_percent(entity)
  local target = entity.mining_target

  if not target or not target.valid or not target.amount then
    return 0
  end

  if not is_infinite_resource(target) then
    return 100
  end

  return target.amount / get_resource_normal_amount(target) * 100
end

local function get_product_amount(product)
  if product.amount then
    return product.amount
  end

  if product.amount_min and product.amount_max then
    return (product.amount_min + product.amount_max) / 2 * (product.probability or 1)
  end

  return 0
end

local function get_resource_fluid_product(resource)
  local ok, mineable_properties = pcall(function()
    return resource.prototype.mineable_properties
  end)

  if not ok or not mineable_properties then
    return "crude-oil", 10
  end

  local mining_time = mineable_properties.mining_time or 1

  if mining_time <= 0 then
    mining_time = 1
  end

  for _, product in pairs(mineable_properties.products or {}) do
    if product.type == "fluid" then
      local amount = get_product_amount(product)

      if amount > 0 then
        return product.name, amount / mining_time
      end
    end
  end

  return "crude-oil", 10
end

local function get_resource_base_fluid_per_second(resource)
  local _, fluid_per_second = get_resource_fluid_product(resource)
  return fluid_per_second
end

local function get_tier_productivity(entity)
  local base_name = get_base_name(entity.name)

  if base_name == "pumpjack-mk2" then
    return settings.startup["bpj-mk2-productivity"].value
  elseif base_name == "pumpjack-mk3" then
    return settings.startup["bpj-mk3-productivity"].value
  end

  return 0
end

local function get_calculated_productivity(entity)
  local base_name = get_base_name(entity.name)

  if not base_name then
    return 0
  end

  local level = get_productivity_level(entity.force)
  local research_productivity = productivity_bonus_per_level * level

  if base_name == "pumpjack" and not productivity_affects_vanilla then
    research_productivity = 0
  end

  return get_tier_productivity(entity) + research_productivity
end

local function get_mining_speed(entity)
  local ok, mining_speed = pcall(function() return entity.prototype.mining_speed end)

  if ok and mining_speed then
    return mining_speed
  end

  return 1
end

local function estimate_resource_per_second(entity)
  local yield_percent = get_resource_yield_percent(entity)

  if yield_percent <= 0 then
    return 0
  end

  local mining_speed = get_mining_speed(entity)
  local speed_modifier = 1 + (get_entity_bonus(entity, "speed_bonus") or get_runtime_effect(entity, "speed"))
  local runtime_productivity = get_entity_bonus(entity, "productivity_bonus")
    or get_optional_runtime_effect(entity, "productivity")
  local productivity_modifier = 1

  if get_entity_bonus(entity, "productivity_bonus") then
    productivity_modifier = productivity_modifier + runtime_productivity
  elseif runtime_productivity then
    productivity_modifier = productivity_modifier + get_tier_productivity(entity) + runtime_productivity
  else
    productivity_modifier = productivity_modifier + get_calculated_productivity(entity)
  end

  return (yield_percent / 100)
    * get_resource_base_fluid_per_second(entity.mining_target)
    * mining_speed
    * speed_modifier
    * productivity_modifier
end

local function get_estimated_fluid_output(entity)
  local fluid_name = "crude-oil"

  if entity.mining_target and entity.mining_target.valid then
    fluid_name = get_resource_fluid_product(entity.mining_target)
  end

  return fluid_name, estimate_resource_per_second(entity)
end

local function ensure_fluid_total(totals, fluid_name)
  totals[fluid_name] = totals[fluid_name] or {
    amount = 0,
    yield_total = 0,
    count = 0,
    vanilla = 0,
    mk2 = 0,
    mk3 = 0
  }

  return totals[fluid_name]
end

local function add_fluid_total(totals, fluid_name, amount, base_name, yield_percent)
  local total = ensure_fluid_total(totals, fluid_name)
  total.amount = total.amount + amount
  total.yield_total = total.yield_total + (yield_percent or 0)
  total.count = total.count + 1

  if base_name == "pumpjack" then
    total.vanilla = total.vanilla + 1
  elseif base_name == "pumpjack-mk2" then
    total.mk2 = total.mk2 + 1
  elseif base_name == "pumpjack-mk3" then
    total.mk3 = total.mk3 + 1
  end
end

local function collect_dashboard_stats(force)
  local names = get_cached_dashboard_pumpjack_entity_names()
  local stats = {}

  for _, surface in pairs(game.surfaces) do
    stats[surface.name] = {
      total = 0,
      vanilla = 0,
      mk2 = 0,
      mk3 = 0,
      yield_total = 0,
      resource_per_second = 0,
      resource_per_second_by_fluid = {}
    }

    if #names > 0 then
      local entities = surface.find_entities_filtered({
        force = force,
        name = names
      })

      for _, entity in pairs(entities) do
        local base_name = get_dashboard_base_name(entity.name)

        if base_name then
          local surface_stats = stats[surface.name]
          local fluid_name, resource_per_second = get_estimated_fluid_output(entity)
          local yield_percent = get_resource_yield_percent(entity)
          surface_stats.total = surface_stats.total + 1
          surface_stats.yield_total = surface_stats.yield_total + yield_percent
          surface_stats.resource_per_second = surface_stats.resource_per_second + resource_per_second
          add_fluid_total(surface_stats.resource_per_second_by_fluid, fluid_name, resource_per_second, base_name, yield_percent)

          if base_name == "pumpjack" then
            surface_stats.vanilla = surface_stats.vanilla + 1
          elseif base_name == "pumpjack-mk2" then
            surface_stats.mk2 = surface_stats.mk2 + 1
          elseif base_name == "pumpjack-mk3" then
            surface_stats.mk3 = surface_stats.mk3 + 1
          end
        end
      end
    end
  end

  return stats
end

local function get_warning_state_key(force_name, surface_name, fluid_name)
  return force_name .. "\31" .. surface_name .. "\31" .. fluid_name
end

local function check_output_threshold_warnings()
  if not are_output_warnings_enabled() then return end

  storage.bpj_output_warning_state = storage.bpj_output_warning_state or {}

  local configured_thresholds = storage.bpj_output_thresholds
  if not configured_thresholds then return end

  for force_name, surface_thresholds in pairs(configured_thresholds) do
    local force = game.forces[force_name]

    if force and has_output_thresholds(surface_thresholds) then
      local stats = collect_dashboard_stats(force)

      for surface_name, fluid_thresholds in pairs(surface_thresholds) do
        local surface_stats = stats[surface_name]

        if surface_stats then
          for fluid_name, threshold in pairs(fluid_thresholds) do
            local fluid_total = surface_stats.resource_per_second_by_fluid[fluid_name]
            local amount = fluid_total and fluid_total.amount or 0
            local warning_key = get_warning_state_key(force_name, surface_name, fluid_name)
            local is_low = amount < threshold

            local last_warning_tick = storage.bpj_output_warning_state[warning_key]
            if type(last_warning_tick) ~= "number" then last_warning_tick = nil end

            if is_low and (not last_warning_tick or game.tick - last_warning_tick >= warning_repeat_interval) then
              force.print({
                "better-pumpjacks.output-warning-chat",
                surface_name,
                "[fluid=" .. fluid_name .. "] " .. fluid_name,
                format_number(amount),
                format_number(threshold)
              })

              storage.bpj_output_warning_state[warning_key] = game.tick
            elseif not is_low then
              storage.bpj_output_warning_state[warning_key] = nil
            end
          end
        end
      end
    end
  end
end

local function update_warning_check_interval()
  script.on_nth_tick(warning_check_interval, nil)
  warning_check_interval = get_warning_check_interval()
  warning_repeat_interval = get_warning_repeat_interval()

  if are_output_warnings_enabled() then
    script.on_nth_tick(warning_check_interval, check_output_threshold_warnings)
  end
end

local function remove_dashboard_button(player)
  local flow = mod_gui.get_button_flow(player)

  if flow and flow[dashboard_button_name] then
    flow[dashboard_button_name].destroy()
  end
end

local function destroy_dashboard(player)
  local frame = player.gui.screen[dashboard_frame_name]

  if frame then
    frame.destroy()
  end
end

local function get_hidden_surfaces(player)
  storage.bpj_hidden_surfaces = storage.bpj_hidden_surfaces or {}
  storage.bpj_hidden_surfaces[player.index] = storage.bpj_hidden_surfaces[player.index] or {}

  return storage.bpj_hidden_surfaces[player.index]
end

local function is_surface_visible(player, surface_name)
  return not get_hidden_surfaces(player)[surface_name]
end

local function get_surface_nicknames(player)
  storage.bpj_surface_nicknames = storage.bpj_surface_nicknames or {}
  storage.bpj_surface_nicknames[player.index] = storage.bpj_surface_nicknames[player.index] or {}

  return storage.bpj_surface_nicknames[player.index]
end

local function get_surface_display_name(player, surface_name)
  local nickname = get_surface_nicknames(player)[surface_name]

  if nickname and nickname ~= "" then
    return nickname
  end

  return surface_name
end

local function set_surface_nickname(player, surface_name, nickname)
  local nicknames = get_surface_nicknames(player)

  if nickname and nickname ~= "" then
    nicknames[surface_name] = nickname
  else
    nicknames[surface_name] = nil
  end
end

local function get_surface_order(player)
  storage.bpj_surface_order = storage.bpj_surface_order or {}
  storage.bpj_surface_order[player.index] = storage.bpj_surface_order[player.index] or {}

  return storage.bpj_surface_order[player.index]
end

local function get_all_surface_names_for_player(player)
  local existing = {}
  local names = {}

  for _, surface in pairs(game.surfaces) do
    existing[surface.name] = true
  end

  for _, surface_name in pairs(get_surface_order(player)) do
    if existing[surface_name] then
      table.insert(names, surface_name)
      existing[surface_name] = nil
    end
  end

  local remaining = {}

  for surface_name in pairs(existing) do
    table.insert(remaining, surface_name)
  end

  table.sort(remaining)

  for _, surface_name in pairs(remaining) do
    table.insert(names, surface_name)
  end

  storage.bpj_surface_order[player.index] = names
  return names
end

local function move_surface_order(player, surface_name, delta)
  local order = get_all_surface_names_for_player(player)
  local index = nil

  for i, ordered_surface_name in pairs(order) do
    if ordered_surface_name == surface_name then
      index = i
      break
    end
  end

  if not index then return end

  local target_index = index + delta

  if target_index < 1 or target_index > #order then return end

  order[index], order[target_index] = order[target_index], order[index]
  storage.bpj_surface_order[player.index] = order
end

local function get_sorted_surface_names(stats)
  local surface_names = {}

  for surface_name in pairs(stats) do
    table.insert(surface_names, surface_name)
  end

  table.sort(surface_names)
  return surface_names
end

local function get_visible_surface_names(player, stats)
  local surface_names = {}
  local stat_surfaces = {}

  for surface_name in pairs(stats) do
    stat_surfaces[surface_name] = true
  end

  for _, surface_name in pairs(get_all_surface_names_for_player(player)) do
    if stat_surfaces[surface_name] and is_surface_visible(player, surface_name) then
      table.insert(surface_names, surface_name)
    end
  end

  return surface_names
end

local function destroy_surface_manager(player)
  local frame = player.gui.screen[surface_manager_frame_name]

  if frame then
    frame.destroy()
  end
end

local function show_surface_manager(player)
  destroy_surface_manager(player)

  local hidden_surfaces = get_hidden_surfaces(player)
  storage.bpj_surface_nickname_inputs = storage.bpj_surface_nickname_inputs or {}
  storage.bpj_surface_nickname_inputs[player.index] = {}
  storage.bpj_surface_order_buttons = storage.bpj_surface_order_buttons or {}
  storage.bpj_surface_order_buttons[player.index] = {}
  local frame = player.gui.screen.add({
    type = "frame",
    name = surface_manager_frame_name,
    direction = "vertical"
  })
  frame.auto_center = true
  frame.style.width = 650

  local header = frame.add({type = "flow", direction = "horizontal"})
  header.drag_target = frame
  local title = header.add({
    type = "label",
    caption = {"better-pumpjacks.surface-manager-title"}
  })
  title.style.font = "default-bold"
  local spacer = header.add({type = "empty-widget", style = "draggable_space_header"})
  spacer.style.horizontally_stretchable = true
  spacer.style.height = 24
  spacer.drag_target = frame
  header.add({
    type = "sprite-button",
    name = "bpj-surface-manager-close",
    sprite = "utility/close",
    hovered_sprite = "utility/close_black",
    clicked_sprite = "utility/close_black",
    style = "frame_action_button"
  })

  local note = frame.add({
    type = "label",
    caption = {"better-pumpjacks.surface-manager-note"}
  })
  note.style.single_line = false

  local surfaces_frame = frame.add({
    type = "frame",
    direction = "vertical",
    style = "inside_shallow_frame_with_padding"
  })
  surfaces_frame.style.horizontally_stretchable = true

  local surfaces_header = surfaces_frame.add({
    type = "label",
    caption = {"better-pumpjacks.surface-manager-title"}
  })
  surfaces_header.style.font = "default-bold"
  surfaces_header.style.font_color = {r = 1, g = 0.86, b = 0.45}

  local surface_header_spacing = surfaces_frame.add({type = "empty-widget"})
  surface_header_spacing.style.height = 6

  local scroll = surfaces_frame.add({type = "scroll-pane"})
  scroll.style.maximal_height = 320
  scroll.style.horizontally_stretchable = true

  local surface_names = get_all_surface_names_for_player(player)

  local nickname_input_index = 0

  for _, surface_name in pairs(surface_names) do
    local row = scroll.add({type = "flow", direction = "horizontal"})
    row.style.horizontally_stretchable = true

    local checkbox = row.add({
      type = "checkbox",
      name = "bpj-surface-visible-" .. surface_name,
      caption = surface_name,
      state = not hidden_surfaces[surface_name]
    })
    checkbox.style.width = 120

    local nickname = get_surface_nicknames(player)[surface_name]
    nickname_input_index = nickname_input_index + 1
    local nickname_input_name = "bpj-surface-nickname-" .. nickname_input_index
    local nickname_input = row.add({
      type = "textfield",
      name = nickname_input_name,
      text = nickname or "",
      tooltip = {"better-pumpjacks.surface-manager-nickname-tooltip"}
    })
    nickname_input.style.width = 190
    storage.bpj_surface_nickname_inputs[player.index][nickname_input_name] = surface_name

    local up_name = "bpj-surface-order-up-" .. nickname_input_index
    local down_name = "bpj-surface-order-down-" .. nickname_input_index

    row.add({
      type = "button",
      name = up_name,
      caption = {"better-pumpjacks.surface-manager-up"},
      tooltip = {"better-pumpjacks.surface-manager-up-tooltip"}
    })
    row.add({
      type = "button",
      name = down_name,
      caption = {"better-pumpjacks.surface-manager-down"},
      tooltip = {"better-pumpjacks.surface-manager-down-tooltip"}
    })

    storage.bpj_surface_order_buttons[player.index][up_name] = {
      surface_name = surface_name,
      delta = -1
    }
    storage.bpj_surface_order_buttons[player.index][down_name] = {
      surface_name = surface_name,
      delta = 1
    }
  end
end

local function add_stat_label(parent, caption, width, align)
  local label = parent.add({type = "label", caption = caption})

  if width then
    label.style.width = width
  end

  if align then
    label.style.horizontal_align = align
  end

  return label
end

local function add_header_label(parent, caption, width, align)
  local label = add_stat_label(parent, caption, width, align)
  label.style.font = "default-bold"
  label.style.font_color = {r = 1, g = 0.86, b = 0.45}

  return label
end

local function get_dashboard_surface_name(player)
  storage.bpj_dashboard_surface = storage.bpj_dashboard_surface or {}
  local surface_name = storage.bpj_dashboard_surface[player.index]

  if surface_name and game.surfaces[surface_name] and is_surface_visible(player, surface_name) then
    return surface_name
  end

  storage.bpj_dashboard_surface[player.index] = nil
  return nil
end

local function add_surface_stats_to_totals(surface_stats, totals)
  totals.pumpjacks = totals.pumpjacks + surface_stats.total
  totals.vanilla = totals.vanilla + surface_stats.vanilla
  totals.mk2 = totals.mk2 + surface_stats.mk2
  totals.mk3 = totals.mk3 + surface_stats.mk3
  totals.resource_per_second = totals.resource_per_second + surface_stats.resource_per_second

  for fluid_name, total in pairs(surface_stats.resource_per_second_by_fluid) do
    local combined_total = ensure_fluid_total(totals.resource_per_second_by_fluid, fluid_name)
    combined_total.amount = combined_total.amount + total.amount
    combined_total.yield_total = combined_total.yield_total + total.yield_total
    combined_total.count = combined_total.count + total.count
    combined_total.vanilla = combined_total.vanilla + total.vanilla
    combined_total.mk2 = combined_total.mk2 + total.mk2
    combined_total.mk3 = combined_total.mk3 + total.mk3
  end
end

local function show_dashboard(player)
  destroy_dashboard(player)

  local force = player.force
  local level = get_productivity_level(force)
  local bonus = productivity_bonus_per_level * level
  local productivity_text = "Level " .. format_number(level) .. " (+" .. format_percent(bonus) .. ")"
  local stats = collect_dashboard_stats(force)
  local surface_names = get_visible_surface_names(player, stats)
  local selected_surface_name = get_dashboard_surface_name(player)
  local totals = {
    pumpjacks = 0,
    vanilla = 0,
    mk2 = 0,
    mk3 = 0,
    resource_per_second = 0,
    resource_per_second_by_fluid = {}
  }

  if selected_surface_name and stats[selected_surface_name] then
    add_surface_stats_to_totals(stats[selected_surface_name], totals)
  else
    for _, surface_name in pairs(surface_names) do
      add_surface_stats_to_totals(stats[surface_name], totals)
    end
  end

  storage.bpj_dashboard_threshold_inputs = storage.bpj_dashboard_threshold_inputs or {}
  storage.bpj_dashboard_threshold_inputs[player.index] = {}

  local frame = player.gui.screen.add({
    type = "frame",
    name = dashboard_frame_name,
    direction = "vertical"
  })

  frame.auto_center = true
  frame.style.width = 760
  frame.style.maximal_height = 520

  local header = frame.add({type = "flow", direction = "horizontal"})
  header.drag_target = frame
  local title_label = header.add({
    type = "label",
    caption = {"better-pumpjacks.dashboard-title"}
  })
  title_label.style.font = "default-bold"
  local spacer = header.add({type = "empty-widget", style = "draggable_space_header"})
  spacer.style.horizontally_stretchable = true
  spacer.style.height = 24
  spacer.drag_target = frame
  header.add({
    type = "sprite-button",
    name = "bpj-dashboard-close",
    sprite = "utility/close",
    hovered_sprite = "utility/close_black",
    clicked_sprite = "utility/close_black",
    style = "frame_action_button"
  })

  local surface_items = {{"better-pumpjacks.dashboard-all-surfaces"}}
  local selected_surface_index = 1

  for index, surface_name in pairs(surface_names) do
    table.insert(surface_items, get_surface_display_name(player, surface_name))

    if surface_name == selected_surface_name then
      selected_surface_index = index + 1
    end
  end

  local summary_frame = frame.add({
    type = "frame",
    direction = "horizontal",
    style = "inside_shallow_frame_with_padding"
  })
  summary_frame.style.horizontally_stretchable = true

  local function add_summary_item(caption, value, icon, tooltip, width)
    local flow = summary_frame.add({type = "flow", direction = "vertical"})
    flow.style.width = width or 230
    flow.tooltip = tooltip

    local caption_flow = flow.add({type = "flow", direction = "horizontal"})
    if icon then
      local icon_label = caption_flow.add({type = "label", caption = icon})
      icon_label.tooltip = tooltip
    end

    local caption_label = caption_flow.add({
      type = "label",
      caption = caption
    })
    caption_label.style.font = "default-bold"
    caption_label.style.font_color = {r = 1, g = 0.86, b = 0.45}
    caption_label.tooltip = tooltip

    local value_label = flow.add({type = "label", caption = value})
    value_label.style.font = "default-bold"
    value_label.tooltip = tooltip
  end

  add_summary_item(
    {"better-pumpjacks.dashboard-productivity-level"},
    productivity_text,
    "[technology=bpj-pumpjack-output]",
    nil,
    230
  )
  add_summary_item(
    {"better-pumpjacks.dashboard-total-resource-second"},
    format_number(totals.resource_per_second),
    "[img=bpj-fluids-icon]",
    {"better-pumpjacks.dashboard-estimate-note"},
    150
  )
  local summary_spacer = summary_frame.add({type = "empty-widget"})
  summary_spacer.style.width = 118
  add_summary_item(
    {"better-pumpjacks.dashboard-total-pumpjacks"},
    format_number(totals.pumpjacks),
    "[item=pumpjack-mk3]",
    {
      "better-pumpjacks.dashboard-pumpjack-tooltip",
      format_number(totals.vanilla),
      format_number(totals.mk2),
      format_number(totals.mk3)
    },
    120
  )

  local products_frame = frame.add({
    type = "frame",
    direction = "vertical",
    style = "inside_shallow_frame_with_padding"
  })
  products_frame.style.horizontally_stretchable = true

  local threshold_enabled = selected_surface_name ~= nil

  if not threshold_enabled then
    local threshold_note = products_frame.add({
      type = "label",
      caption = {"better-pumpjacks.dashboard-threshold-select-surface"}
    })
    threshold_note.style.font_color = {r = 0.72, g = 0.72, b = 0.72}
  end

  local threshold_header = products_frame.add({type = "flow", direction = "horizontal"})
  threshold_header.style.horizontally_stretchable = true
  add_header_label(threshold_header, {"better-pumpjacks.dashboard-product"}, 230)
  add_header_label(threshold_header, {"better-pumpjacks.dashboard-resource-second"}, 150)

  if threshold_enabled then
    add_header_label(threshold_header, {"better-pumpjacks.dashboard-warning-threshold"}, 90)
  else
    local threshold_header_placeholder = threshold_header.add({type = "empty-widget"})
    threshold_header_placeholder.style.width = 90
  end

  local threshold_header_spacer = threshold_header.add({type = "empty-widget"})
  threshold_header_spacer.style.width = 28
  local pumpjack_header = threshold_header.add({type = "flow", direction = "vertical"})
  pumpjack_header.style.width = 120
  add_header_label(pumpjack_header, {"better-pumpjacks.dashboard-pumpjacks"})

  local product_header_spacing = products_frame.add({type = "empty-widget"})
  product_header_spacing.style.height = 8

  local fluid_names = {}

  for fluid_name in pairs(totals.resource_per_second_by_fluid) do
    table.insert(fluid_names, fluid_name)
  end

  table.sort(fluid_names)

  local threshold_input_index = 0

  for _, fluid_name in pairs(fluid_names) do
    local fluid_total = totals.resource_per_second_by_fluid[fluid_name]
    local warning_threshold = threshold_enabled and get_output_threshold(force.name, selected_surface_name, fluid_name) or nil
    local is_low_output = warning_threshold and fluid_total.amount < warning_threshold
    local warning_tooltip = is_low_output and {
      "better-pumpjacks.dashboard-low-output-warning",
      format_number(fluid_total.amount),
      format_number(warning_threshold)
    } or nil
    local row = products_frame.add({type = "flow", direction = "horizontal"})
    row.style.horizontally_stretchable = true

    local product_label = row.add({
      type = "label",
      caption = "[fluid=" .. fluid_name .. "] " .. fluid_name
    })
    product_label.style.width = 230
    product_label.tooltip = warning_tooltip

    if is_low_output then
      product_label.style.font_color = {r = 1, g = 0.75, b = 0.25}
    end

    local tier_text = {}

    if fluid_total.vanilla > 0 then
      table.insert(tier_text, "[item=pumpjack] x " .. format_number(fluid_total.vanilla))
    end

    if fluid_total.mk2 > 0 then
      table.insert(tier_text, "[item=pumpjack-mk2] x " .. format_number(fluid_total.mk2))
    end

    if fluid_total.mk3 > 0 then
      table.insert(tier_text, "[item=pumpjack-mk3] x " .. format_number(fluid_total.mk3))
    end

    local amount_label = row.add({
      type = "label",
      caption = format_number(fluid_total.amount) .. "/s"
    })
    amount_label.style.width = 150
    amount_label.style.font = "default-bold"
    amount_label.tooltip = warning_tooltip

    if is_low_output then
      amount_label.style.font_color = {r = 1, g = 0.75, b = 0.25}
    end

    if threshold_enabled then
      threshold_input_index = threshold_input_index + 1
      local threshold_input_name = "bpj-dashboard-output-threshold-" .. threshold_input_index
      local threshold_input = row.add({
        type = "textfield",
        name = threshold_input_name,
        text = warning_threshold and format_number(warning_threshold) or "",
        numeric = true,
        allow_decimal = true,
        allow_negative = false,
        tooltip = {"better-pumpjacks.dashboard-output-threshold-tooltip"}
      })
      threshold_input.style.width = 90
      storage.bpj_dashboard_threshold_inputs[player.index][threshold_input_name] = {
        force_name = force.name,
        surface_name = selected_surface_name,
        fluid_name = fluid_name
      }
    else
      local threshold_spacer = row.add({type = "empty-widget"})
      threshold_spacer.style.width = 90
    end

    local tier_spacer = row.add({type = "empty-widget"})
    tier_spacer.style.width = 28

    local tiers_label = row.add({
      type = "label",
      caption = table.concat(tier_text, "  ")
    })
    tiers_label.style.horizontally_stretchable = true
    tiers_label.tooltip = warning_tooltip

    if is_low_output then
      tiers_label.style.font_color = {r = 1, g = 0.75, b = 0.25}
      row.add({type = "label", caption = "LOW", tooltip = warning_tooltip}).style.font_color = {r = 1, g = 0.75, b = 0.25}
    end
  end

  local scroll_pane = frame.add({type = "scroll-pane"})
  scroll_pane.style.horizontally_stretchable = true
  scroll_pane.style.vertically_stretchable = true
  scroll_pane.style.maximal_height = 340

  local table_element = scroll_pane.add({
    type = "table",
    name = "bpj-dashboard-table",
    column_count = 8
  })
  table_element.style.horizontally_stretchable = true

  add_header_label(table_element, {"better-pumpjacks.dashboard-surface"}, 150)
  add_header_label(table_element, {"better-pumpjacks.dashboard-productivity"}, 100, "right")
  add_header_label(table_element, {"better-pumpjacks.dashboard-vanilla"}, 70, "right")
  add_header_label(table_element, {"better-pumpjacks.dashboard-mk2"}, 60, "right")
  add_header_label(table_element, {"better-pumpjacks.dashboard-mk3"}, 60, "right")
  add_header_label(table_element, {"better-pumpjacks.dashboard-total"}, 60, "right")
  add_header_label(table_element, {"better-pumpjacks.dashboard-yield"}, 80, "right")
  add_header_label(table_element, {"better-pumpjacks.dashboard-resource-second"}, 90, "right")

  for _, surface_name in pairs(surface_names) do
    if not selected_surface_name or surface_name == selected_surface_name then
      local surface_stats = stats[surface_name]
      local average_yield = 0

      if surface_stats.total > 0 then
        average_yield = surface_stats.yield_total / surface_stats.total
      end

      add_stat_label(table_element, get_surface_display_name(player, surface_name), 150)
      add_stat_label(table_element, productivity_text, 100, "right")
      add_stat_label(table_element, format_number(surface_stats.vanilla), 70, "right")
      add_stat_label(table_element, format_number(surface_stats.mk2), 60, "right")
      add_stat_label(table_element, format_number(surface_stats.mk3), 60, "right")
      add_stat_label(table_element, format_number(surface_stats.total), 60, "right")
      add_stat_label(table_element, format_percent(average_yield / 100), 80, "right")
      add_stat_label(table_element, format_number(surface_stats.resource_per_second), 90, "right")
    end
  end

  local footer = frame.add({type = "flow", direction = "horizontal"})
  footer.style.horizontally_stretchable = true
  footer.style.top_margin = 6

  footer.add({
    type = "label",
    caption = {"better-pumpjacks.dashboard-surface-filter"}
  })

  local surface_dropdown = footer.add({
    type = "drop-down",
    name = "bpj-dashboard-surface-dropdown",
    items = surface_items,
    selected_index = selected_surface_index
  })
  surface_dropdown.style.width = 220

  footer.add({
    type = "button",
    name = "bpj-surface-manager-open",
    caption = {"better-pumpjacks.surface-manager-button"}
  })

  local footer_spacer = footer.add({type = "empty-widget"})
  footer_spacer.style.horizontally_stretchable = true

  footer.add({
    type = "button",
    name = "bpj-dashboard-refresh",
    caption = {"better-pumpjacks.dashboard-refresh"}
  })
end

local function toggle_dashboard(player)
  if player.gui.screen[dashboard_frame_name] then
    destroy_dashboard(player)
  else
    show_dashboard(player)
  end
end

local function queue_known_pumpjacks(force)
  local known = get_known_pumpjacks()
  local compacted = {}
  local count = 0

  for unit_number, entity in pairs(known) do
    if entity and entity.valid and get_base_name(entity.name) then
      compacted[unit_number] = entity
      count = count + 1

      if entity.force == force then
        queue_pumpjack_update(entity)
      end
    end
  end

  storage.bpj_known_pumpjacks = compacted
  return count
end

local function rebuild_known_pumpjacks()
  clear_queues()
  storage.bpj_known_pumpjacks = {}

  for _, force in pairs(game.forces) do
    queue_all_pumpjacks(force, max_migration_scan_level)
  end
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
    clear_queues()

    if queue_known_pumpjacks(event.research.force) == 0 then
      queue_all_pumpjacks(event.research.force, max_migration_scan_level)
    end

    print_productivity_status(event.research.force)
  end
end)

commands.add_command("bpj-refresh", "Refresh Better Pumpjacks productivity variants and print current productivity status.", function(command)
  local player = command.player_index and game.get_player(command.player_index)
  local force = player and player.force or game.forces.player

  clear_queues()
  storage.bpj_known_pumpjacks = {}
  queue_all_pumpjacks(force, max_migration_scan_level)
  print_productivity_status(force)
end)

commands.add_command("bpj-level", "Print the current Better Pumpjacks productivity level and bonus.", function(command)
  local player = command.player_index and game.get_player(command.player_index)
  local force = player and player.force or game.forces.player

  print_productivity_status(force)
end)

commands.add_command("bpj-dashboard", "Open the Better Pumpjacks dashboard.", function(command)
  local player = command.player_index and game.get_player(command.player_index)

  if player then
    toggle_dashboard(player)
  end
end)

script.on_configuration_changed(function()
  rebuild_known_pumpjacks()

  for _, player in pairs(game.players) do
    remove_dashboard_button(player)
  end
end)

script.on_init(function()
  rebuild_known_pumpjacks()

  for _, player in pairs(game.players) do
    remove_dashboard_button(player)
  end
end)

script.on_event(defines.events.on_tick, function()
  process_update_queue()
end)

if are_output_warnings_enabled() then
  script.on_nth_tick(warning_check_interval, check_output_threshold_warnings)
end


script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting == "bpj-warning-sampling-rate"
    or event.setting == "bpj-output-warnings-enabled"
    or event.setting == "bpj-warning-repeat-rate" then
    update_warning_check_interval()
  end
end)

local function on_built(event)
  local entity = event.created_entity or event.entity

  if entity and entity.valid then
    register_pumpjack(replace_pumpjack(entity))
  end
end

script.on_event(defines.events.on_built_entity, on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)
script.on_event(defines.events.script_raised_built, on_built)
script.on_event(defines.events.script_raised_revive, on_built)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)

  if player then
    remove_dashboard_button(player)
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element

  if not element or not element.valid then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  if element.name == "bpj-dashboard-close" then
    destroy_dashboard(player)
  elseif element.name == "bpj-dashboard-refresh" then
    show_dashboard(player)
  elseif element.name == "bpj-surface-manager-open" then
    show_surface_manager(player)
  elseif element.name == "bpj-surface-manager-close" then
    destroy_surface_manager(player)

    if player.gui.screen[dashboard_frame_name] then
      show_dashboard(player)
    end
  else
    local order_buttons = storage.bpj_surface_order_buttons and storage.bpj_surface_order_buttons[player.index]
    local order_action = order_buttons and order_buttons[element.name]

    if order_action then
      move_surface_order(player, order_action.surface_name, order_action.delta)
      show_surface_manager(player)
    end
  end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
  local element = event.element

  if not element or not element.valid then return end

  local surface_name = string.match(element.name, "^bpj%-surface%-visible%-(.+)$")
  if not surface_name then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  local hidden_surfaces = get_hidden_surfaces(player)

  if element.state then
    hidden_surfaces[surface_name] = nil
  else
    hidden_surfaces[surface_name] = true

    if storage.bpj_dashboard_surface and storage.bpj_dashboard_surface[player.index] == surface_name then
      storage.bpj_dashboard_surface[player.index] = nil
    end
  end

end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
  local element = event.element

  if not element or not element.valid or element.name ~= "bpj-dashboard-surface-dropdown" then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  storage.bpj_dashboard_surface = storage.bpj_dashboard_surface or {}

  if element.selected_index <= 1 then
    storage.bpj_dashboard_surface[player.index] = nil
  else
    local stats = collect_dashboard_stats(player.force)
    local surface_names = get_visible_surface_names(player, stats)
    storage.bpj_dashboard_surface[player.index] = surface_names[element.selected_index - 1]
  end

  show_dashboard(player)
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
  local element = event.element

  if not element or not element.valid then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  local nickname_inputs = storage.bpj_surface_nickname_inputs and storage.bpj_surface_nickname_inputs[player.index]
  local nickname_surface_name = nickname_inputs and nickname_inputs[element.name]

  if nickname_surface_name then
    local text = string.match(element.text or "", "^%s*(.-)%s*$")
    set_surface_nickname(player, nickname_surface_name, text)
    return
  end

  local inputs = storage.bpj_dashboard_threshold_inputs and storage.bpj_dashboard_threshold_inputs[player.index]
  local threshold_target = inputs and inputs[element.name]

  if not threshold_target then return end

  local text = string.match(element.text or "", "^%s*(.-)%s*$")

  if text == "" then
    set_output_threshold(threshold_target.force_name, threshold_target.surface_name, threshold_target.fluid_name, nil)
    storage.bpj_output_warning_state = storage.bpj_output_warning_state or {}
    storage.bpj_output_warning_state[get_warning_state_key(
      threshold_target.force_name,
      threshold_target.surface_name,
      threshold_target.fluid_name
    )] = nil
    return
  end

  local value = tonumber(text)

  if value then
    set_output_threshold(threshold_target.force_name, threshold_target.surface_name, threshold_target.fluid_name, value)
    storage.bpj_output_warning_state = storage.bpj_output_warning_state or {}
    storage.bpj_output_warning_state[get_warning_state_key(
      threshold_target.force_name,
      threshold_target.surface_name,
      threshold_target.fluid_name
    )] = nil
  end
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name ~= "bpj-toggle-dashboard" then return end

  local player = game.get_player(event.player_index)

  if player then
    toggle_dashboard(player)
  end
end)

script.on_event("bpj-toggle-dashboard", function(event)
  local player = game.get_player(event.player_index)

  if player then
    toggle_dashboard(player)
  end
end)

remote.add_interface("better_pumpjacks", {
  get_productivity_level = function(force_name)
    local force = game.forces[force_name]

    if not force then
      return 0
    end

    return get_productivity_level(force)
  end,

  get_productivity_bonus = function(force_name)
    local force = game.forces[force_name]

    if not force then
      return 0
    end

    return get_productivity_level(force) * productivity_bonus_per_level
  end,

  get_productivity_bonus_per_level = function()
    return productivity_bonus_per_level
  end,

  get_max_productivity_level = function()
    return max_productivity_level
  end,

  get_base_name = function(entity_name)
    return get_dashboard_base_name(entity_name)
  end,

  is_better_pumpjack = function(entity_name)
    return get_dashboard_base_name(entity_name) ~= nil
  end,

  get_target_name = function(force_name, base_name)
    local force = game.forces[force_name]

    if not force or not get_dashboard_base_name(base_name) then
      return nil
    end

    local level = get_productivity_level(force)

    if level <= 0 then
      return base_name
    end

    if base_name == "pumpjack" and not productivity_affects_vanilla then
      return "pumpjack"
    end

    local target_name = base_name .. "-prod-" .. level

    if prototypes.entity[target_name] then
      return target_name
    end

    return base_name
  end,

  get_known_entity_names = function()
    return get_cached_dashboard_pumpjack_entity_names()
  end,

  productivity_affects_vanilla = function()
    return productivity_affects_vanilla
  end,

  get_output_stats = function(force_name)
    local force = game.forces[force_name]

    if not force then
      return nil
    end

    return collect_dashboard_stats(force)
  end,

  get_output_threshold = function(force_name, surface_name, fluid_name)
    return get_output_threshold(force_name, surface_name, fluid_name)
  end,

  get_output_thresholds = function(force_name, surface_name)
    return get_output_thresholds(force_name, surface_name)
  end,

  is_output_below_threshold = function(force_name, surface_name, fluid_name)
    local threshold = get_output_threshold(force_name, surface_name, fluid_name)

    if not threshold then
      return false
    end

    local force = game.forces[force_name]

    if not force then
      return false
    end

    local stats = collect_dashboard_stats(force)
    local surface_stats = stats[surface_name]

    if not surface_stats then
      return false
    end

    local fluid_total = surface_stats.resource_per_second_by_fluid[fluid_name]
    local amount = fluid_total and fluid_total.amount or 0

    return amount < threshold
  end
})
