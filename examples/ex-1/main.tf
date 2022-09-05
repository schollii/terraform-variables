// It is not possible to specify how all attributes of objects in maps and lists should be defaulted

variable "nested_obj" {
  type = object({
    field1 = optional(number, 123)
    field3 = optional(string, "abc")
    field4 = optional(object({
      field1 = optional(number, 123)
      field3 = optional(string, "abc")
    }), {})
  })
}

variable "list" {
  type = list(object({
    field1 = optional(number, 123)
    field3 = optional(string, "abc")
    field4 = optional(bool, true)
  }))
  default = []
}

variable "map" {
  type = map(object({
    field1 = optional(number, 123)
    field3 = optional(string, "abc")
    field4 = optional(bool, true)
  }))
  default = {}
}

output "nested_obj" {
  value = var.nested_obj
}

output "list" {
  value = var.list
}

output "map" {
  value = var.map
}