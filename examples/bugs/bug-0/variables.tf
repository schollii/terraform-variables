
variable "var1" {
  type = object({
    attr1 = optional(number, 1)
    attr2 = optional(object({
      attr1 = optional(number, 1)
    }), {attr3 = 1})
  })
}

#variable "var1_defaults" {
#  default = {
#    attr1 = 1
#    attr2 = {
#      attr3 = 1
#    }
#  }
#}

locals {
#  config = defaults(var.var1, var.var1_defaults)
}

output "config" {
#  value = local.config
  value = var.var1
}