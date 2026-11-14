# Proxied traffic is TLS to the origin with a valid certificate.
resource "cloudflare_zone_setting" "ssl" {
  zone_id    = local.zone_id
  setting_id = "ssl"
  value      = "strict"
}

# Plain http on proxied hosts redirects to https.
resource "cloudflare_zone_setting" "always_use_https" {
  zone_id    = local.zone_id
  setting_id = "always_use_https"
  value      = "on"
}

# HTML rewriting features are off; with them on, Cloudflare drops the ETag on HTML.
resource "cloudflare_zone_setting" "html_rewrites" {
  for_each   = toset(["email_obfuscation", "automatic_https_rewrites", "server_side_exclude", "replace_insecure_js"])
  zone_id    = local.zone_id
  setting_id = each.key
  value      = "off"
}
