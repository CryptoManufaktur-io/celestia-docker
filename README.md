# celestia-docker

Docker compose for Celestia.

Meant to be used with [central-proxy-docker](https://github.com/CryptoManufaktur-io/central-proxy-docker) for traefik
and Prometheus remote write; use `:ext-network.yml` in `COMPOSE_FILE` inside `.env` in that case.

## Quick setup

Run `cp default.env .env`, then `nano .env`, and update values like MONIKER, NETWORK, and either SNAPSHOT or RAPID_SYNC_URL if you prefer to sync using one of these methods.

If you want the consensus node RPC ports exposed locally, use `rpc-shared.yml` in `COMPOSE_FILE` inside `.env`.

- `./celestiad install` brings in docker-ce, if you don't have Docker installed already.
- `docker compose run --rm create-validator-keys` creates the consensus/validator node keys
- `./celestiad up`

To update the software, run `./celestiad update` and then `./celestiad up`

## celestia-app

### Validator Key Generation

Run `docker compose run --rm create-validator-keys`

It is meant to be executed only once, it has no sanity checks and creates the `priv_validator_key.json`, `priv_validator_state.json` and `voter_state.json` files inside the `keys/consensus/` folder.

Remember to backup those files if you're running a validator.

### Operator Wallet Creation

An operator wallet is needed for staking operations. We provide a simple command to generate it, so it can be done in an air-gapped environment. It is meant to be executed only once, it has no sanity checks. It creates the operator wallet and stores the result in the `keys/operator/` folder.

Make sure to backup the `keys/operator/$MONIKER.backup` file, it is the only way to recover the wallet.

Run `docker compose run --rm create-operator-wallet`

### Register Validator

This assumes an operator wallet `keys/operator/$MONIKER.info` is present, and the `priv_validator_key.json` is present in the `keys/consensus/` folder.

`docker compose run --rm register-validator`

### CLI

An image with the `celestia-appd` binary is also avilable, e.g:

`docker compose run --rm cli tendermint show-validator`

### Bottleneck Bandwidth and Round-trip propagation time

Starting on v3.0.0, it is required to enable BBR and MCTCP on the host machine.

To enable BBR:

```
./enable-bbr.sh
```

Then verify BBR is enabled:

```
sysctl net.ipv4.tcp_congestion_control
```

For *testing* purposes, it can be bypassed by adding the following flag to `CELESTIA_APP_EXTRA_FLAGS` in the `.env` file:

`--force-no-bbr`

## celestia-node

### Import node-key

Run `docker compose run --rm import-celestia-node-key`

It is meant to be executed only once, it has no sanity checks and creates the `$MONIKER.info`, `$xyz.address` and `$MONIKER.backup` files inside the `keys/celestia-node/` folder.

Remember to backup those files if you're running a validator.

## Version

Celestia Docker uses a semver scheme.

This is celestia-docker v1.0.0
