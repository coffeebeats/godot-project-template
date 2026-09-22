"""Reduce Aseprite's JSON export to the manifest 'tools/aseprite.sh' writes by a sheet.

Aseprite's own data carries 'meta.image', an absolute path, and 'meta.version', the
installed binary, so both churn per machine and per upgrade. Only the sheet size, each
frame's duration and the tags survive.

Usage: aseprite_manifest.py RAW SOURCE
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# TAG_KEYS are the tag fields every tag carries, in the order the manifest writes them.
# 'repeat' follows them, and only where Aseprite wrote it: a tag that plays once has no
# such field, and inventing one would change what the importer reads.
TAG_KEYS = ("name", "from", "to", "direction")


def manifest(data: dict, source: str) -> dict:
    """manifest returns the reduced form of one Aseprite export."""
    frames = data["frames"]
    size = data["meta"]["size"]

    tags = []
    for tag in data["meta"].get("frameTags", []):
        kept = {key: tag[key] for key in TAG_KEYS}
        if "repeat" in tag:
            kept["repeat"] = tag["repeat"]

        tags.append(kept)

    return {
        "source": source,
        "size": [size["w"], size["h"]],
        "frame_size": [frames[0]["sourceSize"]["w"], frames[0]["sourceSize"]["h"]],
        "frames": [{"duration": frame["duration"]} for frame in frames],
        "tags": tags,
    }


def main() -> None:
    """main prints the manifest for the raw export named on the command line."""
    if len(sys.argv) != 3:
        sys.exit("usage: aseprite_manifest.py RAW SOURCE")

    raw, source = sys.argv[1], sys.argv[2]
    data = json.loads(Path(raw).read_text(encoding="utf-8"))

    # 'ensure_ascii' stays off so a tag named outside ASCII reads as itself, and the
    # bytes are written as UTF-8 rather than through the console encoding, which on
    # Windows would mangle that same tag.
    text = json.dumps(manifest(data, source), indent=2, ensure_ascii=False)
    sys.stdout.buffer.write(f"{text}\n".encode())


if __name__ == "__main__":
    main()
