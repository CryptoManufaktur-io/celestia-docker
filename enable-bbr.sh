#!/usr/bin/env bash

set -euo pipefail

echo "Configuring system to use BBR..."

# Check the current TCP congestion control setting
current_setting=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')

if [ "$current_setting" != "bbr" ]; then
    echo "BBR is not enabled. Configuring BBR..."

    # Load the BBR module
    sudo modprobe tcp_bbr

    # Ensure BBR module loads on boot
    echo "tcp_bbr" | sudo tee -a /etc/modules > /dev/null

    # Update sysctl settings for BBR
    echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf > /dev/null
    echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf > /dev/null

    # Apply sysctl changes
    sudo sysctl -p

    echo "BBR has been enabled."
else
    echo "BBR is already enabled."
fi