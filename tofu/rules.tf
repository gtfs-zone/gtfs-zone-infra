# Zone entry-point rulesets for the live static hosts.

locals {
  host_set = join(" ", [for h in local.live_hosts : jsonencode(h.fqdn)])
  cors_set = join(" ", [for h in local.live_hosts : jsonencode(h.fqdn) if h.cors])

  rewrite_rules = [for k, h in local.live_hosts : {
    ref         = "${k}_index"
    description = "${h.fqdn}: directory URLs to index.html"
    expression  = "(http.host eq \"${h.fqdn}\" and ends_with(http.request.uri.path, \"/\"))"
    path        = "concat(http.request.uri.path, \"index.html\")"
  } if h.index]
}

resource "cloudflare_ruleset" "url_rewrite" {
  zone_id = local.zone_id
  name    = "default"
  kind    = "zone"
  phase   = "http_request_transform"

  rules = [for r in local.rewrite_rules : {
    ref         = r.ref
    description = r.description
    expression  = r.expression
    action      = "rewrite"
    enabled     = true
    action_parameters = {
      uri = {
        path = { expression = r.path }
      }
    }
  }]
}

# Free plans skip HTML by default; this caches everything and honours the
# objects' Cache-Control.
resource "cloudflare_ruleset" "cache" {
  zone_id = local.zone_id
  name    = "default"
  kind    = "zone"
  phase   = "http_request_cache_settings"

  rules = [{
    ref         = "static_cache"
    description = "Static hosts: cache everything, respect origin TTLs"
    expression  = "(http.host in {${local.host_set}})"
    action      = "set_cache_settings"
    enabled     = true
    action_parameters = {
      cache       = true
      edge_ttl    = { mode = "respect_origin" }
      browser_ttl = { mode = "respect_origin" }
    }
  }]
}

resource "cloudflare_ruleset" "response_headers" {
  zone_id = local.zone_id
  name    = "default"
  kind    = "zone"
  phase   = "http_response_headers_transform"

  rules = local.cors_set == "" ? [] : [{
    ref         = "static_cors"
    description = "Static data hosts: open CORS"
    expression  = "(http.host in {${local.cors_set}})"
    action      = "rewrite"
    enabled     = true
    action_parameters = {
      headers = {
        "Access-Control-Allow-Origin"   = { operation = "set", value = "*" }
        "Access-Control-Expose-Headers" = { operation = "set", value = "ETag" }
      }
    }
  }]
}
