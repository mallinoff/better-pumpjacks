-- ==================== HELPERS ====================

local function prototype_exists(prototype_type, name)
  return data.raw[prototype_type] and data.raw[prototype_type][name]
end

local function add_existing_science_packs(list)
  local packs = {}

  for _, pack in pairs(list) do
    if prototype_exists("tool", pack) then
      table.insert(packs, {pack, 1})
    end
  end

  return packs
end

local function add_existing_prerequisites(list)
  local prereqs = {}

  for _, tech in pairs(list) do
    if prototype_exists("technology", tech) then
      table.insert(prereqs, tech)
    end
  end

  return prereqs
end

local function is_space_exploration()
  return mods["space-exploration"] ~= nil
end

local function add_first_existing_prerequisite(prereqs, possible_names)
  for _, tech in pairs(possible_names) do
    if prototype_exists("technology", tech) then
      table.insert(prereqs, tech)
      return
    end
  end
end

local function is_space_age()
  return prototype_exists("tool", "metallurgic-science-pack")
    or prototype_exists("tool", "electromagnetic-science-pack")
end

local function tint_recursive(obj, tint)
  if not obj then return end

  if obj.filename or obj.filenames then
    obj.tint = tint
  end

  for _, value in pairs(obj) do
    if type(value) == "table" then
      tint_recursive(value, tint)
    end
  end
end

local function format_number(value)
  local rounded = math.floor(value * 100 + 0.5) / 100
  local text = string.format("%.2f", rounded)
  local formatted = text:gsub("%.?0+$", "")
  return formatted
end

local function format_percent(value)
  return format_number(value * 100) .. "%"
end

local function pumpjack_description(tier, modules, speed, productivity, pollution, energy_usage)
  return {
    "",
    tier,
    " pumpjack with ",
    format_number(modules),
    " module slots, ",
    format_number(speed),
    "x mining speed, +",
    format_percent(productivity),
    " productivity, ",
    format_number(pollution),
    " pollution per minute, and ",
    format_number(energy_usage),
    "kW energy usage."
  }
end

local function pumpjack_technology_description(name, modules, speed, productivity, pollution, energy_usage)
  return {
    "",
    "Unlocks ",
    name,
    ": ",
    format_number(modules),
    " module slots, ",
    format_number(speed),
    "x mining speed, +",
    format_percent(productivity),
    " productivity, ",
    format_number(pollution),
    " pollution per minute, and ",
    format_number(energy_usage),
    "kW energy usage."
  }
end

local max_productivity_level = settings.startup["bpj-max-productivity-level"].value
local productivity_bonus_per_level = settings.startup["bpj-productivity-research-bonus"].value
local productivity_affects_vanilla = settings.startup["bpj-productivity-affects-vanilla"].value
local productivity_research_base_cost = settings.startup["bpj-productivity-research-base-cost"].value
local productivity_research_level_cost = settings.startup["bpj-productivity-research-level-cost"].value
local productivity_research_count_formula = productivity_research_base_cost
  .. " + (L * "
  .. productivity_research_level_cost
  .. ")"

data:extend({
  {
    type = "sprite",
    name = "bpj-fluids-icon",
    filename = "__better-pumpjacks__/graphics/icons/fluids.png",
    size = 128,
    flags = {"gui-icon"}
  },
  {
    type = "custom-input",
    name = "bpj-toggle-dashboard",
    key_sequence = "",
    consuming = "none"
  },
  {
    type = "shortcut",
    name = "bpj-toggle-dashboard",
    action = "lua",
    associated_control_input = "bpj-toggle-dashboard",
    localised_name = {"shortcut-name.bpj-toggle-dashboard"},
    icon = "__better-pumpjacks__/graphics/icons/fluids.png",
    icon_size = 128,
    small_icon = "__better-pumpjacks__/graphics/icons/fluids.png",
    small_icon_size = 128,
    order = "b[pumpjacks]-a[dashboard]"
  }
})

-- ==================== PUMPJACK MK2 ====================

local mk2 = table.deepcopy(data.raw["mining-drill"]["pumpjack"])
local mk2_corpse = table.deepcopy(data.raw["corpse"]["pumpjack-remnants"])
local mk2_modules = settings.startup["bpj-mk2-modules"].value
local mk2_speed = settings.startup["bpj-mk2-speed"].value
local mk2_productivity = settings.startup["bpj-mk2-productivity"].value
local mk2_pollution = settings.startup["bpj-mk2-pollution"].value
local mk2_energy_usage = settings.startup["bpj-mk2-energy-usage"].value
local mk2_description = pumpjack_description(
  "Better",
  mk2_modules,
  mk2_speed,
  mk2_productivity,
  mk2_pollution,
  mk2_energy_usage
)
local mk2_technology_description = pumpjack_technology_description(
  "Pumpjack MK2",
  mk2_modules,
  mk2_speed,
  mk2_productivity,
  mk2_pollution,
  mk2_energy_usage
)

mk2.name = "pumpjack-mk2"
mk2.icon = "__better-pumpjacks__/graphics/icons/pumpjack-mk2.png"
mk2.icon_size = 256
mk2.localised_description = mk2_description
mk2.minable.result = "pumpjack-mk2"
mk2.energy_usage = mk2_energy_usage .. "kW"
mk2.fast_replaceable_group = "pumpjack"
mk2.next_upgrade = "pumpjack-mk3"
mk2.module_slots = mk2_modules
mk2.mining_speed = mk2_speed
mk2.base_productivity = mk2_productivity
mk2.energy_source.emissions_per_minute = {
  pollution = mk2_pollution
}

mk2_corpse.name = "pumpjack-mk2-remnants"

tint_recursive(mk2_corpse.animation, {
  r = 0.2,
  g = 0.3,
  b = 1.0,
  a = 1
})

data:extend({mk2_corpse})

mk2.corpse = "pumpjack-mk2-remnants"

tint_recursive(mk2.graphics_set, {
  r = 0.2,
  g = 0.3,
  b = 1.0,
  a = 1
})


-- ==================== PUMPJACK MK3 ====================

local mk3 = table.deepcopy(data.raw["mining-drill"]["pumpjack"])
local mk3_corpse = table.deepcopy(data.raw["corpse"]["pumpjack-remnants"])
local mk3_modules = settings.startup["bpj-mk3-modules"].value
local mk3_speed = settings.startup["bpj-mk3-speed"].value
local mk3_productivity = settings.startup["bpj-mk3-productivity"].value
local mk3_pollution = settings.startup["bpj-mk3-pollution"].value
local mk3_energy_usage = settings.startup["bpj-mk3-energy-usage"].value
local mk3_description = pumpjack_description(
  "Advanced",
  mk3_modules,
  mk3_speed,
  mk3_productivity,
  mk3_pollution,
  mk3_energy_usage
)
local mk3_technology_description = pumpjack_technology_description(
  "Pumpjack MK3",
  mk3_modules,
  mk3_speed,
  mk3_productivity,
  mk3_pollution,
  mk3_energy_usage
)

mk3.name = "pumpjack-mk3"
mk3.icon = "__better-pumpjacks__/graphics/icons/pumpjack-mk3.png"
mk3.icon_size = 256
mk3.localised_description = mk3_description
mk3.minable.result = "pumpjack-mk3"
mk3.energy_usage = mk3_energy_usage .. "kW"
mk3.fast_replaceable_group = "pumpjack"
mk3.module_slots = mk3_modules
mk3.mining_speed = mk3_speed
mk3.base_productivity = mk3_productivity
mk3.energy_source.emissions_per_minute = {
  pollution = mk3_pollution
}

mk3_corpse.name = "pumpjack-mk3-remnants"

tint_recursive(mk3_corpse.animation, {
  r = 1.0,
  g = 0.3,
  b = 0.2,
  a = 1
})

data:extend({mk3_corpse})

mk3.corpse = "pumpjack-mk3-remnants"

tint_recursive(mk3.graphics_set, {
  r = 1.0,
  g = 0.3,
  b = 0.2,
  a = 1
})

-- Vanilla pumpjack upgrades into MK2
data.raw["mining-drill"]["pumpjack"].next_upgrade = "pumpjack-mk2"

data:extend({mk2, mk3})

-- ==================== ITEMS ====================

data:extend({
  {
    type = "item",
    name = "pumpjack-mk2",
    icon = "__better-pumpjacks__/graphics/icons/pumpjack-mk2.png",
    icon_size = 256,
    subgroup = "extraction-machine",
    order = "b[fluid-extractor]-a[pumpjack-mk2]",
    place_result = "pumpjack-mk2",
    stack_size = 20
  },
  {
    type = "item",
    name = "pumpjack-mk3",
    icon = "__better-pumpjacks__/graphics/icons/pumpjack-mk3.png",
    icon_size = 256,
    subgroup = "extraction-machine",
    order = "b[fluid-extractor]-b[pumpjack-mk3]",
    place_result = "pumpjack-mk3",
    stack_size = 20
  }
})

-- ==================== RECIPES ====================

data:extend({
  {
    type = "recipe",
    name = "pumpjack-mk2",
    category = "crafting",
    energy_required = 12,
    ingredients = {
      {type = "item", name = "pumpjack", amount = 2},
      {type = "item", name = "advanced-circuit", amount = 25},
      {type = "item", name = "steel-plate", amount = 40},
      {type = "item", name = "pipe", amount = 25},
      {type = "item", name = "electric-engine-unit", amount = 10}
    },
    results = {{type = "item", name = "pumpjack-mk2", amount = 1}},
    enabled = false
  },
  {
    type = "recipe",
    name = "pumpjack-mk3",
    category = "crafting",
    energy_required = 20,
    ingredients = {
      {type = "item", name = "pumpjack-mk2", amount = 2},
      {type = "item", name = "advanced-circuit", amount = 50},
      {type = "item", name = "steel-plate", amount = 80},
      {type = "item", name = "pipe", amount = 50},
      {type = "item", name = "electric-engine-unit", amount = 20},
      {type = "item", name = "processing-unit", amount = 15}
    },
    results = {{type = "item", name = "pumpjack-mk3", amount = 1}},
    enabled = false
  }
})

-- ==================== TECHNOLOGIES ====================

local mk2_science = nil
local mk3_science = nil

if mods["space-exploration"] then
  -- Space Exploration / SE + K2
  mk2_science = add_existing_science_packs({
    "automation-science-pack",
    "logistic-science-pack",
    "chemical-science-pack",
    "space-science-pack"
  })

  mk3_science = add_existing_science_packs({
    "automation-science-pack",
    "logistic-science-pack",
    "chemical-science-pack",
    "production-science-pack",
    "space-science-pack"
  })

elseif mods["space-age"] then
  -- Space Age
  mk2_science = add_existing_science_packs({
    "automation-science-pack",
    "logistic-science-pack",
    "chemical-science-pack",
    "space-science-pack"
  })

  mk3_science = add_existing_science_packs({
    "automation-science-pack",
    "logistic-science-pack",
    "chemical-science-pack",
    "production-science-pack",
    "space-science-pack",
    "metallurgic-science-pack"
  })

else
  -- Vanilla / base
  mk2_science = add_existing_science_packs({
    "automation-science-pack",
    "logistic-science-pack",
    "chemical-science-pack"
  })

  mk3_science = add_existing_science_packs({
    "automation-science-pack",
    "logistic-science-pack",
    "chemical-science-pack",
    "production-science-pack",
    "utility-science-pack"
  })
end

data:extend({
  {
    type = "technology",
    name = "pumpjack-mk2",
    icon = "__better-pumpjacks__/graphics/icons/pumpjack-mk2.png",
    icon_size = 256,
    localised_description = mk2_technology_description,
    effects = {
      {type = "unlock-recipe", recipe = "pumpjack-mk2"}
    },
    prerequisites = add_existing_prerequisites({
      "advanced-oil-processing",
      "space-science-pack"
    }),
    unit = {
      count = 250,
      ingredients = mk2_science,
      time = 30
    }
  },
  {
    type = "technology",
    name = "pumpjack-mk3",
    icon = "__better-pumpjacks__/graphics/icons/pumpjack-mk3.png",
    icon_size = 256,
    localised_description = mk3_technology_description,
    effects = {
      {type = "unlock-recipe", recipe = "pumpjack-mk3"}
    },

    -- Important: hard-code MK2 here.
    -- Do not use add_existing_prerequisites for pumpjack-mk2.
    prerequisites = 
    {
     "pumpjack-mk2",
     "production-science-pack",
     "space-science-pack"
    },

    unit = {
      count = 400,
      ingredients = mk3_science,
      time = 45
    }
  }
})

-- Extra Space Age gate for MK3
if is_space_age() and not is_space_exploration() then
  table.insert(data.raw.technology["pumpjack-mk3"].prerequisites, "metallurgic-science-pack")
end

-- ==================== PUMPJACK PRODUCTIVITY RESEARCH ====================

local pumpjack_productivity_science = nil
local pumpjack_productivity_prerequisites = nil
local productivity_target_description = productivity_affects_vanilla
  and "vanilla pumpjacks, Pumpjack MK2, and Pumpjack MK3"
  or "Pumpjack MK2 and Pumpjack MK3"
local pumpjack_productivity_description = {
  "",
  "Increases productivity of ",
  productivity_target_description,
  " by +",
  format_percent(productivity_bonus_per_level),
  " per level, up to level ",
  format_number(max_productivity_level),
  "."
}

if mods["space-exploration"] then
  -- Space Exploration / SE + K2

  pumpjack_productivity_science = add_existing_science_packs({
    "automation-science-pack",
    "logistic-science-pack",
    "chemical-science-pack",
    "production-science-pack",
    "utility-science-pack",
    "kr-optimization-tech-card",
    "space-science-pack"
  })

  pumpjack_productivity_prerequisites = add_existing_prerequisites({
    "pumpjack-mk3",
    "production-science-pack",
    "space-science-pack",
    "utility-science-pack",
    "kr-optimization-tech-card-processing"
 })

elseif mods["space-age"] then
  -- Space Age
  pumpjack_productivity_science = add_existing_science_packs({
    "automation-science-pack",
    "logistic-science-pack",
    "chemical-science-pack",
    "production-science-pack",
    "utility-science-pack",
    "space-science-pack",
    "metallurgic-science-pack",
    "electromagnetic-science-pack"
  })

  pumpjack_productivity_prerequisites = add_existing_prerequisites({
    "pumpjack-mk3",
    "metallurgic-science-pack",
    "electromagnetic-science-pack"
  })

else
  -- Vanilla / base
  pumpjack_productivity_science = add_existing_science_packs({
    "automation-science-pack",
    "logistic-science-pack",
    "chemical-science-pack",
    "production-science-pack",
    "utility-science-pack"
  })

  pumpjack_productivity_prerequisites = add_existing_prerequisites({
    "pumpjack-mk3"
  })
end

data:extend({
  {
    type = "technology",
    name = "bpj-pumpjack-output",
    localised_name = {"technology-name.bpj-pumpjack-output"},
    localised_description = pumpjack_productivity_description,
    icon = "__better-pumpjacks__/graphics/icons/pumpjack-research.png",
    icon_size = 256,
    upgrade = true,
    max_level = "infinite",

    effects = {
      {
        type = "nothing",
        effect_description = pumpjack_productivity_description
      }
    },

    prerequisites = pumpjack_productivity_prerequisites,

    unit = {
      count_formula = productivity_research_count_formula,
      ingredients = pumpjack_productivity_science,
      time = 45
    },

    order = "e-p-b"
  }
})

-- ==================== HIDDEN PRODUCTIVITY VARIANTS ====================

local hidden_entities = {}
local vanilla_pumpjack = data.raw["mining-drill"]["pumpjack"]
local vanilla_productivity = vanilla_pumpjack.base_productivity or 0

for level = 1, max_productivity_level do
  if productivity_affects_vanilla then
    local vanilla_prod = table.deepcopy(vanilla_pumpjack)
    vanilla_prod.name = "pumpjack-prod-" .. level
    vanilla_prod.hidden = true
    vanilla_prod.hidden_in_factoriopedia = true
    vanilla_prod.localised_name = {"entity-name.pumpjack"}
    vanilla_prod.localised_description = {
      "",
      "Standard pumpjack with +",
      format_percent(vanilla_productivity + productivity_bonus_per_level * level),
      " productivity from pumpjack productivity research."
    }
    vanilla_prod.minable.result = "pumpjack"
    vanilla_prod.placeable_by = {item = "pumpjack", count = 1}
    vanilla_prod.base_productivity = vanilla_productivity + productivity_bonus_per_level * level
    vanilla_prod.next_upgrade = "pumpjack-mk2"

    table.insert(hidden_entities, vanilla_prod)
  end

  local mk2_prod = table.deepcopy(mk2)
  mk2_prod.name = "pumpjack-mk2-prod-" .. level
  mk2_prod.hidden = true
  mk2_prod.hidden_in_factoriopedia = true
  mk2_prod.localised_name = {"entity-name.pumpjack-mk2"}
  mk2_prod.localised_description = pumpjack_description(
    "Better",
    mk2_modules,
    mk2_speed,
    mk2_productivity + productivity_bonus_per_level * level,
    mk2_pollution,
    mk2_energy_usage
  )
  mk2_prod.minable.result = "pumpjack-mk2"
  mk2_prod.placeable_by = {item = "pumpjack-mk2", count = 1}
  mk2_prod.base_productivity =
    mk2_productivity + productivity_bonus_per_level * level
  mk2_prod.next_upgrade = "pumpjack-mk3"

  local mk3_prod = table.deepcopy(mk3)
  mk3_prod.name = "pumpjack-mk3-prod-" .. level
  mk3_prod.hidden = true
  mk3_prod.hidden_in_factoriopedia = true
  mk3_prod.localised_name = {"entity-name.pumpjack-mk3"}
  mk3_prod.localised_description = pumpjack_description(
    "Advanced",
    mk3_modules,
    mk3_speed,
    mk3_productivity + productivity_bonus_per_level * level,
    mk3_pollution,
    mk3_energy_usage
  )
  mk3_prod.minable.result = "pumpjack-mk3"
  mk3_prod.placeable_by = {item = "pumpjack-mk3", count = 1}
  mk3_prod.base_productivity =
    mk3_productivity + productivity_bonus_per_level * level

  table.insert(hidden_entities, mk2_prod)
  table.insert(hidden_entities, mk3_prod)
end

data:extend(hidden_entities)
