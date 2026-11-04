local max_productivity_level = settings.startup["bpj-max-productivity-level"].value
local max_staged_research_level = 500
local productivity_affects_vanilla = settings.startup["bpj-productivity-affects-vanilla"].value
local productivity_bonus_per_level = settings.startup["bpj-productivity-research-bonus"].value
local updates_per_tick = 2
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
local extraction_frame_name = "bpj-extraction-mode-frame"
local extraction_dropdown_name = "bpj-extraction-mode-dropdown"
local extraction_circuit_name = "bpj-extraction-mode-circuit"
local extraction_active_name = "bpj-extraction-mode-active"
local extraction_fallback_name = "bpj-extraction-mode-fallback"
local extraction_signals_name = "bpj-extraction-signals"
local conservation_picker_name = "bpj-conservation-signal"
local overdrive_picker_name = "bpj-overdrive-signal"
local circuit_poll_interval = 30
local default_circuit_signals = {
  [conservation_picker_name] = {type = "virtual", name = "bpj-conserve"},
  [overdrive_picker_name] = {type = "virtual", name = "bpj-overdrive"}
}
local standard_mode = 2
local extraction_modes = {
  {speed = -0.35, consumption = 0, caption = {"better-pumpjacks.extraction-mode-conservation"}},
  {speed = 0, consumption = 0, caption = {"better-pumpjacks.extraction-mode-standard"}},
  {speed = 0.5, consumption = 1, caption = {"better-pumpjacks.extraction-mode-overdrive"}}
}
local mode_tooltip_name = "better-pumpjacks.extraction-mode-tooltip-name"
local mode_tooltip_order = 0
local supports_runtime_tooltips

local function format_number(value)
  local rounded = math.floor(value * 100 + 0.5) / 100
  local text = string.format("%.2f", rounded)
  return text:gsub("%.?0+$", "")
end

local function format_percent(value)
  return format_number(value * 100) .. "%"
end

local function surface_index(surface_name)
  local surface = game.surfaces[surface_name]
  return surface and surface.index or nil
end

local function migrate_surface_settings()
  if storage.bpj_surface_settings_version == 1 then return end
  for _, key in ipairs({"bpj_output_thresholds", "bpj_hidden_surfaces", "bpj_surface_nicknames"}) do
    for owner, entries in pairs(storage[key] or {}) do
      local converted = {}
      for name, value in pairs(entries) do
        local index = surface_index(name)
        if index then converted[index] = value end
      end
      storage[key][owner] = converted
    end
  end
  for player_index, entries in pairs(storage.bpj_surface_order or {}) do
    local converted = {}
    for _, name in ipairs(entries) do
      local index = surface_index(name)
      if index then table.insert(converted, index) end
    end
    storage.bpj_surface_order[player_index] = converted
  end
  for player_index, name in pairs(storage.bpj_dashboard_surface or {}) do
    storage.bpj_dashboard_surface[player_index] = surface_index(name)
  end
  -- Old cooldown keys contain names; restart their intervals after migration.
  storage.bpj_output_warning_state = {}
  storage.bpj_surface_settings_version = 1
end

local function get_output_thresholds(force_name, surface_name)
  migrate_surface_settings()
  local index = surface_index(surface_name)
  if not index then return {} end
  storage.bpj_output_thresholds = storage.bpj_output_thresholds or {}
  storage.bpj_output_thresholds[force_name] = storage.bpj_output_thresholds[force_name] or {}
  storage.bpj_output_thresholds[force_name][index] = storage.bpj_output_thresholds[force_name][index] or {}

  return storage.bpj_output_thresholds[force_name][index]
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
    level = tech.researched and tech.level or tech.level - 1
  elseif tech.researched then
    level = 1
  end

  for staged_level = 2, max_staged_research_level do
    local staged_tech = force.technologies["bpj-pumpjack-output-" .. staged_level]

    if staged_tech then
      if staged_tech.researched then
        level = math.max(level, staged_tech.level or staged_level)
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

local pumpjack_names = {"pumpjack", "pumpjack-mk2", "pumpjack-mk3"}

local function get_base_name(name)
  for _, base in ipairs(pumpjack_names) do
    if name == base or string.match(name, "^" .. base:gsub("%-", "%%-") .. "%-prod%-%d+$") then
      return base
    end
  end
end

local function get_cached_dashboard_pumpjack_entity_names()
  return pumpjack_names
end

local function get_known_pumpjacks()
  storage.bpj_known_pumpjacks = storage.bpj_known_pumpjacks or {}
  return storage.bpj_known_pumpjacks
end

local function can_set_extraction_mode(player, entity)
  return entity and entity.valid and entity.object_name == "LuaEntity"
    and entity.force == player.force
    and (entity.name == "pumpjack-mk2" or entity.name == "pumpjack-mk3")
end

local function get_extraction_mode(entity)
  local modes = storage.bpj_extraction_modes
  return modes and modes[entity.unit_number] or standard_mode
end

local function update_mode_tooltip(entity)
  if not entity or not entity.valid or (entity.name ~= "pumpjack-mk2" and entity.name ~= "pumpjack-mk3") then return end
  if supports_runtime_tooltips == nil then
    -- Older Factorio 2.1 builds can raise an error when an unknown LuaEntity member is read.
    local ok, method = pcall(function() return entity.set_tooltip_field end)
    supports_runtime_tooltips = ok and method ~= nil
  end
  if not supports_runtime_tooltips then return end

  local caption = extraction_modes[get_extraction_mode(entity)].caption
  local id
  for _, field in ipairs(entity.get_tooltip_fields()) do
    if type(field.name) == "table" and field.name[1] == mode_tooltip_name then
      if field.order == mode_tooltip_order and type(field.value) == "table" and field.value[1] == caption[1] then return end
      id = field.id
      break
    end
  end
  entity.set_tooltip_field({id = id, name = {mode_tooltip_name}, value = caption, order = mode_tooltip_order})
end

local function get_circuit_bucket(unit_number)
  return storage.bpj_circuit_modes and storage.bpj_circuit_modes[unit_number % circuit_poll_interval]
end

local function get_circuit_fallback(entity)
  local bucket = get_circuit_bucket(entity.unit_number)
  return bucket and bucket[entity.unit_number]
end

local function is_valid_circuit_signal(signal)
  if not signal or not signal.name then return false end
  local prototype_type = signal.type == "virtual" and "virtual_signal" or (signal.type or "item"):gsub("-", "_")
  local prototype = prototypes[prototype_type][signal.name]
  return prototype and (signal.type ~= "virtual" or not prototype.special)
    and (not signal.quality or prototypes.quality[signal.quality])
end

local function copy_circuit_signals(signals)
  local copied = {}
  for picker_name, signal in pairs(signals or {}) do
    if is_valid_circuit_signal(signal) then
      copied[picker_name] = {name = signal.name, type = signal.type, quality = signal.quality}
    end
  end
  return next(copied) and copied or nil
end

local function register_pumpjack(entity)
  if entity and entity.valid and entity.unit_number and get_base_name(entity.name) then
    local unit_number = entity.unit_number
    get_known_pumpjacks()[unit_number] = entity
    storage.bpj_destruction_registrations = storage.bpj_destruction_registrations or {}
    storage.bpj_unit_registrations = storage.bpj_unit_registrations or {}
    if not storage.bpj_unit_registrations[unit_number] then
      local registration = script.register_on_object_destroyed(entity)
      storage.bpj_destruction_registrations[registration] = unit_number
      storage.bpj_unit_registrations[unit_number] = registration
    end
  end
end

local function unregister_pumpjack(unit_number)
  get_known_pumpjacks()[unit_number] = nil
  local registrations = storage.bpj_unit_registrations
  local registration = registrations and registrations[unit_number]
  if registration then
    registrations[unit_number] = nil
    storage.bpj_destruction_registrations[registration] = nil
  end
  if storage.bpj_queued_pumpjacks then
    storage.bpj_queued_pumpjacks[unit_number] = nil
  end
  if storage.bpj_applied_productivity then
    storage.bpj_applied_productivity[unit_number] = nil
  end
  if storage.bpj_extraction_modes then
    storage.bpj_extraction_modes[unit_number] = nil
  end
  local bucket = get_circuit_bucket(unit_number)
  if bucket then bucket[unit_number] = nil end
  if storage.bpj_circuit_signals then storage.bpj_circuit_signals[unit_number] = nil end
  if storage.bpj_circuit_wires then storage.bpj_circuit_wires[unit_number] = nil end
end

local function set_extraction_mode(entity, index)
  local previous_index = get_extraction_mode(entity)
  local mode = extraction_modes[index]
  if not mode or index == previous_index then return end

  register_pumpjack(entity)
  local previous = extraction_modes[previous_index]
  local effects = entity.local_effect or {}
  effects.speed = (effects.speed or 0) - previous.speed + mode.speed
  effects.consumption = (effects.consumption or 0) - previous.consumption + mode.consumption
  entity.local_effect = effects

  storage.bpj_extraction_modes = storage.bpj_extraction_modes or {}
  storage.bpj_extraction_modes[entity.unit_number] = index ~= standard_mode and index or nil
  update_mode_tooltip(entity)
end

local function set_circuit_fallback(entity, fallback)
  register_pumpjack(entity)
  local index = entity.unit_number % circuit_poll_interval
  storage.bpj_circuit_modes = storage.bpj_circuit_modes or {}
  local bucket = storage.bpj_circuit_modes[index] or {}
  bucket[entity.unit_number] = fallback
  storage.bpj_circuit_modes[index] = bucket
end

local function copy_circuit_wires(source, destination)
  local wires = storage.bpj_circuit_wires
  if not wires then return end
  local selection = wires[source.unit_number]
  wires[destination.unit_number] = selection and {
    [conservation_picker_name] = selection[conservation_picker_name],
    [overdrive_picker_name] = selection[overdrive_picker_name]
  } or nil
end

-- Red is 1, green is 2, and the default of 3 listens to both wires.
local function read_circuit_signal(entity, signal, mask)
  local wires = defines.wire_connector_id
  if mask == 0 then return 0 end
  if mask == 1 then return entity.get_signal(signal, wires.circuit_red) end
  if mask == 2 then return entity.get_signal(signal, wires.circuit_green) end
  return entity.get_signal(signal, wires.circuit_red, wires.circuit_green)
end

local function apply_circuit_mode(entity, fallback)
  local signals = storage.bpj_circuit_signals and storage.bpj_circuit_signals[entity.unit_number]
  local selection = storage.bpj_circuit_wires and storage.bpj_circuit_wires[entity.unit_number]
  local conserve_signal = signals and signals[conservation_picker_name] or default_circuit_signals[conservation_picker_name]
  local overdrive_signal = signals and signals[overdrive_picker_name] or default_circuit_signals[overdrive_picker_name]
  local mode = fallback
  if read_circuit_signal(entity, conserve_signal, selection and selection[conservation_picker_name]) > 0 then
    mode = 1
  elseif read_circuit_signal(entity, overdrive_signal, selection and selection[overdrive_picker_name]) > 0 then
    mode = 3
  end
  set_extraction_mode(entity, mode)
end

local function poll_circuit_modes(tick)
  -- Each enabled pumpjack is sampled twice a second, spread across ticks.
  local bucket = get_circuit_bucket(tick)
  if not bucket then return end
  local known = get_known_pumpjacks()
  for unit_number, fallback in pairs(bucket) do
    local entity = known[unit_number]
    if entity and entity.valid then
      apply_circuit_mode(entity, fallback)
    else
      bucket[unit_number] = nil
    end
  end
end

local function refresh_extraction_panel(frame, entity)
  local checkbox = frame[extraction_circuit_name]
  if not checkbox then return end
  local fallback = get_circuit_fallback(entity)
  local active = get_extraction_mode(entity)
  checkbox.state = fallback ~= nil
  frame[extraction_dropdown_name].selected_index = fallback or active
  local fallback_label = frame[extraction_fallback_name]
  if fallback_label then fallback_label.visible = fallback ~= nil end
  local label = frame[extraction_active_name]
  label.visible = fallback ~= nil
  label.caption = {"better-pumpjacks.extraction-mode-active", extraction_modes[active].caption}
  local signal_table = frame[extraction_signals_name]
  if not signal_table then return end
  signal_table.visible = fallback ~= nil
  if not fallback then return end
  local wires = defines.wire_connector_id
  local red_connected = entity.get_circuit_network(wires.circuit_red) ~= nil
  local green_connected = entity.get_circuit_network(wires.circuit_green) ~= nil
  local signals = storage.bpj_circuit_signals and storage.bpj_circuit_signals[entity.unit_number]
  local selection = storage.bpj_circuit_wires and storage.bpj_circuit_wires[entity.unit_number]
  for picker_name, default in pairs(default_circuit_signals) do
    local picker = signal_table[picker_name]
    local signal = signals and signals[picker_name] or default
    local shown = picker.elem_value
    if not shown or shown.name ~= signal.name or (shown.type or "item") ~= (signal.type or "item")
      or (shown.quality or "normal") ~= (signal.quality or "normal") then
      picker.elem_value = signal
    end
    local red = signal_table[picker_name .. "-red"]
    local green = signal_table[picker_name .. "-green"]
    if red and green then
      local mask = selection and selection[picker_name] or 3
      red.enabled = red_connected
      green.enabled = green_connected
      red.state = mask % 2 == 1
      green.state = mask >= 2
    end
  end
end

script.on_event(defines.events.on_object_destroyed, function(event)
  local registrations = storage.bpj_destruction_registrations
  local unit_number = registrations and registrations[event.registration_number]
  if unit_number then unregister_pumpjack(unit_number) end
end)

local function clear_queues()
  storage.bpj_update_queue = {}
  storage.bpj_update_queue_index = 1
  storage.bpj_queued_pumpjacks = {}
end

local function apply_pumpjack_productivity(entity)
  if not entity or not entity.valid or not get_base_name(entity.name) then return end
  register_pumpjack(entity)
  storage.bpj_applied_productivity = storage.bpj_applied_productivity or {}
  local unit_number = entity.unit_number
  local previous = storage.bpj_applied_productivity[unit_number] or 0
  local bonus = 0
  if entity.name ~= "pumpjack" or productivity_affects_vanilla then
    bonus = get_productivity_level(entity.force) * productivity_bonus_per_level
  end

  -- Only replace our own contribution; retain other local effect fields/bonuses.
  local effects = entity.local_effect or {}
  effects.productivity = (effects.productivity or 0) - previous + bonus
  entity.local_effect = effects
  storage.bpj_applied_productivity[unit_number] = bonus
end

local function get_update_queue()
  storage.bpj_update_queue = storage.bpj_update_queue or {}
  storage.bpj_update_queue_index = storage.bpj_update_queue_index or 1
  if not storage.bpj_queued_pumpjacks then
    storage.bpj_queued_pumpjacks = {}
    for i = storage.bpj_update_queue_index, #storage.bpj_update_queue do
      local entity = storage.bpj_update_queue[i]
      if entity and entity.valid and entity.unit_number then
        storage.bpj_queued_pumpjacks[entity.unit_number] = true
      end
    end
  end
  return storage.bpj_update_queue
end

local function queue_pumpjack_update(entity)
  if not entity or not entity.valid then return end
  register_pumpjack(entity)

  if not get_base_name(entity.name) then return end

  local queue = get_update_queue()
  local unit_number = entity.unit_number
  if not unit_number or storage.bpj_queued_pumpjacks[unit_number] then return end

  storage.bpj_queued_pumpjacks[unit_number] = true
  table.insert(queue, entity)
end

local function queue_all_pumpjacks(force)
  local names = pumpjack_names

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
  local productivity_modifier = 1 + (get_entity_bonus(entity, "productivity_bonus")
    or get_runtime_effect(entity, "productivity"))

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
        local base_name = get_base_name(entity.name)

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
  return force_name .. "\31" .. tostring(surface_index(surface_name)) .. "\31" .. fluid_name
end

local function check_output_threshold_warnings()
  migrate_surface_settings()
  if not are_output_warnings_enabled() then return end

  storage.bpj_output_warning_state = storage.bpj_output_warning_state or {}

  local configured_thresholds = storage.bpj_output_thresholds
  if not configured_thresholds then return end

  for force_name, surface_thresholds in pairs(configured_thresholds) do
    local force = game.forces[force_name]

    if force and has_output_thresholds(surface_thresholds) then
      local stats = collect_dashboard_stats(force)

      for index, fluid_thresholds in pairs(surface_thresholds) do
        local surface = game.surfaces[index]
        local surface_name = surface and surface.name
        local surface_stats = surface_name and stats[surface_name]

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

local changing_windows = {}

local function save_window_position(player, frame)
  storage.bpj_window_positions = storage.bpj_window_positions or {}
  local positions = storage.bpj_window_positions
  positions[player.index] = positions[player.index] or {}
  positions[player.index][frame.name] = {x = frame.location.x, y = frame.location.y}
end

local function position_window(player, frame)
  local positions = storage.bpj_window_positions and storage.bpj_window_positions[player.index]
  local location = positions and positions[frame.name]
  if location then
    frame.location = location
  else
    frame.auto_center = true
  end
end

local function focus_window(player, frame)
  -- Switching between our windows must not be treated as pressing Escape.
  changing_windows[player.index] = true
  player.opened = frame
  changing_windows[player.index] = nil
end

local function destroy_window(player, name)
  local frame = player.gui.screen[name]

  if frame then
    save_window_position(player, frame)
    changing_windows[player.index] = true
    if player.opened == frame then player.opened = nil end
    frame.destroy()
    changing_windows[player.index] = nil
  end
end

local function destroy_dashboard(player)
  if storage.bpj_dashboard_views then storage.bpj_dashboard_views[player.index] = nil end
  destroy_window(player, dashboard_frame_name)
end

local function get_hidden_surfaces(player)
  migrate_surface_settings()
  storage.bpj_hidden_surfaces = storage.bpj_hidden_surfaces or {}
  storage.bpj_hidden_surfaces[player.index] = storage.bpj_hidden_surfaces[player.index] or {}

  return storage.bpj_hidden_surfaces[player.index]
end

local function is_surface_visible(player, surface_name)
  return not get_hidden_surfaces(player)[surface_index(surface_name)]
end

local function get_surface_nicknames(player)
  migrate_surface_settings()
  storage.bpj_surface_nicknames = storage.bpj_surface_nicknames or {}
  storage.bpj_surface_nicknames[player.index] = storage.bpj_surface_nicknames[player.index] or {}

  return storage.bpj_surface_nicknames[player.index]
end

local function get_surface_display_name(player, surface_name)
  local nickname = get_surface_nicknames(player)[surface_index(surface_name)]

  if nickname and nickname ~= "" then
    return nickname
  end

  return surface_name
end

local function set_surface_nickname(player, surface_name, nickname)
  local nicknames = get_surface_nicknames(player)
  local index = surface_index(surface_name)
  if not index then return end

  if nickname and nickname ~= "" then
    nicknames[index] = nickname
  else
    nicknames[index] = nil
  end
end

local function get_surface_order(player)
  migrate_surface_settings()
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

  for _, index in pairs(get_surface_order(player)) do
    local surface = game.surfaces[index]
    local surface_name = surface and surface.name
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

  local indices = {}
  for _, name in ipairs(names) do table.insert(indices, surface_index(name)) end
  storage.bpj_surface_order[player.index] = indices
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
  local indices = {}
  for _, name in ipairs(order) do table.insert(indices, surface_index(name)) end
  storage.bpj_surface_order[player.index] = indices
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
  destroy_window(player, surface_manager_frame_name)
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
  position_window(player, frame)
  frame.style.width = 650

  local header = frame.add({type = "flow", direction = "horizontal"})
  header.style.width = 626
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
  note.style.width = 626

  local surfaces_frame = frame.add({
    type = "frame",
    direction = "vertical",
    style = "inside_shallow_frame_with_padding"
  })
  surfaces_frame.style.horizontally_stretchable = true
  surfaces_frame.style.width = 626

  local column_headers = surfaces_frame.add({type = "flow", direction = "horizontal"})
  column_headers.style.horizontally_stretchable = true
  local surfaces_header = column_headers.add({
    type = "label",
    caption = {"better-pumpjacks.dashboard-surface"}
  })
  surfaces_header.style.width = 160
  surfaces_header.style.font = "default-bold"
  surfaces_header.style.font_color = {r = 1, g = 0.86, b = 0.45}
  local nickname_header = column_headers.add({
    type = "label",
    caption = {"better-pumpjacks.surface-manager-nickname"}
  })
  nickname_header.style.font = "default-bold"
  nickname_header.style.font_color = {r = 1, g = 0.86, b = 0.45}

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
      state = not hidden_surfaces[surface_index(surface_name)]
    })
    checkbox.style.width = 160
    checkbox.tooltip = surface_name

    local nickname = get_surface_nicknames(player)[surface_index(surface_name)]
    nickname_input_index = nickname_input_index + 1
    local nickname_input_name = "bpj-surface-nickname-" .. nickname_input_index
    local nickname_input = row.add({
      type = "textfield",
      name = nickname_input_name,
      text = nickname or "",
      tooltip = {"better-pumpjacks.surface-manager-nickname-tooltip"}
    })
    nickname_input.style.minimal_width = 190
    nickname_input.style.horizontally_stretchable = true
    storage.bpj_surface_nickname_inputs[player.index][nickname_input_name] = surface_name

    local up_name = "bpj-surface-order-up-" .. nickname_input_index
    local down_name = "bpj-surface-order-down-" .. nickname_input_index

    local up_button = row.add({
      type = "button",
      name = up_name,
      caption = {"better-pumpjacks.surface-manager-up"},
      tooltip = {"better-pumpjacks.surface-manager-up-tooltip"}
    })
    up_button.style.width = 64
    local down_button = row.add({
      type = "button",
      name = down_name,
      caption = {"better-pumpjacks.surface-manager-down"},
      tooltip = {"better-pumpjacks.surface-manager-down-tooltip"}
    })
    down_button.style.width = 64

    storage.bpj_surface_order_buttons[player.index][up_name] = {
      surface_name = surface_name,
      delta = -1
    }
    storage.bpj_surface_order_buttons[player.index][down_name] = {
      surface_name = surface_name,
      delta = 1
    }
  end
  focus_window(player, frame)
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
  migrate_surface_settings()
  storage.bpj_dashboard_surface = storage.bpj_dashboard_surface or {}
  local surface_name = storage.bpj_dashboard_surface[player.index]

  if surface_name and game.surfaces[surface_name] and is_surface_visible(player, surface_name) then
    return game.surfaces[surface_name].name
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

local function add_dashboard_fluid_row(player, view, fluid_name, fluid_total)
  local force = player.force
  local selected_surface_name = view.selected_surface_name
  local threshold_enabled = selected_surface_name ~= nil
  local products_frame = view.products_frame
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
      view.next_input = view.next_input + 1
      local threshold_input_name = "bpj-dashboard-output-threshold-" .. view.next_input
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
        element = threshold_input,
        force_index = force.index,
        surface_index = surface_index(selected_surface_name),
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

    local low_label = row.add({type = "label", caption = "LOW", tooltip = warning_tooltip})
    low_label.visible = not not is_low_output
    low_label.style.font_color = {r = 1, g = 0.75, b = 0.25}
    if is_low_output then tiers_label.style.font_color = {r = 1, g = 0.75, b = 0.25} end
    view.fluids[fluid_name] = {row = row, product = product_label, amount = amount_label,
      tiers = tiers_label, low = low_label}
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
  local view = {force_index = force.index, selected_surface_name = selected_surface_name,
    fluids = {}, surfaces = {}, next_input = 0}
  storage.bpj_dashboard_views = storage.bpj_dashboard_views or {}
  storage.bpj_dashboard_views[player.index] = view

  local frame = player.gui.screen.add({
    type = "frame",
    name = dashboard_frame_name,
    direction = "vertical"
  })

  view.frame = frame
  position_window(player, frame)
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
    return value_label
  end

  view.productivity = add_summary_item(
    {"better-pumpjacks.dashboard-productivity-level"},
    productivity_text,
    "[technology=bpj-pumpjack-output]",
    nil,
    230
  )
  view.output = add_summary_item(
    {"better-pumpjacks.dashboard-total-resource-second"},
    format_number(totals.resource_per_second),
    "[img=bpj-fluids-icon]",
    {"better-pumpjacks.dashboard-estimate-note"},
    150
  )
  local summary_spacer = summary_frame.add({type = "empty-widget"})
  summary_spacer.style.width = 118
  view.count = add_summary_item(
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
  view.products_frame = products_frame

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

  -- Keep saved thresholds editable even after their last producer is removed.
  if threshold_enabled then
    for fluid_name in pairs(get_output_thresholds(force.name, selected_surface_name)) do
      ensure_fluid_total(totals.resource_per_second_by_fluid, fluid_name)
    end
  end

  for fluid_name in pairs(totals.resource_per_second_by_fluid) do
    table.insert(fluid_names, fluid_name)
  end

  table.sort(fluid_names)

  for _, fluid_name in ipairs(fluid_names) do
    add_dashboard_fluid_row(player, view, fluid_name, totals.resource_per_second_by_fluid[fluid_name])
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

      view.surfaces[surface_name] = {
        add_stat_label(table_element, get_surface_display_name(player, surface_name), 150),
        add_stat_label(table_element, productivity_text, 100, "right"),
        add_stat_label(table_element, format_number(surface_stats.vanilla), 70, "right"),
        add_stat_label(table_element, format_number(surface_stats.mk2), 60, "right"),
        add_stat_label(table_element, format_number(surface_stats.mk3), 60, "right"),
        add_stat_label(table_element, format_number(surface_stats.total), 60, "right"),
        add_stat_label(table_element, format_percent(average_yield / 100), 80, "right"),
        add_stat_label(table_element, format_number(surface_stats.resource_per_second), 90, "right")
      }    end
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
  view.dropdown = surface_dropdown
  view.surface_table = table_element
  view.surface_choices = surface_names

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
  focus_window(player, player.gui.screen[surface_manager_frame_name] or frame)
end

local function refresh_open_dashboards()
  local views = storage.bpj_dashboard_views
  if not views then return end
  local force_stats = {}
  for _, player in pairs(game.connected_players) do
    local view = views[player.index]
    if view and view.frame.valid and player.gui.screen[dashboard_frame_name] == view.frame
      and player.force.index == view.force_index then
      local selected = view.selected_surface_name
      -- Surface deletion needs the normal close/reopen path, not stale field writes.
      if not selected or game.surfaces[selected] then
        local force = player.force
        if not force_stats[force.index] then force_stats[force.index] = collect_dashboard_stats(force) end
        local stats = force_stats[force.index]
        local surfaces = get_visible_surface_names(player, stats)
        local totals = {pumpjacks = 0, vanilla = 0, mk2 = 0, mk3 = 0,
          resource_per_second = 0, resource_per_second_by_fluid = {}}
        if selected and stats[selected] then
          add_surface_stats_to_totals(stats[selected], totals)
        else
          for _, name in ipairs(surfaces) do add_surface_stats_to_totals(stats[name], totals) end
        end
        if selected then
          for fluid in pairs(get_output_thresholds(force.name, selected)) do
            ensure_fluid_total(totals.resource_per_second_by_fluid, fluid)
          end
        end
        local level = get_productivity_level(force)
        local productivity = "Level " .. format_number(level) .. " (+"
          .. format_percent(level * productivity_bonus_per_level) .. ")"
        view.productivity.caption = productivity
        view.output.caption = format_number(totals.resource_per_second)
        view.count.caption = format_number(totals.pumpjacks)
        view.count.tooltip = {"better-pumpjacks.dashboard-pumpjack-tooltip",
          format_number(totals.vanilla), format_number(totals.mk2), format_number(totals.mk3)}

        local new_fluids = {}
        for fluid in pairs(totals.resource_per_second_by_fluid) do
          if not view.fluids[fluid] then table.insert(new_fluids, fluid) end
        end
        table.sort(new_fluids)
        for _, fluid in ipairs(new_fluids) do
          add_dashboard_fluid_row(player, view, fluid, totals.resource_per_second_by_fluid[fluid])
        end
        -- Keep existing rows/inputs alive even at zero output. Never rewrite text.
        for fluid, row in pairs(view.fluids) do
          local total = ensure_fluid_total(totals.resource_per_second_by_fluid, fluid)
          local threshold = selected and get_output_threshold(force.name, selected, fluid)
          local low = threshold and total.amount < threshold
          local tooltip = low and {"better-pumpjacks.dashboard-low-output-warning",
            format_number(total.amount), format_number(threshold)} or nil
          local tiers = {}
          for _, tier in ipairs({{"vanilla", "pumpjack"}, {"mk2", "pumpjack-mk2"}, {"mk3", "pumpjack-mk3"}}) do
            if total[tier[1]] > 0 then
              table.insert(tiers, "[item=" .. tier[2] .. "] x " .. format_number(total[tier[1]]))
            end
          end
          row.amount.caption = format_number(total.amount) .. "/s"
          row.tiers.caption = table.concat(tiers, "  ")
          row.low.visible = not not low
          row.low.tooltip = tooltip
          for _, label in ipairs({row.product, row.amount, row.tiers}) do
            label.tooltip = tooltip
            label.style.font_color = low and {r = 1, g = 0.75, b = 0.25} or {r = 1, g = 1, b = 1}
          end
        end

        local visible = {}
        local items = {{"better-pumpjacks.dashboard-all-surfaces"}}
        local selected_index = 1
        local widths = {150, 100, 70, 60, 60, 60, 80, 90}
        for index, name in ipairs(surfaces) do
          table.insert(items, get_surface_display_name(player, name))
          if name == selected then selected_index = index + 1 end
          if not selected or name == selected then
            visible[name] = true
            local total = stats[name]
            local values = {get_surface_display_name(player, name), productivity,
              format_number(total.vanilla), format_number(total.mk2), format_number(total.mk3),
              format_number(total.total), format_percent(total.total > 0 and total.yield_total / total.total / 100 or 0),
              format_number(total.resource_per_second)}
            local labels = view.surfaces[name]
            if not labels then
              labels = {}
              for column = 1, 8 do
                labels[column] = add_stat_label(view.surface_table, "", widths[column], column > 1 and "right" or nil)
              end
              view.surfaces[name] = labels
            end
            for column = 1, 8 do
              labels[column].caption = values[column]
              labels[column].visible = true
            end
          end
        end
        for name, labels in pairs(view.surfaces) do
          if not visible[name] then for _, label in ipairs(labels) do label.visible = false end end
        end
        view.surface_choices = surfaces
        local old_items = view.dropdown.items
        local changed = #old_items ~= #items
        for index = 2, #items do
          if old_items[index] ~= items[index] then changed = true; break end
        end
        if changed then view.dropdown.items = items end
        if view.dropdown.selected_index ~= selected_index then
          view.dropdown.selected_index = selected_index
        end
      end
    end
  end
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

      if entity.force == force then
        count = count + 1
        queue_pumpjack_update(entity)
      end
    end
  end

  storage.bpj_known_pumpjacks = compacted
  return count
end

local function rebuild_known_pumpjacks()
  clear_queues()
  local old_applied = storage.bpj_applied_productivity or {}
  storage.bpj_applied_productivity = {}
  storage.bpj_known_pumpjacks = {}
  storage.bpj_destruction_registrations = {}
  storage.bpj_unit_registrations = {}

  for _, force in pairs(game.forces) do
    queue_all_pumpjacks(force)
  end
  for unit_number in pairs(get_known_pumpjacks()) do
    storage.bpj_applied_productivity[unit_number] = old_applied[unit_number]
  end
  for unit_number in pairs(storage.bpj_extraction_modes or {}) do
    if not storage.bpj_known_pumpjacks[unit_number] then
      storage.bpj_extraction_modes[unit_number] = nil
    end
  end
  for unit_number, signals in pairs(storage.bpj_circuit_signals or {}) do
    for picker_name, signal in pairs(signals) do
      if not is_valid_circuit_signal(signal) then signals[picker_name] = nil end
    end
    if not storage.bpj_known_pumpjacks[unit_number] or not next(signals) then
      storage.bpj_circuit_signals[unit_number] = nil
    end
  end
  for unit_number in pairs(storage.bpj_circuit_wires or {}) do
    if not storage.bpj_known_pumpjacks[unit_number] then storage.bpj_circuit_wires[unit_number] = nil end
  end
  storage.bpj_tracking_version = nil
  storage.bpj_direct_productivity_version = 1
end

local function process_update_queue()
  migrate_surface_settings()
  if storage.bpj_direct_productivity_version ~= 1 then rebuild_known_pumpjacks() end
  local queue = get_update_queue()
  local queue_index = storage.bpj_update_queue_index

  for _ = 1, updates_per_tick do
    local entity = queue[queue_index]

    if not entity then
      if #queue > 0 then clear_queues() end
      return
    end

    if entity.valid and entity.unit_number then
      storage.bpj_queued_pumpjacks[entity.unit_number] = nil
    end
    -- Read current research when processed, including reversals and force changes.
    apply_pumpjack_productivity(entity)
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

script.on_event({defines.events.on_research_finished, defines.events.on_research_reversed}, function(event)
  if is_pumpjack_productivity_research(event.research.name) then
    if queue_known_pumpjacks(event.research.force) == 0 then
      queue_all_pumpjacks(event.research.force)
    end

    print_productivity_status(event.research.force)
  end
end)

script.on_event(defines.events.on_force_reset, function(event)
  queue_all_pumpjacks(event.force)
end)

local function refresh_open_windows(player)
  if player.gui.screen[dashboard_frame_name] then show_dashboard(player) end
  if player.gui.screen[surface_manager_frame_name] then show_surface_manager(player) end
end

script.on_event(defines.events.on_forces_merged, function(event)
  migrate_surface_settings()
  local thresholds = storage.bpj_output_thresholds or {}
  local source = thresholds[event.source_name]
  if source then
    local destination = thresholds[event.destination.name] or {}
    thresholds[event.destination.name] = destination
    for index, fluids in pairs(source) do
      if game.surfaces[index] then
        destination[index] = destination[index] or {}
        for fluid, value in pairs(fluids) do
          if destination[index][fluid] == nil then destination[index][fluid] = value end
        end
      end
    end
    thresholds[event.source_name] = nil
  end
  local prefix = event.source_name .. "\31"
  for key in pairs(storage.bpj_output_warning_state or {}) do
    if key:sub(1, #prefix) == prefix then storage.bpj_output_warning_state[key] = nil end
  end
  queue_all_pumpjacks(event.destination)
  for _, player in pairs(event.destination.players) do
    refresh_open_windows(player)
  end
end)

script.on_event(defines.events.on_player_changed_force, function(event)
  local player = game.get_player(event.player_index)
  if player and player.gui.screen[dashboard_frame_name] then show_dashboard(player) end
end)

script.on_event(defines.events.on_surface_deleted, function(event)
  migrate_surface_settings()
  local index = event.surface_index
  for _, key in ipairs({"bpj_output_thresholds", "bpj_hidden_surfaces", "bpj_surface_nicknames"}) do
    for _, entries in pairs(storage[key] or {}) do entries[index] = nil end
  end
  for _, order in pairs(storage.bpj_surface_order or {}) do
    for i = #order, 1, -1 do
      if order[i] == index then table.remove(order, i) end
    end
  end
  for player_index, selected in pairs(storage.bpj_dashboard_surface or {}) do
    if selected == index then storage.bpj_dashboard_surface[player_index] = nil end
  end
  for key in pairs(storage.bpj_output_warning_state or {}) do
    local stored_index = key:match("^[^\31]*\31(%d+)\31")
    if tonumber(stored_index) == index then storage.bpj_output_warning_state[key] = nil end
  end
  for _, player in pairs(game.players) do refresh_open_windows(player) end
end)

commands.add_command("bpj-refresh", "Refresh Better Pumpjacks research bonuses and print current productivity status.", function(command)
  local player = command.player_index and game.get_player(command.player_index)
  local force = player and player.force or game.forces.player

  queue_all_pumpjacks(force)
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
  poll_circuit_modes(game.tick)
  if game.tick % circuit_poll_interval == 0 then
    for _, player in pairs(game.connected_players) do
      local relative = player.gui.relative
      local frame = relative and relative[extraction_frame_name]
      if frame and can_set_extraction_mode(player, player.opened) then
        refresh_extraction_panel(frame, player.opened)
      end
    end
  end
  if game.tick % 300 == 0 then refresh_open_dashboards() end
  -- Factorio advises against opening another GUI inside on_gui_closed.
  local pending = storage.bpj_restore_dashboard
  storage.bpj_restore_dashboard = nil
  for player_index in pairs(pending or {}) do
    local player = game.get_player(player_index)
    if player and player.gui.screen[dashboard_frame_name]
      and not player.gui.screen[surface_manager_frame_name] and not player.opened then
      show_dashboard(player)
    end
  end
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
    apply_pumpjack_productivity(entity)
  end
end

script.on_event(defines.events.on_built_entity, on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)
script.on_event(defines.events.script_raised_built, on_built)
script.on_event(defines.events.script_raised_revive, on_built)

script.on_event(defines.events.on_entity_cloned, function(event)
  local destination = event.destination
  if not destination or not destination.valid or not get_base_name(destination.name) then return end
  -- Factorio creates the clone without the source's local effects.
  local source = event.source
  if source and source.valid then
    local fallback = get_circuit_fallback(source)
    set_extraction_mode(destination, fallback or get_extraction_mode(source))
    if fallback then set_circuit_fallback(destination, fallback) end
    local signals = storage.bpj_circuit_signals and storage.bpj_circuit_signals[source.unit_number]
    if signals then storage.bpj_circuit_signals[destination.unit_number] = copy_circuit_signals(signals) end
    copy_circuit_wires(source, destination)
  end
  queue_pumpjack_update(destination)
end)

script.on_event(defines.events.on_surface_renamed, function()
  migrate_surface_settings()
  -- Refresh open controls so they use the surface's current name.
  for _, player in pairs(game.players) do
    if player.gui.screen[dashboard_frame_name] then show_dashboard(player) end
    if player.gui.screen[surface_manager_frame_name] then show_surface_manager(player) end
  end
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)

  if player then
    remove_dashboard_button(player)
  end
end)

script.on_event(defines.events.on_gui_location_changed, function(event)
  local frame = event.element
  if not frame or not frame.valid then return end
  if frame.name ~= dashboard_frame_name and frame.name ~= surface_manager_frame_name then return end
  local player = game.get_player(event.player_index)
  if player then save_window_position(player, frame) end
end)

local function read_extraction_settings(entity)
  local fallback = get_circuit_fallback(entity)
  local signals = storage.bpj_circuit_signals and storage.bpj_circuit_signals[entity.unit_number]
  return {fallback = fallback, mode = fallback or get_extraction_mode(entity), signals = signals}
end

local function paste_extraction_settings(entity, settings)
  storage.bpj_circuit_signals = storage.bpj_circuit_signals or {}
  storage.bpj_circuit_signals[entity.unit_number] = copy_circuit_signals(settings.signals)
  set_circuit_fallback(entity, settings.fallback)
  if settings.fallback then
    apply_circuit_mode(entity, settings.fallback)
  else
    set_extraction_mode(entity, settings.mode)
  end
end

script.on_event(defines.events.on_entity_settings_pasted, function(event)
  local player = game.get_player(event.player_index)
  if not player or not can_set_extraction_mode(player, event.source)
    or not can_set_extraction_mode(player, event.destination) then return end
  copy_circuit_wires(event.source, event.destination)
  paste_extraction_settings(event.destination, read_extraction_settings(event.source))
end)

script.on_event(defines.events.on_selected_entity_changed, function(event)
  local player = game.get_player(event.player_index)
  if player then update_mode_tooltip(player.selected) end
end)

script.on_event(defines.events.on_gui_opened, function(event)
  if not event.entity then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local relative = player.gui.relative
  local old_frame = relative[extraction_frame_name]
  if old_frame then old_frame.destroy() end

  local entity = event.entity
  if not can_set_extraction_mode(player, entity) then return end
  local frame = relative.add({
    type = "frame",
    name = extraction_frame_name,
    caption = {"better-pumpjacks.extraction-mode-title"},
    direction = "vertical",
    anchor = {gui = defines.relative_gui_type.mining_drill_gui, position = defines.relative_gui_position.right}
  })
  local active_label = frame.add({type = "label", name = extraction_active_name})
  active_label.style.font = "default-bold"
  active_label.style.font_color = {r = 1, g = 0.86, b = 0.45}
  frame.add({
    type = "label",
    name = extraction_fallback_name,
    caption = {"better-pumpjacks.extraction-mode-fallback"}
  })
  frame.add({
    type = "drop-down",
    name = extraction_dropdown_name,
    items = {extraction_modes[1].caption, extraction_modes[2].caption, extraction_modes[3].caption},
    selected_index = get_circuit_fallback(entity) or get_extraction_mode(entity),
    tooltip = {"better-pumpjacks.extraction-mode-tooltip"}
  })
  frame.add({
    type = "checkbox",
    name = extraction_circuit_name,
    state = false,
    caption = {"better-pumpjacks.extraction-mode-circuit"},
    tooltip = {"better-pumpjacks.extraction-mode-circuit-tooltip"}
  })
  local signal_table = frame.add({type = "table", name = extraction_signals_name, column_count = 4})
  for _, picker in ipairs({
    {name = conservation_picker_name, caption = extraction_modes[1].caption},
    {name = overdrive_picker_name, caption = extraction_modes[3].caption}
  }) do
    signal_table.add({type = "label", caption = picker.caption})
    signal_table.add({
      type = "choose-elem-button",
      name = picker.name,
      elem_type = "signal",
      tooltip = {"better-pumpjacks.extraction-mode-signal-tooltip", picker.caption}
    })
    for _, wire in ipairs({"red", "green"}) do
      signal_table.add({
        type = "checkbox",
        name = picker.name .. "-" .. wire,
        state = true,
        caption = {"better-pumpjacks.extraction-wire-" .. wire}
      })
    end
  end
  refresh_extraction_panel(frame, entity)
end)

script.on_event(defines.events.on_gui_closed, function(event)
  if changing_windows[event.player_index] then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  if event.entity then
    local extraction_frame = player.gui.relative[extraction_frame_name]
    if extraction_frame then extraction_frame.destroy() end
  end
  local frame = event.element
  if not frame or not frame.valid then return end
  if frame.name == dashboard_frame_name then
    destroy_dashboard(player)
  elseif frame.name == surface_manager_frame_name then
    destroy_surface_manager(player)
    storage.bpj_restore_dashboard = storage.bpj_restore_dashboard or {}
    storage.bpj_restore_dashboard[player.index] = true
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

  local picker_name = element.name:match("^(.+)%-%a+$")
  if default_circuit_signals[picker_name] then
    local player = game.get_player(event.player_index)
    local entity = player and player.opened
    if not player or not can_set_extraction_mode(player, entity) then return end
    local frame = player.gui.relative[extraction_frame_name]
    local signal_table = frame and frame[extraction_signals_name]
    if not signal_table or signal_table[element.name] ~= element then return end
    local fallback = get_circuit_fallback(entity)
    if not fallback then return end

    local red = signal_table[picker_name .. "-red"]
    local green = signal_table[picker_name .. "-green"]
    local wires = defines.wire_connector_id
    local connector = element == red and wires.circuit_red or wires.circuit_green
    if not entity.get_circuit_network(connector) then
      refresh_extraction_panel(frame, entity)
      return
    end
    local mask = (red.state and 1 or 0) + (green.state and 2 or 0)
    local unit_number = entity.unit_number
    storage.bpj_circuit_wires = storage.bpj_circuit_wires or {}
    local selection = storage.bpj_circuit_wires[unit_number] or {}
    selection[picker_name] = mask ~= 3 and mask or nil
    storage.bpj_circuit_wires[unit_number] = next(selection) and selection or nil
    apply_circuit_mode(entity, fallback)
    refresh_extraction_panel(frame, entity)
    return
  end

  if element.name == extraction_circuit_name then
    local player = game.get_player(event.player_index)
    local entity = player and player.opened
    if not player or not can_set_extraction_mode(player, entity) then return end
    local frame = player.gui.relative[extraction_frame_name]
    if not frame or frame[extraction_circuit_name] ~= element then return end
    local fallback = get_circuit_fallback(entity) or get_extraction_mode(entity)
    if element.state then
      set_circuit_fallback(entity, fallback)
      apply_circuit_mode(entity, fallback)
    else
      set_circuit_fallback(entity, nil)
      set_extraction_mode(entity, fallback)
    end
    refresh_extraction_panel(frame, entity)
    return
  end

  local surface_name = string.match(element.name, "^bpj%-surface%-visible%-(.+)$")
  if not surface_name then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  local index = surface_index(surface_name)
  if not index then return end
  local hidden_surfaces = get_hidden_surfaces(player)

  if element.state then
    hidden_surfaces[index] = nil
  else
    hidden_surfaces[index] = true

    if storage.bpj_dashboard_surface and storage.bpj_dashboard_surface[player.index] == index then
      storage.bpj_dashboard_surface[player.index] = nil
    end
  end

end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
  local element = event.element

  if not element or not element.valid then return end
  if element.name ~= extraction_dropdown_name and element.name ~= "bpj-dashboard-surface-dropdown" then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  if element.name == extraction_dropdown_name then
    local entity = player.opened
    if not can_set_extraction_mode(player, entity) then return end
    local frame = player.gui.relative[extraction_frame_name]
    if not frame or frame[extraction_dropdown_name] ~= element then return end
    if not extraction_modes[element.selected_index] then return end
    if get_circuit_fallback(entity) then
      set_circuit_fallback(entity, element.selected_index)
      apply_circuit_mode(entity, element.selected_index)
    else
      set_extraction_mode(entity, element.selected_index)
    end
    refresh_extraction_panel(frame, entity)
    return
  end

  storage.bpj_dashboard_surface = storage.bpj_dashboard_surface or {}

  if element.selected_index <= 1 then
    storage.bpj_dashboard_surface[player.index] = nil
  else
    local view = storage.bpj_dashboard_views and storage.bpj_dashboard_views[player.index]
    local surface_names = view and view.surface_choices or {}
    storage.bpj_dashboard_surface[player.index] = surface_index(surface_names[element.selected_index - 1])
  end

  show_dashboard(player)
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
  local picker = event.element
  if not picker or not picker.valid or not default_circuit_signals[picker.name] then return end
  local player = game.get_player(event.player_index)
  local entity = player and player.opened
  if not player or not can_set_extraction_mode(player, entity) then return end
  local frame = player.gui.relative[extraction_frame_name]
  local signal_table = frame and frame[extraction_signals_name]
  if not signal_table or signal_table[picker.name] ~= picker then return end
  local fallback = get_circuit_fallback(entity)
  if not fallback then return end

  local signal = picker.elem_value
  if signal and not is_valid_circuit_signal(signal) then
    player.print({"better-pumpjacks.extraction-mode-invalid-signal"})
    refresh_extraction_panel(frame, entity)
    return
  end

  storage.bpj_circuit_signals = storage.bpj_circuit_signals or {}
  local unit_number = entity.unit_number
  local signals = storage.bpj_circuit_signals[unit_number] or {}
  signals[picker.name] = signal
  storage.bpj_circuit_signals[unit_number] = next(signals) and signals or nil
  apply_circuit_mode(entity, fallback)
  refresh_extraction_panel(frame, entity)
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
  if threshold_target.force_name ~= player.force.name then return end
  if threshold_target.force_index and threshold_target.force_index ~= player.force.index then return end
  if threshold_target.element and threshold_target.element ~= element then return end
  local index = surface_index(threshold_target.surface_name)
  if not index or (threshold_target.surface_index and threshold_target.surface_index ~= index) then return end

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
    return get_base_name(entity_name)
  end,

  is_better_pumpjack = function(entity_name)
    return get_base_name(entity_name) ~= nil
  end,

  get_target_name = function(force_name, base_name)
    local force = game.forces[force_name]

    if not force or not get_base_name(base_name) then
      return nil
    end

    return get_base_name(base_name)
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
