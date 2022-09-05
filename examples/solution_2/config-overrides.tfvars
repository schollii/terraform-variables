# this file must not be named terraform.tfvars(.json) nor *.auto.tfvars(.json)
# as it will only be used by the tf-vars spec generator

somevar = "abc"

config = {
  buckets = {
    log = {
      bucket_name = "name"
    }

    storage = {
      bucket_1 = {
        bucket_name         = "some-name"
        intelligent_tiering = {
          duration = 50
        }
      }
    }

    items = [
      {
        prefix = "prefix"
      }
    ]
  }
}
