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
  }

})