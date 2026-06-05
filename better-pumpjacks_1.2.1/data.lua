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

-- ==================== PUMPJACK MK2 ====================

local mk2 = table.deepcopy(data.raw["mining-drill"]["pumpjack"])
local mk2_corpse = table.deepcopy(data.raw["corpse"]["pumpjack-remnants"])

mk2.name = "pumpjack-mk2"
mk2.icon = "__better-pumpjacks__/graphics/icons/pumpjack-mk2.png"
mk2.icon_size = 256
mk2.minable.result = "pumpjack-mk2"
mk2.energy_usage = "180kW"
mk2.fast_replaceable_group = "pumpjack"
mk2.next_upgrade = "pumpjack-mk3"
mk2.module_slots =
  settings.startup["bpj-mk2-modules"].value
mk2.mining_speed =
  settings.startup["bpj-mk2-speed"].value
mk2.base_productivity =
  settings.startup["bpj-mk2-productivity"].value
mk2.energy_source.emissions_per_minute = {
  pollution = settings.startup["bpj-mk2-pollution"].value
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

mk3.name = "pumpjack-mk3"
mk3.icon = "__better-pumpjacks__/graphics/icons/pumpjack-mk3.png"
mk3.icon_size = 256
mk3.minable.result = "pumpjack-mk3"
mk3.energy_usage = "300kW"
mk3.fast_replaceable_group = "pumpjack"
mk3.module_slots =
  settings.startup["bpj-mk3-modules"].value
mk3.mining_speed =
  settings.startup["bpj-mk3-speed"].value
mk3.base_productivity =
  settings.startup["bpj-mk3-productivity"].value
mk3.energy_source.emissions_per_minute = {
  pollution = settings.startup["bpj-mk3-pollution"].value
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

local mk2_science = add_existing_science_packs({
  "automation-science-pack",
  "logistic-science-pack",
  "chemical-science-pack",
  "se-rocket-science-pack",
  "space-science-pack"
})

local mk3_science = add_existing_science_packs({
  "automation-science-pack",
  "logistic-science-pack",
  "chemical-science-pack",
  "production-science-pack",
  "se-rocket-science-pack",
  "space-science-pack",
  "metallurgic-science-pack"
})

data:extend({
  {
    type = "technology",
    name = "pumpjack-mk2",
    icon = "__better-pumpjacks__/graphics/icons/pumpjack-mk2.png",
    icon_size = 256,
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
    effects = {
      {type = "unlock-recipe", recipe = "pumpjack-mk3"}
    },
    prerequisites = add_existing_prerequisites({
      "pumpjack-mk2",
      "metallurgic-science-pack"
    }),
    unit = {
      count = 400,
      ingredients = mk3_science,
      time = 45
    }
  }
})

-- ==================== PUMPJACK PRODUCTIVITY RESEARCH ====================

local pumpjack_productivity_science = nil

if mods["space-exploration"] then
  pumpjack_productivity_science = add_existing_science_packs({
    "automation-science-pack",
    "logistic-science-pack",
    "chemical-science-pack",
    "production-science-pack",
    "se-rocket-science-pack"
  })

else

  pumpjack_productivity_science = add_existing_science_packs({
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
  name = "bpj-pumpjack-output",
  localised_name = {"technology-name.pumpjack-productivity"},
  icon = "__better-pumpjacks__/graphics/icons/pumpjack-research.png",
  icon_size = 256,
  upgrade = true,
  max_level = "infinite",

    effects = {
      {
        type = "nothing",
        effect_description = {"technology-description.pumpjack-productivity"}
      }
    },

    prerequisites = add_existing_prerequisites({
      "pumpjack-mk3"
    }),

    unit = {
      count_formula = "(1000 * L) + (250 * L * L)",
      ingredients = pumpjack_productivity_science,
      time = 45
    },

    order = "e-p-b"
  }
})

-- ==================== HIDDEN PRODUCTIVITY VARIANTS ====================

local max_productivity_level = 50
local productivity_bonus_per_level = 0.10

local hidden_entities = {}

for level = 1, max_productivity_level do
  local mk2_prod = table.deepcopy(mk2)
  mk2_prod.name = "pumpjack-mk2-prod-" .. level
  mk2_prod.hidden = true
  mk2_prod.hidden_in_factoriopedia = true
  mk2_prod.localised_name = {"entity-name.pumpjack-mk2"}
  mk2_prod.minable.result = "pumpjack-mk2"
  mk2_prod.base_productivity =
    settings.startup["bpj-mk2-productivity"].value + productivity_bonus_per_level * level

  local mk3_prod = table.deepcopy(mk3)
  mk3_prod.name = "pumpjack-mk3-prod-" .. level
  mk3_prod.hidden = true
  mk3_prod.hidden_in_factoriopedia = true
  mk3_prod.localised_name = {"entity-name.pumpjack-mk3"}
  mk3_prod.minable.result = "pumpjack-mk3"
  mk3_prod.base_productivity =
    settings.startup["bpj-mk3-productivity"].value + productivity_bonus_per_level * level

  table.insert(hidden_entities, mk2_prod)
  table.insert(hidden_entities, mk3_prod)
end

data:extend(hidden_entities)