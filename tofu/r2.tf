# One R2 bucket per static host. A live host is served by the bucket's custom
# domain, which creates its own proxied DNS record.
resource "cloudflare_r2_bucket" "static" {
  for_each = local.static_hosts

  account_id = local.account_id
  name       = each.value.bucket
  location   = "enam"
}

resource "cloudflare_r2_custom_domain" "static" {
  for_each = local.live_hosts

  account_id  = local.account_id
  bucket_name = cloudflare_r2_bucket.static[each.key].name
  domain      = each.value.fqdn
  zone_id     = local.zone_id
  enabled     = true
  min_tls     = "1.2"
}
