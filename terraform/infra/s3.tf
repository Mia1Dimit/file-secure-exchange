locals {
  s3_notifications = {
    for item in flatten([
      for ps_key, s3 in var.s3s : [
        for as_key, notification in s3.notifications : {
          key        = as_key
          bucket_key = ps_key
          value = {
            lambda_function = notification.lambda_function
            bucket          = module.s3[ps_key].s3-id
          }
        }
      ]
    ]) : "${item.bucket_key}-${item.key}" => item.value
  }

  # Deny-insecure-transport policy per bucket, satisfies require-tls.rego.
  # Built from the bucket name directly (S3 ARNs are global — no
  # region/account segment — so this doesn't need a data lookup).
  s3_tls_deny_policies = {
    for key, s3 in var.s3s : key => jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid       = "DenyInsecureTransport"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:*"
          Resource = [
            "arn:aws:s3:::${s3.name}",
            "arn:aws:s3:::${s3.name}/*",
          ]
          Condition = {
            Bool = {
              "aws:SecureTransport" = "false"
            }
          }
        }
      ]
    })
  }
}

module "s3" {
  for_each              = var.s3s
  source                = "../modules/s3-bucket"
  bucket_name           = each.value["name"]
  rules                 = each.value["rules"]
  blockpublicacls       = each.value["blockpublicacls"]
  blockpublicpolicy     = each.value["blockpublicpolicy"]
  ignorepublicacls      = each.value["ignorepublicacls"]
  restrictpublicbuckets = each.value["restrictpublicbuckets"]
  enable_versioning     = each.value["enable_versioning"]
  specifictags          = each.value["specifictags"]
  name                  = each.value["name"]

  applicationname = var.applicationname
  applicationid   = var.applicationid
  environment     = each.value["environment"]
}

# MVP baseline is SSE-S3 (AES256). Switch sse_algorithm to "aws:kms" + set kms_key_id once
# customer-managed keys land in Phase 4.
module "s3-sse" {
  for_each   = var.s3s
  source     = "../modules/s3-sse-config"
  bucket_name = module.s3[each.key].s3-id
  sse_algorithm = "AES256"
  kms_key_id    = null

  depends_on = [module.s3]
}

# denies any request where aws:SecureTransport is false
module "s3-bucket-policy" {
  for_each    = var.s3s
  source      = "../modules/s3-bucket-policy"
  bucket_name = module.s3[each.key].s3-id
  policy      = local.s3_tls_deny_policies[each.key]

  depends_on = [module.s3]
}

module "s3-bucket-notification" {
  for_each = local.s3_notifications
  source   = "../modules/s3-bucket-notification"

  bucket           = each.value.bucket
  lambda_functions = each.value.lambda_function

  # Ensure Lambda permissions are created before S3 notifications
  depends_on = [module.lambda_permission]
}
