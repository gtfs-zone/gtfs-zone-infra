locals {
  zone = "gtfs.zone"

  # Static hosts served from R2 buckets through their custom domains.
  # Each key is the host's label under gtfs.zone (one level only: Universal SSL
  # does not cover deeper names).
  #   index: directory URLs ("/x/") serve "/x/index.html"
  #   cors:  responses carry Access-Control-Allow-Origin: *
  #   live:  the custom domain and rules exist
  static_hosts = {
    rt-archive = { bucket = "gtfs-zone-rt-archive", index = false, cors = true, live = true }
    data       = { bucket = "gtfs-zone-data", index = false, cors = true, live = true }
    sites      = { bucket = "gtfs-zone-sites", index = true, cors = false, live = true }
  }

  live_hosts = { for k, h in local.static_hosts : k => merge(h, { fqdn = "${k}.${local.zone}" }) if h.live }
}
