#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Rebuild the static GS1Native XCFramework with the pinned official toolchain."""

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import urllib.request


ROOT = Path(__file__).resolve().parent
KOTLIN = "kotlin-native-prebuilt-macos-aarch64-2.4.21"
JAVA = "jdk-21.0.13+9"
PACKAGES = (
    (
        KOTLIN + ".tar.gz",
        "https://github.com/JetBrains/kotlin/releases/download/v2.4.21/",
        "bf4edb526d91e17d0862102f69250525d788e79011f86c2c64362749adf260ae",
    ),
    (
        "OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.13_9.tar.gz",
        "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13%2B9/",
        "bf036b35b071bfb2f54f2c0af8ee8d88afa95ee6eb3dce02c0f94cfc2524d04a",
    ),
)
BUILD_PATH = re.compile(rb"/(?:Users|home|Volumes|tmp|var/folders|private/var/folders|workspace)/")


def download_toolchains(toolchains):
    toolchains.mkdir(parents=True, exist_ok=True)
    for name, base_url, expected in PACKAGES:
        with tempfile.NamedTemporaryFile(dir=toolchains) as archive:
            print(f"Downloading {name}", flush=True)
            digest = hashlib.sha256()
            with urllib.request.urlopen(base_url + name, timeout=60) as source:
                while chunk := source.read(1024 * 1024):
                    archive.write(chunk)
                    digest.update(chunk)
            if digest.hexdigest() != expected:
                raise RuntimeError(f"Unexpected SHA-256 for {name}")
            archive.flush()
            subprocess.run(["tar", "-xzf", archive.name, "-C", toolchains], check=True)


def verify_paths(framework, paths):
    for file in framework.rglob("*"):
        if file.is_file():
            contents = file.read_bytes()
            if BUILD_PATH.search(contents) or any(os.fsencode(path) in contents for path in paths):
                raise RuntimeError(f"Build path found in {file.relative_to(framework)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/GS1Native.xcframework")
    parser.add_argument("--toolchains", type=Path, help="reuse the exact pinned Kotlin and JDK installations")
    parser.add_argument("--konan-data", type=Path, help="reuse a Kotlin/Native dependencies cache")
    options = parser.parse_args()
    output = options.output.resolve()
    if output.exists():
        parser.error(f"output already exists: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    toolchains = (options.toolchains or ROOT / "build/toolchains").resolve()
    konan_data = (options.konan_data or ROOT / "build/konan-data").resolve()
    compiler = toolchains / KOTLIN / "bin/kotlinc-native"
    java_home = toolchains / JAVA / "Contents/Home"
    if options.toolchains is None and not (compiler.is_file() and (java_home / "bin/java").is_file()):
        download_toolchains(toolchains)
    if not (compiler.is_file() and (java_home / "bin/java").is_file()):
        parser.error(f"pinned Kotlin and JDK installations are missing in {toolchains}")

    env = os.environ.copy()
    env["JAVA_HOME"] = str(java_home)
    env["KONAN_DATA_DIR"] = str(konan_data)
    env["JAVA_OPTS"] = "-Xmx4g"
    if "DEVELOPER_DIR" not in env and Path("/Applications/Xcode.app/Contents/Developer").is_dir():
        env["DEVELOPER_DIR"] = "/Applications/Xcode.app/Contents/Developer"

    sources = sorted(str(path.relative_to(ROOT)) for path in (ROOT / "Source").glob("*.kt"))
    scratch = ROOT / "build"
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=scratch) as tmp:
        build = Path(tmp).resolve()
        frameworks = []
        for target in ("ios_arm64", "ios_simulator_arm64"):
            prefix = build / target / "GS1Native"
            prefix.parent.mkdir()
            subprocess.run(
                [
                    compiler, *sources, "-target", target, "-produce", "framework",
                    "-Xstatic-framework", "-Xbinary=bundleId=local.gs1.nativecore",
                    f"-Xklib-relative-path-base={ROOT}", f"-Xdebug-prefix-map={ROOT}=.",
                    # Kotlin also records the output name in its debug metadata.
                    "-Xadd-light-debug=disable", "-o", prefix.relative_to(ROOT),
                ],
                cwd=ROOT,
                env=env,
                check=True,
            )
            frameworks.extend(("-framework", prefix.with_suffix(".framework")))

        artifact = build / "GS1Native.xcframework"
        subprocess.run(
            ["xcodebuild", "-create-xcframework", *frameworks, "-output", artifact],
            env=env,
            check=True,
        )
        verify_paths(artifact, (ROOT, toolchains, konan_data, build))
        shutil.move(artifact, output)
    print(f"Built {output}")


if __name__ == "__main__":
    main()
