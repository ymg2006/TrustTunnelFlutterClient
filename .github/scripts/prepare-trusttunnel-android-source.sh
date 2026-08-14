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
  aarch64-linux-android \
  armv7-linux-androideabi \
  i686-linux-android \
  x86_64-linux-android
cargo +"$rust_toolchain" install cargo-ndk --locked

python - <<'PY'
import re
from pathlib import Path

android_root = Path(".deps/TrustTunnelClient/platform/android")
for path in android_root.rglob("*"):
    if path.suffix not in {".gradle", ".kts", ".toml"}:
        continue
    text = path.read_text(encoding="utf-8")
    updated = text
    updated = re.sub(r'(?m)^(\s*agp\s*=\s*)"[^"]+"', r'\g<1>"8.11.1"', updated)
    updated = re.sub(
        r'(com\.android\.tools\.build:gradle:)[0-9][^"\'\s)]*',
        r'\g<1>8.11.1',
        updated,
    )
    updated = re.sub(
        r'((?:com\.android\.application|com\.android\.library)["\']?\s+version\s+)["\'][^"\']+["\']',
        r'\g<1>"8.11.1"',
        updated,
    )
    if updated != text:
        path.write_text(updated, encoding="utf-8")
        print(f"Normalized Android Gradle plugin version in {path}")
PY

cmake_bin="$(command -v cmake || true)"
if [ -n "$cmake_bin" ]; then
  cmake_root="$(dirname "$(dirname "$cmake_bin")")"
  echo "cmake.dir=$cmake_root" > "$source_dir/platform/android/local.properties"
fi

cat > android/libs.gradle <<EOF
// Generated in CI to build TrustTunnelClient Android from source instead of GitHub Packages.
includeBuild('../.deps/TrustTunnelClient/platform/android') {
    dependencySubstitution {
        substitute module('com.adguard.trusttunnel:trusttunnel-client-android') using project(':lib')
    }
}
EOF

cat android/libs.gradle
