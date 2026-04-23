#!/usr/bin/env python3

from pathlib import Path
import sys


FLUID_AUDIO_ROOT = Path("SourcePackages/checkouts/FluidAudio")
LEGACY_TARGET_RELATIVE_PATH = Path(
    "SourcePackages/checkouts/FluidAudio/Sources/FluidAudio/ASR/AsrManager.swift"
)
OLD_DECLARATION = "public final class AsrManager {"
NEW_DECLARATION = "public final class AsrManager: @unchecked Sendable {"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: patch_fluidaudio_sendability.py <derived-data-path>", file=sys.stderr)
        return 1

    derived_data_path = Path(sys.argv[1]).expanduser().resolve()
    target_path = derived_data_path / LEGACY_TARGET_RELATIVE_PATH
    if not target_path.exists():
        fluid_audio_root = derived_data_path / FLUID_AUDIO_ROOT
        candidates = sorted(fluid_audio_root.rglob("AsrManager.swift")) if fluid_audio_root.exists() else []
        if not candidates:
            print(
                f"FluidAudio source file not found at {target_path} or under {fluid_audio_root}",
                file=sys.stderr,
            )
            return 1
        target_path = candidates[0]

    contents = target_path.read_text()

    if NEW_DECLARATION in contents:
        print(f"FluidAudio sendability patch already applied at {target_path}")
        return 0

    if "public actor AsrManager" in contents:
        print(f"FluidAudio uses actor-based AsrManager at {target_path}; patch not required")
        return 0

    if OLD_DECLARATION not in contents:
        print(
            "Unable to locate expected AsrManager declaration in "
            f"{target_path}. Upstream FluidAudio may have changed.",
            file=sys.stderr,
        )
        return 1

    target_path.chmod(0o644)
    target_path.write_text(contents.replace(OLD_DECLARATION, NEW_DECLARATION, 1))
    print(f"Applied FluidAudio sendability patch at {target_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
