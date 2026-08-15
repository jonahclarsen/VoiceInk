#!/usr/bin/env python3

from pathlib import Path
import subprocess
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: get_local_app_path.py <derived-data-path>", file=sys.stderr)
        return 1

    derived_data_path = str(Path(sys.argv[1]).expanduser().resolve())
    entitlements_path = str(
        (Path(__file__).resolve().parents[1] / "VoiceInk" / "VoiceInk.local.entitlements").resolve()
    )

    command = [
        "xcodebuild",
        "-project",
        "VoiceInk.xcodeproj",
        "-scheme",
        "VoiceInk",
        "-configuration",
        "Debug",
        "-derivedDataPath",
        derived_data_path,
        "-skipPackagePluginValidation",
        "-skipMacroValidation",
        "-xcconfig",
        "LocalBuild.xcconfig",
        "CODE_SIGN_IDENTITY=-",
        "CODE_SIGNING_REQUIRED=NO",
        "CODE_SIGNING_ALLOWED=YES",
        "DEVELOPMENT_TEAM=",
        f"CODE_SIGN_ENTITLEMENTS={entitlements_path}",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) LOCAL_BUILD",
        "-showBuildSettings",
    ]

    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr, end="")
        return result.returncode

    for line in result.stdout.splitlines():
        if "CONFIGURATION_BUILD_DIR =" in line:
            build_dir = line.split("=", 1)[1].strip()
            print(str(Path(build_dir) / "VoiceInk.app"))
            return 0

    print("CONFIGURATION_BUILD_DIR not found in xcodebuild output", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
