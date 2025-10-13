#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f /cosmos/.initialized ]]; then
  echo "Initializing!"

  echo "Running init..."
  celestia-appd init $MONIKER --chain-id $NETWORK --home /cosmos --overwrite

  echo "Downloading config..."
  SEEDS=$(curl -sL https://raw.githubusercontent.com/celestiaorg/networks/master/$NETWORK/seeds.txt | tr '\n' ',')

  celestia-appd download-genesis $NETWORK --home /cosmos
  dasel put -f /cosmos/config/config.toml -v $SEEDS p2p.seeds
  dasel put -f /cosmos/config/config.toml -v "null" indexer

  if [ -n "$SNAPSHOT" ]; then
    echo "Downloading snapshot..."
    # Try aria2c first for faster multi-connection downloads (3-10x faster)
    if command -v aria2c &> /dev/null; then
      echo "Using aria2c for faster download (multi-connection)..."
      aria2c -x 16 -s 16 -k 1M --file-allocation=none --allow-overwrite=true -d /tmp -o snapshot.tar.lz4 "$SNAPSHOT" && \
        lz4 -c -d /tmp/snapshot.tar.lz4 | tar --exclude='data/priv_validator_state.json' -x -C /cosmos && \
        rm -f /tmp/snapshot.tar.lz4
    else
      # Fallback to curl if aria2c is not available
      echo "aria2c not found, falling back to curl..."
      curl -o - -L $SNAPSHOT | lz4 -c -d - | tar --exclude='data/priv_validator_state.json' -x -C /cosmos
    fi
  else
    echo "No snapshot URL defined."
  fi

  # Check whether we should rapid sync
  if [ -n "${RAPID_SYNC_URL}" ]; then
    echo "Configuring rapid state sync"
    # Get the latest height
    LATEST=$(curl -s "${RAPID_SYNC_URL}/block" | jq -r '.result.block.header.height')
    echo "LATEST=$LATEST"

    # Calculate the snapshot height
    SNAPSHOT_HEIGHT=$((LATEST - 2000));
    echo "SNAPSHOT_HEIGHT=$SNAPSHOT_HEIGHT"

    # Get the snapshot hash
    SNAPSHOT_HASH=$(curl -s $RAPID_SYNC_URL/block\?height\=$SNAPSHOT_HEIGHT | jq -r '.result.block_id.hash')
    echo "SNAPSHOT_HASH=$SNAPSHOT_HASH"

    dasel put -f /cosmos/config/config.toml -v true statesync.enable
    dasel put -f /cosmos/config/config.toml -v "${RAPID_SYNC_URL},${RAPID_SYNC_URL}" statesync.rpc_servers
    dasel put -f /cosmos/config/config.toml -v $SNAPSHOT_HEIGHT statesync.trust_height
    dasel put -f /cosmos/config/config.toml -v $SNAPSHOT_HASH statesync.trust_hash
  else
    echo "No rapid sync url defined."
  fi

  touch /cosmos/.initialized
else
  echo "Already initialized!"
fi

echo "Updating config..."

# Get public IP address.
__public_ip=$(curl -s ifconfig.me/ip)
echo "Public ip: ${__public_ip}"

# Always update public IP address, moniker and ports.
dasel put -f /cosmos/config/config.toml -v "${__public_ip}:${CL_P2P_PORT}" p2p.external_address
dasel put -f /cosmos/config/config.toml -v "tcp://0.0.0.0:${CL_P2P_PORT}" p2p.laddr
dasel put -f /cosmos/config/config.toml -v 10485760 p2p.recv_rate
dasel put -f /cosmos/config/config.toml -v 10485760 p2p.send_rate
dasel put -f /cosmos/config/config.toml -v "tcp://0.0.0.0:${CL_RPC_PORT}" rpc.laddr
dasel put -f /cosmos/config/config.toml -v "tcp://0.0.0.0:9098" rpc.grpc_laddr
dasel put -f /cosmos/config/config.toml -v ${MONIKER} moniker
dasel put -f /cosmos/config/config.toml -v true prometheus
dasel put -f /cosmos/config/config.toml -v ${LOG_LEVEL} log_level
dasel put -f /cosmos/config/config.toml -v 12 mempool.ttl-num-blocks
dasel put -f /cosmos/config/app.toml -v "0.0.0.0:${RPC_PORT}" json-rpc.address
dasel put -f /cosmos/config/app.toml -v "0.0.0.0:${WS_PORT}" json-rpc.ws-address
dasel put -f /cosmos/config/app.toml -v "0.0.0.0:${CL_GRPC_PORT}" grpc.address
dasel put -f /cosmos/config/app.toml -v true grpc.enable
dasel put -f /cosmos/config/app.toml -v $MIN_RETAIN_BLOCKS min-retain-blocks
dasel put -f /cosmos/config/app.toml -v $PRUNING pruning
dasel put -f /cosmos/config/client.toml -v "tcp://localhost:${CL_RPC_PORT}" node
dasel put -f /cosmos/config/app.toml -v "tcp://0.0.0.0:${CL_REST_PORT}" api.address

# Word splitting is desired for the command line parameters
# shellcheck disable=SC2086
exec "$@" ${EXTRA_FLAGS}
