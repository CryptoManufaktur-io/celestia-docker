# celestia-docker

Docker compose for Celestia.

Meant to be used with central-proxy-docker for traefik and Prometheus remote write; use :ext-network.yml in COMPOSE_FILE inside .env in that case.

### Bottleneck Bandwidth and Round-trip propagation time

Starting on v3.0.0, it is required to enable BBR and MCTCP on the host machine.

To enable BBR:

```
sudo modprobe tcp_bbr
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
sudo sysctl -p
```

Then verify BBR is enabled:

```
sysctl net.ipv4.tcp_congestion_control
```

For *testing* purposes, it can be bypassed by adding the following flag to `EXTRA_FLAGS` in the `.env` file:

`--force-no-bbr`

## Version

Celestia Docker uses a semver scheme.

This is celestia-docker v0.1.0
