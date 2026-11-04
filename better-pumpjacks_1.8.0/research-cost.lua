-- Shared by data.lua and SE final fixes so every research stage uses one curve.
return function(startup)
  return startup["bpj-productivity-research-base-cost"].value
    .. " + (L * " .. startup["bpj-productivity-research-level-cost"].value .. ")"
    .. " + (L ^ 2 * " .. startup["bpj-productivity-research-quadratic-cost"].value .. ")"
end
