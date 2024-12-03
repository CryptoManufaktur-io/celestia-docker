# celestia-docker

Docker compose for Celestia.

Meant to be used with central-proxy-docker for traefik and Prometheus remote write; use :ext-network.yml in COMPOSE_FILE inside .env in that case.

### Validator Key Generation

Run `docker compose run --rm create-validator-keys`

It is meant to be executed only once, it has no sanity checks and creates the `priv_validator_key.json`, `priv_validator_state.json` and `voter_state.json` files inside the `config/` folder.

Remember to backup those files if you're running a validator.

### Wallet Creation

An operator wallet is needed for staking operations. We provide a simple command to generate it, so it can be done in an air-gapped environment. It is meant to be executed only once, it has no sanity checks. It creates the operator wallet and stores the result in the `keyring/` folder.

Make sure to backup the `keyring/$MONIKER.account_info` file, it is the only way to recover the wallet.

Run `docker compose run --rm create-wallet`

### Register Validator

This assumes an operator wallet `keyring/$MONIKER.info` is present, and the `priv_validator_key.json` is present in the `config/` folder.

`docker compose run --rm register-validator`

### CLI

An image with the `celestia-appd` binary is also avilable, e.g:

`docker compose run --rm cli tendermint show-validator`

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
