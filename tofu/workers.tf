# CORS proxy Worker on cors.gtfs.zone (source: worker/cors-proxy.js).
resource "cloudflare_workers_script" "cors_proxy" {
  account_id         = local.account_id
  script_name        = "cors-proxy"
  content            = file("${path.module}/worker/cors-proxy.js")
  main_module        = "cors-proxy.js"
  compatibility_date = "2026-11-01"

  bindings = [{
    type = "plain_text"
    name = "ALLOWED_ORIGINS"
    text = join(",", local.cors_proxy_origins)
  }]
}

# Served only on its custom domain, not on workers.dev.
resource "cloudflare_workers_script_subdomain" "cors_proxy" {
  account_id  = local.account_id
  script_name = cloudflare_workers_script.cors_proxy.script_name
  enabled     = false
}

resource "cloudflare_workers_custom_domain" "cors_proxy" {
  account_id = local.account_id
  zone_id    = local.zone_id
  hostname   = "cors.${local.zone}"
  service    = cloudflare_workers_script.cors_proxy.script_name
}
