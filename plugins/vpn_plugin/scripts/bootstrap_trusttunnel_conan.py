#!/usr/bin/env python3
"""Export TrustTunnel's private Conan recipe dependencies into the local cache."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

NLC_URL = "https://github.com/AdguardTeam/NativeLibsCommon.git"
DNS_LIBS_URL = "https://github.com/AdguardTeam/DnsLibs.git"


def revision_for_version(version: str) -> str:
    described = re.search(r"-g([0-9a-f]+)$", version)
    if described:
        return described.group(1)
    return "v" + version


def collect_versions(conanfile: Path) -> tuple[str | None, list[str]]:
    dns_version = None
    nlc_versions: list[str] = []
    for line in conanfile.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if "@adguard/oss" not in line:
            continue
        if line.startswith('self.requires("dns-libs/'):
            dns_version = line.split("@", 1)[0].split("/", 1)[1]
        elif line.startswith('self.requires("native_libs_common/'):
            nlc_versions.append(line.split("@", 1)[0].split("/", 1)[1])
    return dns_version, nlc_versions


def run(command: list[str], cwd: Path | None = None, env: dict[str, str] | None = None) -> None:
    print("+ " + " ".join(command), flush=True)
    subprocess.run(command, cwd=str(cwd) if cwd else None, env=env, check=True)


def find_windows_bash() -> str:
    candidates = [
        os.environ.get("GIT_BASH"),
        str(Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "Git" / "bin" / "bash.exe"),
        str(Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "Git" / "usr" / "bin" / "bash.exe"),
        str(Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")) / "Git" / "bin" / "bash.exe"),
        shutil.which("bash"),
    ]
    for candidate in candidates:
        if not candidate:
            continue
        path = Path(candidate)
        if path.exists() and "Windows/System32" not in path.as_posix():
            return str(path)
    raise RuntimeError("Git Bash is required to export TrustTunnel Conan recipes on Windows")


def find_conan_dir() -> str | None:
    conan = shutil.which("conan")
    if conan:
        return str(Path(conan).parent)

    candidates: list[Path] = []
    for root in (
        Path(os.environ.get("APPDATA", "")) / "Python",
        Path(os.environ.get("LOCALAPPDATA", "")) / "Python",
    ):
        if root.exists():
            candidates.extend(root.glob("*/Scripts/conan.exe"))

    if candidates:
        return str(candidates[0].parent)
    return None


def clone_and_checkout(url: str, path: Path, version: str) -> None:
    run(["git", "clone", url, str(path)])
    run(["git", "-C", str(path), "checkout", revision_for_version(version)])


def export_conan(repo: Path) -> None:
    script = repo / "scripts" / "export_conan.sh"
    if os.name == "nt":
        env = os.environ.copy()
        conan_dir = find_conan_dir()
        if conan_dir:
            env["PATH"] = conan_dir + os.pathsep + env.get("PATH", "")
        run([find_windows_bash(), str(script)], cwd=repo, env=env)
    else:
        run([str(script)], cwd=repo)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: bootstrap_trusttunnel_conan.py <TrustTunnelClient source dir>", file=sys.stderr)
        return 2

    trusttunnel_source = Path(sys.argv[1]).resolve()
    conanfile = trusttunnel_source / "conanfile.py"
    if not conanfile.exists():
        print(f"TrustTunnel conanfile.py was not found at {conanfile}", file=sys.stderr)
        return 2

    dns_version, nlc_versions = collect_versions(conanfile)
    if not dns_version:
        print("dns-libs dependency was not found in TrustTunnel conanfile.py", file=sys.stderr)
        return 2

    temp_parent = trusttunnel_source.parent
    temp_dir = Path(tempfile.mkdtemp(
        prefix="trusttunnel-conan-bootstrap-",
        dir=str(temp_parent),
    ))
    try:
        dns_dir = temp_dir / "dns-libs"
        clone_and_checkout(DNS_LIBS_URL, dns_dir, dns_version)
        _, dns_nlc_versions = collect_versions(dns_dir / "conanfile.py")
        nlc_versions.extend(dns_nlc_versions)
        export_conan(dns_dir)

        nlc_dir = temp_dir / "native-libs-common"
        run(["git", "clone", NLC_URL, str(nlc_dir)])
        seen: set[str] = set()
        for version in nlc_versions:
            if version in seen:
                continue
            seen.add(version)
            run(["git", "-C", str(nlc_dir), "checkout", revision_for_version(version)])
            export_conan(nlc_dir)
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
