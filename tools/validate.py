#!/usr/bin/env python3
"""Import, parse every script, run both suites, then smoke-test the main scene."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r"SCRIPT ERROR:|(?:^|\n)ERROR:|(?:^|\n)FAIL:|ObjectDB instances were leaked")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args()
    binary = shutil.which(args.godot)
    if binary is None:
        print(f"Missing Godot executable: {args.godot}", file=sys.stderr)
        return 1
    version = subprocess.check_output([binary, "--version"], text=True).strip()
    match = re.match(r"(\d+)\.(\d+)", version)
    if match is None or (int(match[1]), int(match[2])) < (4, 4):
        print("Godot 4.4 or later is required.", file=sys.stderr)
        return 1
    with tempfile.TemporaryDirectory(prefix="worm-validate-") as temporary:
        env = dict(os.environ)
        env["XDG_DATA_HOME"] = str(Path(temporary) / "data")
        env["XDG_CONFIG_HOME"] = str(Path(temporary) / "config")
        common = [binary, "--headless", "--path", str(ROOT)]
        commands = [
            ("Import assets", common + ["--editor", "--import"]),
            *[(f"Parse {p.relative_to(ROOT)}", common + ["--script", str(p), "--check-only"])
              for p in sorted((ROOT / "scripts").rglob("*.gd"))],
            ("Gameplay integration", common + ["--script", "tests/run_tests.gd"]),
            ("Interface integration", common + ["--script", "tests/test_ui.gd"]),
            ("Main scene smoke test", common + ["--quit-after", "90"]),
        ]
        for label, command in commands:
            try:
                result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=90)
            except subprocess.TimeoutExpired:
                print(f"FAIL {label}: timed out", file=sys.stderr)
                return 1
            output = result.stdout + result.stderr
            if result.returncode or ERROR.search(output):
                print(f"FAIL {label}\n{output}", file=sys.stderr)
                return 1
            if label.startswith("Parse "):
                continue
            print(f"PASS {label}")
            for line in output.splitlines():
                if "checks," in line:
                    print("  " + line)
        print(f"Validated all GDScript files, gameplay, UI and startup with Godot {version}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
