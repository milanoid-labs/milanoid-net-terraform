data "cloudflare_zone" "milanoid_net" {
  filter = {
    name = local.zone_name
  }
}

locals {
  zone_name = "milanoid.net"

  # Traefik's LoadBalancer answers on both node IPs via klipper-lb, so either
  # reaches the ingress. Existing internal records point at hpmini01, so these
  # follow suit rather than splitting across nodes for no reason.
  traefik_ip = "192.168.1.231" # hpmini01
}

# home-dashboard is reached over the LAN through the cluster's Traefik ingress,
# not a Cloudflare tunnel, so this is a plain A record to a node IP. It must stay
# unproxied: Cloudflare cannot proxy an RFC1918 address, and the name is only
# meant to resolve from the LAN/VPN.
#
# The Ingress itself lives in the homelab-cluster repo:
# apps/argocd/home-dashboard/frontend-ingress.yaml
resource "cloudflare_dns_record" "home_dashboard" {
  zone_id = data.cloudflare_zone.milanoid_net.zone_id
  name    = "home-dashboard.${local.zone_name}"
  type    = "A"
  content = local.traefik_ip
  ttl     = 300 # explicit 5 minutes; 1 would mean "automatic" (Cloudflare's own default)
  proxied = false
  comment = "k3s Traefik ingress (homelab-cluster: apps/argocd/home-dashboard)"
}
