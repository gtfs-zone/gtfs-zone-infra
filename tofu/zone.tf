# Proxied traffic is TLS to the origin with a valid certificate.
resource "cloudflare_zone_setting" "ssl" {
  zone_id    = local.zone_id
  setting_id = "ssl"
  value      = "strict"
}
