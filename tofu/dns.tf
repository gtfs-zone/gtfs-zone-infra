data "cloudflare_zone" "gtfs" {
  filter = {
    name = local.zone
  }
}

locals {
  zone_id    = data.cloudflare_zone.gtfs.id
  account_id = data.cloudflare_zone.gtfs.account.id

  # Records with nothing in the cluster behind them. Every other gtfs.zone
  # record is owned by external-dns (IngressRoutes and DNSEndpoints); keep the
  # two sets apart.
  dns_records = {
    # GitHub Pages (gtfs-zone-homepage). Pages issues its own certificate, so
    # these stay DNS-only.
    apex_a_108    = { name = local.zone, type = "A", content = "185.199.108.153" }
    apex_a_109    = { name = local.zone, type = "A", content = "185.199.109.153" }
    apex_a_110    = { name = local.zone, type = "A", content = "185.199.110.153" }
    apex_a_111    = { name = local.zone, type = "A", content = "185.199.111.153" }
    apex_aaaa_0   = { name = local.zone, type = "AAAA", content = "2606:50c0:8000::153" }
    apex_aaaa_1   = { name = local.zone, type = "AAAA", content = "2606:50c0:8001::153" }
    apex_aaaa_2   = { name = local.zone, type = "AAAA", content = "2606:50c0:8002::153" }
    apex_aaaa_3   = { name = local.zone, type = "AAAA", content = "2606:50c0:8003::153" }
    www           = { name = "www.${local.zone}", type = "CNAME", content = "gtfs-zone.github.io" }
    pages_root    = { name = "_github-pages-challenge-gtfs-zone.${local.zone}", type = "TXT", content = "\"6f93426007950afde3000862d961da\"" }
    pages_rt      = { name = "_github-pages-challenge-gtfs-zone.rt.${local.zone}", type = "TXT", content = "\"9b8d96dfaeb744f806603de08518d1\"" }
    google_verify = { name = local.zone, type = "TXT", content = "\"google-site-verification=v51TLE5S8axq3-3sERroQvHRWTbSZwzdtYaD7NpvBcY\"" }

    # Porkbun email forwarding.
    spf = { name = local.zone, type = "TXT", content = "\"v=spf1 include:_spf.porkbun.com ~all\"" }
    mx1 = { name = local.zone, type = "MX", content = "fwd1.porkbun.com", priority = 10 }
    mx2 = { name = local.zone, type = "MX", content = "fwd2.porkbun.com", priority = 20 }
  }
}

resource "cloudflare_dns_record" "static" {
  for_each = local.dns_records

  zone_id  = local.zone_id
  name     = each.value.name
  type     = each.value.type
  content  = each.value.content
  priority = lookup(each.value, "priority", null)
  ttl      = 1
  proxied  = false
}
