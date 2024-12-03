#!/usr/bin/env bash
set -euo pipefail

__p2p_network_flag=$(echo "$NETWORK" | grep -Eo 'mocha|arabica' | sed 's/^/--p2p.network /' || echo "")

if [[ ! -f /data/.initialized ]]; then
  echo "Initializing!"
  celestia $CELESTIA_NODE_TYPE init $__p2p_network_flag --node.store /data
  touch /data/.initialized
else
  echo "Already initialized!"
fi

# Update the P2P port.
sed -i "/^\[P2P\]/,/^$/ { /ListenAddresses\|NoAnnounceAddresses/ s/\/\(udp\|tcp\)\/[0-9]\{1,5\}/\/\1\/${P2P_PORT}/g }" /data/config.toml

exec "$@" ${__p2p_network_flag} ${EXTRAS}
