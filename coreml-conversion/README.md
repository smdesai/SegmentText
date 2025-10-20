# CoreML Conversion

## Environment Setup

1. Install [uv](https://github.com/astral-sh/uv) if it is not already available.
2. Sync the project environment (creates `.venv/` from `uv.lock` and `pyproject.toml`):
   ```bash
   uv sync
   ```
3. Activate the virtual environment:
   ```bash
   source .venv/bin/activate
   ```

## Converting the Model

Run the conversion script to export the SaT Core ML package:

```bash
python convert.py
```

This produces `SaT.mlpackage` in the repository root.

## Compiling for Xcode

Compile the package and place the artifacts in `../Sources/SegmentTextKit/Resources`:

```bash
./compile.sh
```

`compile.sh` performs the following steps:

- Compiles `SaT.mlpackage` into `SaT.mlmodelc` using `coremlcompiler`.
- Copies `SaT.mlmodelc` into `../Sources/SegmentTextKit/Resources`.
- Downloads `sentencepiece.bpe.model` from the XLM-RoBERTa checkpoint (if not already present) into the same resources directory.

Ensure `xcrun` is available (part of Xcode command-line tools) before running the script.
