#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
MODEL_PACKAGE="${PROJECT_ROOT}/SaT.mlpackage"
MODEL_FILE="${MODEL_PACKAGE}/Data/com.apple.CoreML/SaT.mlmodel"
COMPILED_MODEL_DIR="${PROJECT_ROOT}/SaT.mlmodelc"
RESOURCES_DIR="${PROJECT_ROOT}/../Sources/SegmentTextKit/Resources"
RESOURCE_MODEL_DIR="${RESOURCES_DIR}/SaT.mlmodelc"
TOKENIZER_URL="https://huggingface.co/facebookAI/xlm-roberta-base/resolve/main/sentencepiece.bpe.model"
TOKENIZER_PATH="${RESOURCES_DIR}/sentencepiece.bpe.model"

rm -fr "${COMPILED_MODEL_DIR}"

xcrun coremlcompiler compile "${MODEL_FILE}" "${PROJECT_ROOT}"

mkdir -p "${RESOURCES_DIR}"
rm -fr "${RESOURCE_MODEL_DIR}"
cp -R "${COMPILED_MODEL_DIR}" "${RESOURCE_MODEL_DIR}"

if [ ! -f "${TOKENIZER_PATH}" ]; then
  tmpfile="$(mktemp)"
  curl -L --fail --silent --show-error "${TOKENIZER_URL}" -o "${tmpfile}"
  mv "${tmpfile}" "${TOKENIZER_PATH}"
fi
