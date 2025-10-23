#!/usr/bin/env python3
"""Download tokenizer resources needed for SegmentTextKit."""

from __future__ import annotations

import pathlib
import shutil
import sys
import tempfile
import urllib.error
import urllib.request


TOKENIZER_URL = "https://huggingface.co/facebookAI/xlm-roberta-base/resolve/main/sentencepiece.bpe.model"


def main() -> int:
    script_dir = pathlib.Path(__file__).resolve().parent
    project_root = script_dir
    resources_dir = project_root / ".." / "Sources" / "SegmentTextKit" / "Resources"
    tokenizer_path = resources_dir / "sentencepiece.bpe.model"

    if tokenizer_path.exists():
        return 0

    resources_dir.mkdir(parents=True, exist_ok=True)

    tmp_path: pathlib.Path | None = None
    try:
        with tempfile.NamedTemporaryFile(delete=False) as tmp_file:
            tmp_path = pathlib.Path(tmp_file.name)
            with urllib.request.urlopen(TOKENIZER_URL) as response:
                if response.status >= 400:
                    raise urllib.error.HTTPError(
                        TOKENIZER_URL, response.status, response.reason, response.headers, None
                    )
                shutil.copyfileobj(response, tmp_file)

        tmp_path.replace(tokenizer_path)
    except (urllib.error.URLError, OSError) as exc:
        print(f"Failed to download tokenizer: {exc}", file=sys.stderr)
        return 1
    finally:
        if tmp_path and tmp_path.exists():
            tmp_path.unlink()

    return 0


if __name__ == "__main__":
    sys.exit(main())
