#!/bin/bash
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

apt update && apt install curl gpg -y

curl -fsSL "https://packages.buildkite.com/crazy/gdiff/gpgkey" \
  | gpg --dearmor -o /etc/apt/keyrings/crazy_gdiff-archive-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/crazy_gdiff-archive-keyring.gpg] \
https://packages.buildkite.com/crazy/gdiff/any/ any main" \
  > /etc/apt/sources.list.d/buildkite-crazy-gdiff.list

apt update && apt install gdiff -y