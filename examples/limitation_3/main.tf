terraform {
  experiments = [module_variable_optional_attrs]
}

// Expectation: if defaults are given anywhere in hierarchy, then it should be
// possible to specify, in the .tfvars file, only what needs overriding

variable "var" {
  type = object({
    field1 = optional(number)
    field2 = optional(object({
      field3 = optional(string)
      field4 = optional(bool)
    }))
  })

  default = {
    field1 = 123
    field2 = {
      field3 = "abc"
      field4 = true // tfvars will only give this one
    }
  }
}

locals {
  config = var.var
}

resource "null_resource" "dummy" {}

output "config" {
  value = local.config
}