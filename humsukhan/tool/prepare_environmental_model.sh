#!/usr/bin/env bash
set -euo pipefail

MODEL_DIR="assets/environmental"
MODEL="$MODEL_DIR/model.int8.onnx"
LABELS="$MODEL_DIR/class_labels_indices.csv"
MODEL_URL="https://huggingface.co/k2-fsa/sherpa-onnx-ced-tiny-audio-tagging-2024-04-19/resolve/main/model.int8.onnx"
LABELS_URL="https://huggingface.co/k2-fsa/sherpa-onnx-ced-tiny-audio-tagging-2024-04-19/resolve/main/class_labels_indices.csv"
EXPECTED_MODEL_SHA256="73aa22e783115f6a4ae169b36089907e07d0fd44795595eddea9c1bfc74cc945"

mkdir -p "$MODEL_DIR"

curl --fail --location --retry 3 --retry-all-errors --silent --show-error \
  "$MODEL_URL" -o "$MODEL"
curl --fail --location --retry 3 --retry-all-errors --silent --show-error \
  "$LABELS_URL" -o "$LABELS"

MODEL_SHA256="$(sha256sum "$MODEL" | cut -d' ' -f1)"
test "$MODEL_SHA256" = "$EXPECTED_MODEL_SHA256" || {
  echo "ERROR: environmental model checksum mismatch: $MODEL_SHA256"
  exit 1
}

test -s "$LABELS" || {
  echo 'ERROR: environmental model labels file is empty.'
  exit 1
}

echo "Prepared bundled environmental model ($MODEL_SHA256)."
