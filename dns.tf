data "cloudflare_zone" "milanoid_net" {
  filter = {
    name = local.zone_name
  }
}

locals {
  zone_name = "milanoid.net"

  # Traefik's LoadBalancer answers on both node IPs via klipper-lb, so either
  # reaches the ingress; which one a record uses is historical, not meaningful.
  traefik_ip_hpmini01 = "192.168.1.231"
  traefik_ip_hpmini02 = "192.168.1.232"
}

# ---------------------------------------------------------------------------
# Cluster services behind the Traefik ingress.
#
# All unproxied: Cloudflare cannot proxy an RFC1918 address, and these names are
# only meant to resolve from the LAN/VPN.
# ---------------------------------------------------------------------------

locals {
  # subdomain => ingress node IP + Cloudflare record comment
  traefik_records = {
    "argo"           = { ip = local.traefik_ip_hpmini01, comment = "Argo Workflows" }
    "argocd"         = { ip = local.traefik_ip_hpmini01, comment = null }
    "bazarr"         = { ip = local.traefik_ip_hpmini01, comment = null }
    "grafana"        = { ip = local.traefik_ip_hpmini01, comment = "Internal IP of the Ingress service (Traefik) for Graphana." }
    "homarr"         = { ip = local.traefik_ip_hpmini02, comment = "Homarr" }
    "home-dashboard" = { ip = local.traefik_ip_hpmini01, comment = "k3s Traefik ingress (homelab-cluster: apps/argocd/home-dashboard)" }
    "linkding"       = { ip = local.traefik_ip_hpmini01, comment = "Internal IP of the Ingress service (Traefik)." }
    "pihole"         = { ip = local.traefik_ip_hpmini02, comment = null }
    "prowlarr"       = { ip = local.traefik_ip_hpmini01, comment = null }
    "radarr"         = { ip = local.traefik_ip_hpmini01, comment = "radarr via traefik ingress" }
    "rollouts"       = { ip = local.traefik_ip_hpmini01, comment = "Argo Rollouts dashboard via Traefik ingress" }
    "sonarr"         = { ip = local.traefik_ip_hpmini01, comment = "Internal IP for Traefik service Sonarr" }
    "torrent"        = { ip = local.traefik_ip_hpmini01, comment = null }
  }
}

resource "cloudflare_dns_record" "traefik" {
  for_each = local.traefik_records

  zone_id = data.cloudflare_zone.milanoid_net.zone_id
  name    = "${each.key}.${local.zone_name}"
  type    = "A"
  content = each.value.ip
  ttl     = 1 # automatic
  proxied = false
  comment = each.value.comment
}

# ---------------------------------------------------------------------------
# Public hostnames served through Cloudflare tunnels.
#
# Proxied CNAMEs to <tunnel-uuid>.cfargotunnel.com — the tunnel itself is what
# reaches the cluster, so no origin IP is exposed.
# ---------------------------------------------------------------------------

locals {
  # subdomain => cloudflared tunnel UUID + Cloudflare record comment
  tunnel_records = {
    "argocd-badge" = { tunnel_id = "7dbe9987-fbda-4d0f-99c2-026ade7dda10", comment = null }
    "audiobooks"   = { tunnel_id = "89bd5528-bdf9-486a-99ca-6680e5f6d9ec", comment = "tunnel for audiobokshelf" }
    "headlamp"     = { tunnel_id = "ee6aeecb-8525-46af-885f-93bbf970e059", comment = null }
    "jenkins"      = { tunnel_id = "f5444cf3-c744-4c1c-821c-0d42cadd622e", comment = null }
    "jf"           = { tunnel_id = "98d4f567-4e8a-4a7d-a415-4a75e0b4889f", comment = null }
    "lkd"          = { tunnel_id = "cf838265-1863-4c1b-a710-f8bb9fbf038b", comment = "This is a DNS record required for Cloudflare Tunnel (cloudflared running in my Kubernetes HomeLab)" }
    "web"          = { tunnel_id = "1adb981b-fce3-4a1c-bdf5-8466327ceac3", comment = "tunnel for webhosting" }
  }
}

resource "cloudflare_dns_record" "tunnel" {
  for_each = local.tunnel_records

  zone_id = data.cloudflare_zone.milanoid_net.zone_id
  name    = "${each.key}.${local.zone_name}"
  type    = "CNAME"
  content = "${each.value.tunnel_id}.cfargotunnel.com"
  ttl     = 1 # automatic; required to be 1 while proxied
  proxied = true
  comment = each.value.comment
}

# ---------------------------------------------------------------------------
# Hosts outside the k3s cluster: the NAS, Proxmox LXCs, and a cloud lab.
# ---------------------------------------------------------------------------

locals {
  # subdomain => address + Cloudflare record comment
  host_records = {
    "*.mercury"   = { ip = "4.208.18.120", comment = "Kubecraft (Kubernetes in the Cloud)" }
    "capa-argo"   = { ip = "127.0.0.1", comment = null }
    "capa-argocd" = { ip = "127.0.0.1", comment = null }
    "jellyfin"    = { ip = "192.168.1.201", comment = null }
    "nas"         = { ip = "192.168.1.36", comment = "Synology NAS" }
    "nexus"       = { ip = "192.168.1.204", comment = "Nexus running in LXC@proxmox" }
    "sonar"       = { ip = "192.168.1.203", comment = "sonar running as LXC on Proxmox" }
  }
}

resource "cloudflare_dns_record" "host" {
  for_each = local.host_records

  zone_id = data.cloudflare_zone.milanoid_net.zone_id
  name    = "${each.key}.${local.zone_name}"
  type    = "A"
  content = each.value.ip
  ttl     = 1 # automatic
  proxied = false
  comment = each.value.comment
}

# ---------------------------------------------------------------------------
# vpn: the home WAN address, kept current by ddclient on hpmini01.
#
# ddclient rewrites `content` whenever the ISP hands out a new address, so these
# two are deliberately excluded from drift management — OpenTofu owns the TTL,
# proxy setting and comment, but never the address itself. The values committed
# here are only what was current at import time and will go stale; that is fine.
# ---------------------------------------------------------------------------

resource "cloudflare_dns_record" "vpn_a" {
  zone_id = data.cloudflare_zone.milanoid_net.zone_id
  name    = "vpn.${local.zone_name}"
  type    = "A"
  content = "109.81.174.65"
  ttl     = 1 # automatic
  proxied = false
  comment = null

  lifecycle {
    ignore_changes = [content]
  }
}

resource "cloudflare_dns_record" "vpn_aaaa" {
  zone_id = data.cloudflare_zone.milanoid_net.zone_id
  name    = "vpn.${local.zone_name}"
  type    = "AAAA"
  content = "2a00:1028:838a:1248:243f:5ea1:5f5f:4584"
  ttl     = 1 # automatic
  proxied = false
  comment = "Automatically updated by ddclient running on hpmini01."

  lifecycle {
    ignore_changes = [content]
  }
}

# home-dashboard was added standalone in #2; it belongs in the traefik map with
# every other ingress record.
moved {
  from = cloudflare_dns_record.home_dashboard
  to   = cloudflare_dns_record.traefik["home-dashboard"]
}
