#!/usr/bin/env bash
# Compila a gramática tree-sitter-dart (fontes C) em biblioteca compartilhada
# para uso pelo validador de sintaxe.
set -euo pipefail

SRC_DIR="${1:-/tmp/tsdart/tree-sitter-dart-master/src}"
OUT="${2:-/tmp/tsdart/libtree-sitter-dart.so}"

cc -O2 -fPIC -shared -I"$SRC_DIR" \
  "$SRC_DIR/parser.c" "$SRC_DIR/scanner.c" \
  -o "$OUT"

echo "gerado: $OUT"
