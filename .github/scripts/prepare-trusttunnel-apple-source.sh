#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

bash .github/scripts/checkout-trusttunnel-client.sh

source_dir="${TRUSTTUNNEL_CLIENT_SOURCE_DIR:-$repo_root/.deps/TrustTunnelClient}"

python3 -m venv "$repo_root/.deps/python-venv"
# shellcheck disable=SC1091
source "$repo_root/.deps/python-venv/bin/activate"
python -m pip install --upgrade pip
python -m pip install "conan>=2,<3" "cmake>=3.24" ninja
python_scripts_dir="$(python -c 'import sysconfig; print(sysconfig.get_path("scripts"))')"
export PATH="$python_scripts_dir:$PATH"
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$python_scripts_dir" >> "$GITHUB_PATH"
fi

conan profile detect --force

python "$source_dir/scripts/bootstrap_conan_deps.py"

rust_toolchain="$(cd "$source_dir" && rustup show active-toolchain | awk '{print $1}')"
rustup target add --toolchain "$rust_toolchain" \
  aarch64-apple-darwin \
  x86_64-apple-darwin \
  aarch64-apple-ios \
  aarch64-apple-ios-sim \
  x86_64-apple-ios

cd "$source_dir/platform/apple"
./build_framework.sh

apple_pod_dir="$repo_root/specs"
trusttunnel_framework="$(find "$source_dir/platform/apple" -type d -name TrustTunnelClient.xcframework -print -quit)"
vpn_framework="$(find "$source_dir/platform/apple" -type d -name VpnClientFramework.xcframework -print -quit)"
test -n "$trusttunnel_framework" || { echo "TrustTunnelClient.xcframework was not produced"; exit 1; }
test -n "$vpn_framework" || { echo "VpnClientFramework.xcframework was not produced"; exit 1; }

rm -rf \
  "$apple_pod_dir/TrustTunnelClient.xcframework" \
  "$apple_pod_dir/VpnClientFramework.xcframework"
cp -R \
  "$trusttunnel_framework" \
  "$apple_pod_dir/TrustTunnelClient.xcframework"
cp -R \
  "$vpn_framework" \
  "$apple_pod_dir/VpnClientFramework.xcframework"

if [ -n "${GITHUB_ENV:-}" ]; then
  echo "TRUSTTUNNEL_CLIENT_APPLE_PATH=$apple_pod_dir" >> "$GITHUB_ENV"
fi

echo "TrustTunnelClient Apple pod path: $apple_pod_dir"
