#!/usr/bin/env bash

echo "------------------------------------------------"
echo "------------------------------------------------"
env 
echo "------------------------------------------------"
echo "------------------------------------------------"

set -eu
set -o pipefail

if [[ "${VERBOSE:-0}" -eq 1 ]]; then
  set -x 
fi

SUDO="$(which sudo 2>/dev/null)"

# if the user env var is unset and 
if [[ -z "${USER:-}" ]] && [[ "$EUID" -eq 0 ]]; then
    USER="root"
fi

# Create user-writeable /nix
if [[ $OSTYPE =~ darwin ]]; then
  sys="x86_64-darwin"
  $SUDO $SHELL -euo pipefail << EOF
  echo nix >> /etc/synthetic.conf
  echo -e "run\\tprivate/var/run" >> /etc/synthetic.conf
  /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -B || true
  diskutil apfs addVolume disk1 APFS nix -mountpoint /nix
  mdutil -i off /nix
  chown $USER /nix
EOF
else
  sys="x86_64-linux"
  $SUDO install -d -o "$USER" /nix
  if [[ "$NIX_ON_TMPFS" == "true" || "$NIX_ON_TMPFS" == "True" || "$NIX_ON_TMPFS" == "TRUE" ]]; then
    $SUDO mount -t tmpfs -o size=90%,mode=0755,gid="$(id -g)",uid="$(id -u)" tmpfs /nix
  fi
fi

# Fetch and unpack nix
rel="$(head -n1 "$RELEASE_FILE")"
url="${NIX_ARCHIVES_URL:-https://github.com/nixbuild/nix-quick-install-action/releases/download/$rel}/nix-$NIX_VERSION-$sys.tar.zstd"

curl -sL --retry 3 --retry-connrefused "$url" | zstdcat | \
  tar --strip-components 1 -xC /nix

# Setup nix.conf
NIX_CONF_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/nix/nix.conf"
mkdir -p "$(dirname "$NIX_CONF_FILE")"
echo "build-users-group =" > "$NIX_CONF_FILE"
if [ -n "$NIX_CONF" ]; then
  printenv NIX_CONF >> "$NIX_CONF_FILE"
fi

# Install nix in profile
nix="$(readlink /nix/.nix)"
MANPATH= . "$nix/etc/profile.d/nix.sh"
"$nix/bin/nix-env" -i "$nix"

# Certificate bundle is not detected by nix.sh on macOS.
if [ -z "${NIX_SSL_CERT_FILE:-}" -a -e "/etc/ssl/cert.pem" ]; then
  NIX_SSL_CERT_FILE="/etc/ssl/cert.pem"
fi

# Set env
echo "$HOME/.nix-profile/bin" >> $GITHUB_PATH
echo "NIX_PROFILES=/nix/var/nix/profiles/default $HOME/.nix-profile" >> $GITHUB_ENV
echo "NIX_USER_PROFILE_DIR=/nix/var/nix/profiles/per-user/$USER" >> $GITHUB_ENV
echo "NIX_SSL_CERT_FILE=$NIX_SSL_CERT_FILE" >> $GITHUB_ENV
