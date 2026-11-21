#!/usr/bin/env bash
# Roda a bateria de testes do projeto.
#
# Uso:
#   ./tools/run_tests.sh            # todos os testes
#   ./tools/run_tests.sh app/test/v3_test.dart
#
# Requer o SDK do Flutter instalado e as dependencias resolvidas
# (`cd app && flutter pub get`).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/app" || exit 1

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter nao encontrado no PATH." >&2
  echo "Instale o Flutter e rode 'flutter pub get' dentro de app/." >&2
  exit 127
fi

if [ "$#" -gt 0 ]; then
  exec flutter test --reporter expanded "$@"
fi

exec flutter test --reporter expanded
