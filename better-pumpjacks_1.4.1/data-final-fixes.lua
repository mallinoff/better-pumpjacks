local function science_pack_exists(name)
  return data.raw["tool"] and data.raw["tool"][name]
end

local function add_existing_science_packs(list)
  local packs = {}

  for _, pack in pairs(list) do
    if science_pack_exists(pack) then
      table.insert(packs, {pack, 1})
    end
  end

  return packs
end

-- Only needed for Space Exploration.
-- SE generates staged infinite-tech versions and changes their cost/science packs.
if mods["space-exploration"] then
  local productivity_research_count_formula = settings.startup["bpj-productivity-research-base-cost"].value
    .. " + (L * "
    .. settings.startup["bpj-productivity-research-level-cost"].value
    .. ")"

  local science_packs = add_existing_science_packs({
    "automation-science-pack",
    "logistic-science-pack",
    "chemical-science-pack",
    "production-science-pack",
    "utility-science-pack",
    "se-rocket-science-pack",
    "space-science-pack",
    "kr-optimization-tech-card"
  })

  local tech_names = {
    "bpj-pumpjack-output",
    "bpj-pumpjack-output-2",
    "bpj-pumpjack-output-3",
    "bpj-pumpjack-output-4",
    "bpj-pumpjack-output-5",
    "bpj-pumpjack-output-6"
  }

  for _, tech_name in pairs(tech_names) do
    local tech = data.raw.technology[tech_name]

    if tech and tech.unit then
      tech.unit.count_formula = productivity_research_count_formula
      tech.unit.ingredients = table.deepcopy(science_packs)

      if tech_name == "bpj-pumpjack-output" then
        tech.prerequisites = {
          "pumpjack-mk3",
          "utility-science-pack",
          "kr-optimization-tech-card"
        }
      else
        local level = tonumber(string.match(tech_name, "%-(%d+)$"))

        if level then
          local previous_name =
            level == 2
            and "bpj-pumpjack-output"
            or "bpj-pumpjack-output-" .. (level - 1)

          tech.prerequisites = {previous_name}
        end
      end
    end
  end
end
