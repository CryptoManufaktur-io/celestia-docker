#!/usr/bin/env bash
set -euo pipefail


__p2p_network_flag=$(echo "$NETWORK" | grep -Eo 'mocha|arabica' | sed 's/^/--p2p.network /' || echo "")

if [[ ! -f /data/.initialized ]]; then
  echo "Initializing!"
  celestia $CELESTIA_NODE_TYPE init --core.ip ${CELESTIA_NODE_GRPC_IP} --core.port ${CELESTIA_NODE_GRPC_PORT} --node.store /data $__p2p_network_flag
  touch /data/.initialized
else
  echo "Already initialized!"
fi

exec "$@" ${__p2p_network_flag} ${EXTRAS}
