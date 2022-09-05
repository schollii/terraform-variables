terraform {
  experiments = [module_variable_optional_attrs]
}

variable "var1" {
  type = object({
    attr1 = optional(number)
    attr2 = optional(object({ attr1 = optional(number) }))
    attr3 = optional(map(object({ attr1 = optional(number) })))
    attr4 = optional(list(object({ attr1 = optional(number) })))

    obj = optional(object({
      attr1 = optional(number)
      attr2 = optional(object({ attr1 = optional(number) }))
      attr3 = optional(map(object({ attr1 = optional(number) })))
      attr4 = optional(list(object({ attr1 = optional(number) })))
    }))

    map = optional(map(object({
      attr1 = optional(number)
      attr2 = optional(object({ attr1 = optional(number) }))
      attr3 = optional(map(object({ attr1 = optional(number) })))
      attr4 = optional(list(object({ attr1 = optional(number) })))
    })))

    list = optional(list(object({
      attr1 = optional(number)
      attr2 = optional(object({ attr1 = optional(number) }))
      attr3 = optional(map(object({ attr1 = optional(number) })))
      attr4 = optional(list(object({ attr1 = optional(number) })))
    })))
  })

  default = {}
}

variable "var1_defaults" {
  default = {
    attr1 = 1
    attr2 = {
      attr1 = 1
    }
    attr3 = {
      attr1 = 1
    }
    attr4 = {
      attr1 = 1
    }

    obj = {
      attr1 = 2
      attr2 = {
        attr1 = 2
      }
      attr3 = {
        attr1 = 2
      }
      attr4 = {
        attr1 = 2
      }
    }

    map = {
      attr1 = 3
      attr2 = {
        attr1 = 3
      }
      attr3 = {
        attr1 = 3
      }
      attr4 = {
        attr1 = 3
      }
    }

    list = {
      attr1 = 4
      attr2 = {
        attr1 = 4
      }
      attr3 = {
        attr1 = 4
      }
      attr4 = {
        attr1 = 4
      }
    }
  }
}

locals {
  config = defaults(var.var1, var.var1_defaults)
}

output "config" {
  value = local.config
}