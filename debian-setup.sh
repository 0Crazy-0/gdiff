#!/bin/bash
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

apt update && apt install curl gpg -y

# gdiff apt repository (hosted on GitHub Pages, signed with GPG)
mkdir -p /etc/apt/keyrings
curl -fsSL "https://0crazy-0.github.io/gdiff/apt/KEY.gpg" \
  | gpg --dearmor -o /etc/apt/keyrings/gdiff-archive-keyring.gpg
sync

echo "deb [signed-by=/etc/apt/keyrings/gdiff-archive-keyring.gpg] \
https://0crazy-0.github.io/gdiff/apt stable main" \
  > /etc/apt/sources.list.d/gdiff.list

apt update && apt install gdiff -y
