terraform {
  experiments = [module_variable_optional_attrs]
}

// It is not possible to specify how all attributes of objects in maps and lists should be defaulted

variable "var" {
  type = map(object({
    field1 = optional(number)
    field3 = optional(string)
    field4 = optional(bool)
  }))
  default = {}
}

variable "var_defaults" {
  default = {
    _key_ = {
      field1 = 123
      field3 = "abc"
      field4 = true
    }
  }
}

locals {
  config = defaults(var.var, var.var_defaults)
}

output "config" {
  value = local.config
}