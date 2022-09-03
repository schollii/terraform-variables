terraform {
  experiments = [module_variable_optional_attrs]
}

variable "var" {
  type = object({
    field1 = optional(number)
    field2 = optional(object({
      field3 = optional(string)
      field4 = optional(bool)
    }))
  })
  default = {}
}

variable "var_defaults" {
  default = {
    field1 = 123
    field2 = {
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