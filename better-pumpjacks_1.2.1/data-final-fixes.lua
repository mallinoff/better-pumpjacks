if mods["space-exploration"] then
  local science_packs = {
    {"automation-science-pack", 1},
    {"logistic-science-pack", 1},
    {"chemical-science-pack", 1},
    {"production-science-pack", 1},
    {"se-rocket-science-pack", 1}
  }

  -- Base level
  local base_tech = data.raw.technology["bpj-pumpjack-output"]

  if base_tech and base_tech.unit then
    base_tech.unit.count_formula = "1000 + (L * 1000)"
    base_tech.unit.ingredients = table.deepcopy(science_packs)
  end

  -- SE-generated staged levels
  for level = 2, 6 do
    local tech = data.raw.technology["bpj-pumpjack-output-" .. level]

    if tech and tech.unit then
      tech.unit.count_formula = "1000 + (L * 1000)"
      tech.unit.ingredients = table.deepcopy(science_packs)

      -- Remove SE's added science-pack prerequisites,
      -- while keeping the previous research level prerequisite.
      local previous_name =
        level == 2
        and "bpj-pumpjack-output"
        or "bpj-pumpjack-output-" .. (level - 1)

      tech.prerequisites = {previous_name}
    end
  end
end