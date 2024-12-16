#!/usr/bin/env bash
set -euo pipefail

# Define directories
HOME_DIR="${PROJECT_HOME}"
CONFIG_DIR="$HOME_DIR/config"
DATA_DIR="$HOME_DIR/data"

# Check if data directory exists to determine if this is a new node
if [ -d "$DATA_DIR" ] && [ -n "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
    echo "Existing node data found. Starting node..."
else
    echo "No existing data found. Initializing new node..."

    # Initialize the node
    echo "Running init..."
    ${PROJECT_BIN} init "$MONIKER" --chain-id "$NETWORK" --home "$HOME_DIR" --overwrite

    # Download the genesis file
    echo "Downloading genesis file..."
    ${PROJECT_BIN} download-genesis "$NETWORK" --home "$HOME_DIR"

    echo "Node initialization complete."
fi

echo "Updating config..."

# Fetch seeds and configure the node
if [ -n "${CUSTOM_SEEDS:-}" ]; then
  echo "Using custom seed addresses from environment: $CUSTOM_SEEDS"
  SEEDS="$CUSTOM_SEEDS"
elif [ -n "${SEEDS_URL:-}" ]; then
  # Fetch seeds from the provided URL
  echo "Fetching seeds from URL: $SEEDS_URL"
  SEEDS=$(curl -sL "$SEEDS_URL")
  SEEDS=$(echo "$SEEDS" | while read -r line; do
    printf "%s," "$line"
  done)
  SEEDS=${SEEDS%,}  # Remove the trailing comma
  echo "Fetched seeds: $SEEDS"
else
  echo "No custom seeds or URL provided. Skipping seed configuration."
  SEEDS=""
fi
if [ -n "$SEEDS" ]; then
  echo "Got seeds: $SEEDS"
  dasel put -f "$CONFIG_DIR/config.toml" -v "$SEEDS" p2p.seeds
else
  echo "No seeds to configure in config.toml."
fi

# Optionally configure persistent peers
if [ -n "$CUSTOM_PEERS" ]; then
    echo "Configuring persistent peers..."
    dasel put -f "$CONFIG_DIR/config.toml" -v "$CUSTOM_PEERS" p2p.persistent_peers
fi

# Optionally configure indexer, else default to kv
if [ -n "$INDEXER" ]; then
    dasel put -f "$CONFIG_DIR/config.toml" -v "$INDEXER" tx_index.indexer
fi

# Optionally download snapshot
if [ -n "$SNAPSHOT" ]; then
    echo "Downloading snapshot..."
    curl -o - -L "$SNAPSHOT" | lz4 -c -d - | tar --exclude='data/priv_validator_state.json' -x -C "$HOME_DIR"
else
    echo "No snapshot URL defined."
fi

# Optionally configure rapid state sync if applicable
if [ -n "$RAPID_SYNC_URL" ]; then
    echo "Configuring rapid state sync..."
    LATEST=$(curl -s "$RAPID_SYNC_URL/block" | jq -r '.result.block.header.height')
    SNAPSHOT_HEIGHT=$((LATEST - 2000))
    SNAPSHOT_HASH=$(curl -s "$RAPID_SYNC_URL/block?height=$SNAPSHOT_HEIGHT" | jq -r '.result.block_id.hash')

    dasel put -f "$CONFIG_DIR/config.toml" -v "true" statesync.enable
    dasel put -f "$CONFIG_DIR/config.toml" -v "$RAPID_SYNC_URL,$RAPID_SYNC_URL" statesync.rpc_servers
    dasel put -f "$CONFIG_DIR/config.toml" -v "$SNAPSHOT_HEIGHT" statesync.trust_height
    dasel put -f "$CONFIG_DIR/config.toml" -v "$SNAPSHOT_HASH" statesync.trust_hash
else
    echo "No rapid sync URL defined."
fi

# Optionally configure pruning if APP_PRUNING is set
if [[ -n "$APP_PRUNING" ]]; then
    dasel put -f "$CONFIG_DIR/app.toml" -v "$APP_PRUNING" pruning

    if [[ "$CPP_PRUNING" == "custom" ]]; then
        if [[ -n "$APP_PRUNING_KEEP_RECENT" ]]; then
            dasel put -f "$CONFIG_DIR/app.toml" -v "$APP_PRUNING_KEEP_RECENT" pruning-keep-recent
        fi

        if [[ -n "$APP_PRUNING_INTERVAL" ]]; then
            dasel put -f "$CONFIG_DIR/app.toml" -v "$APP_PRUNING_INTERVAL" pruning-interval
        fi
    fi
fi

# Optionally configure minimum-gas-prices if MIN_GAS_PRICES is set
if [[ -n "$MIN_GAS_PRICES" ]]; then
    dasel put -f "$CONFIG_DIR/app.toml" -v "$MIN_GAS_PRICES" minimum-gas-prices
fi

# Update config.toml with runtime variables
dasel put -f "$CONFIG_DIR/config.toml" -v "tcp://0.0.0.0:$CL_P2P_PORT" p2p.laddr
dasel put -f "$CONFIG_DIR/config.toml" -v "tcp://0.0.0.0:$CL_RPC_PORT" rpc.laddr
dasel put -f "$CONFIG_DIR/config.toml" -v "$MONIKER" moniker
dasel put -f "$CONFIG_DIR/config.toml" -v "true" instrumentation.prometheus
dasel put -f "$CONFIG_DIR/config.toml" -v "$LOG_LEVEL" log_level

dasel put -f "$CONFIG_DIR/config.toml" -v "10485760" recv_rate
dasel put -f "$CONFIG_DIR/config.toml" -v "10485760" send_rate
dasel put -f "$CONFIG_DIR/config.toml" -v "12" mempool.ttl-num-blocks

# Update app.toml file
dasel put -f "$CONFIG_DIR/app.toml" -v "false" api.enable # Disable API, not serving rpc node
dasel put -f "$CONFIG_DIR/app.toml" -v "false" rosetta.enable # Disable Rosetta, not serving rpc node
dasel put -f "$CONFIG_DIR/app.toml" -v "true" grpc.enable
dasel put -f "$CONFIG_DIR/app.toml" -v "0.0.0.0:$CL_GRPC_PORT" grpc.address
dasel put -f "$CONFIG_DIR/app.toml" -v "0" state-sync.snapshot-interval # Disable snapshotting

# Update client.toml file
dasel put -f "$CONFIG_DIR/client.toml" -v "tcp://localhost:$CL_RPC_PORT" node

# Start the celestia-appd process
COMMAND="${PROJECT_BIN} start --home $HOME_DIR --log_format json $@ ${EXTRA_FLAGS}"
echo "Starting celestia-appd with command: $COMMAND"
exec $COMMAND
