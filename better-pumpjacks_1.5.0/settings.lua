data:extend({

  {
    type = "double-setting",
    name = "bpj-mk2-speed",
    setting_type = "startup",
    default_value = 1.5,
    minimum_value = 1.0,
    maximum_value = 10.0,
    order = "a"
  },

  {
    type = "double-setting",
    name = "bpj-mk3-speed",
    setting_type = "startup",
    default_value = 2.0,
    minimum_value = 1.0,
    maximum_value = 20.0,
    order = "b"
  },

  {
    type = "double-setting",
    name = "bpj-mk2-productivity",
    setting_type = "startup",
    default_value = 0.1,
    minimum_value = 0,
    maximum_value = 1.0,
    order = "c"
  },

  {
    type = "double-setting",
    name = "bpj-mk3-productivity",
    setting_type = "startup",
    default_value = 0.2,
    minimum_value = 0,
    maximum_value = 2.0,
    order = "d"
  },

  {
    type = "int-setting",
    name = "bpj-mk2-modules",
    setting_type = "startup",
    default_value = 4,
    minimum_value = 0,
    maximum_value = 20,
    order = "e"
  },

  {
    type = "int-setting",
    name = "bpj-mk3-modules",
    setting_type = "startup",
    default_value = 8,
    minimum_value = 0,
    maximum_value = 20,
    order = "f"
  },

  {
    type = "double-setting",
    name = "bpj-mk2-pollution",
    setting_type = "startup",
    default_value = 20,
    minimum_value = 0,
    maximum_value = 100,
    order = "g"
  },

  {
    type = "double-setting",
    name = "bpj-mk3-pollution",
    setting_type = "startup",
    default_value = 30,
    minimum_value = 0,
    maximum_value = 100,
    order = "h"
  },

  {
    type = "double-setting",
    name = "bpj-productivity-research-bonus",
    setting_type = "startup",
    default_value = 0.1,
    minimum_value = 0,
    maximum_value = 1.0,
    order = "i"
  },

  {
    type = "int-setting",
    name = "bpj-mk2-energy-usage",
    setting_type = "startup",
    default_value = 180,
    minimum_value = 1,
    maximum_value = 10000,
    order = "j"
  },

  {
    type = "int-setting",
    name = "bpj-mk3-energy-usage",
    setting_type = "startup",
    default_value = 300,
    minimum_value = 1,
    maximum_value = 10000,
    order = "k"
  },

  {
    type = "int-setting",
    name = "bpj-max-productivity-level",
    setting_type = "startup",
    default_value = 50,
    minimum_value = 1,
    maximum_value = 500,
    order = "l"
  },

  {
    type = "bool-setting",
    name = "bpj-productivity-affects-vanilla",
    setting_type = "startup",
    default_value = false,
    order = "m"
  },

  {
    type = "int-setting",
    name = "bpj-productivity-research-base-cost",
    setting_type = "startup",
    default_value = 1000,
    minimum_value = 1,
    maximum_value = 1000000,
    order = "n"
  },

  {
    type = "int-setting",
    name = "bpj-productivity-research-level-cost",
    setting_type = "startup",
    default_value = 1000,
    minimum_value = 0,
    maximum_value = 1000000,
    order = "o"
  },

  {
    type = "int-setting",
    name = "bpj-warning-sampling-rate",
    setting_type = "runtime-global",
    default_value = 60,
    minimum_value = 5,
    maximum_value = 3600,
    order = "p"
  },

  {
    type = "bool-setting",
    name = "bpj-output-warnings-enabled",
    setting_type = "runtime-global",
    default_value = true,
    order = "q"
  },

  {
    type = "int-setting",
    name = "bpj-warning-repeat-rate",
    setting_type = "runtime-global",
    default_value = 60,
    minimum_value = 5,
    maximum_value = 3600,
    order = "r"
  }

})
