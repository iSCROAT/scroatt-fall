#!/usr/bin/env python3
"""Validador de sintaxe Dart baseado na gramática tree-sitter.

Como o SDK do Flutter não pode ser instalado neste ambiente (os hosts de
distribuição do SDK e o pub.dev estão bloqueados), compilamos a gramática
tree-sitter-dart e usamos o parser para confirmar que todo arquivo .dart é
sintaticamente válido. Isso não substitui o `flutter analyze`, mas evita
subir ao CI com erros de sintaxe.

Uso:
    python3 tools/validate_dart.py [raiz-do-projeto-flutter]
"""
from __future__ import annotations

import ctypes
import sys
from pathlib import Path

from tree_sitter import Language, Parser

LIB = Path("/tmp/tsdart/libtree-sitter-dart.so")


def load_language(path: Path) -> Language:
    """Carrega a gramática compilada via ctypes e devolve o Language."""
    lib = ctypes.cdll.LoadLibrary(str(path))
    lib.tree_sitter_dart.restype = ctypes.c_void_p
    ptr = lib.tree_sitter_dart()
    if not ptr:
        raise RuntimeError("tree_sitter_dart() retornou ponteiro nulo")
    return Language(ptr)  # type: ignore[arg-type]


def collect_errors(node, out):
    """Percorre a árvore marcando nós ERROR e nós ausentes."""
    if node.type == "ERROR" or node.is_missing:
        out.append(node)
        return
    for child in node.children:
        collect_errors(child, out)


def main() -> int:
    if not LIB.exists():
        print(f"Biblioteca da gramática não encontrada: {LIB}", file=sys.stderr)
        print("Rode: ./tools/build_dart_grammar.sh", file=sys.stderr)
        return 2

    root = Path(sys.argv[1] if len(sys.argv) > 1 else "app").resolve()
    lib_dir = root / "lib"
    if not lib_dir.is_dir():
        print(f"Diretório lib não encontrado em {root}", file=sys.stderr)
        return 2

    language = load_language(LIB)
    parser = Parser(language)

    files = sorted(lib_dir.rglob("*.dart"))
    total_errors = 0

    for file in files:
        source = file.read_bytes()
        tree = parser.parse(source)
        errors: list = []
        collect_errors(tree.root_node, errors)

        rel = file.relative_to(root)
        if not errors:
            print(f"OK   {rel}")
            continue

        total_errors += len(errors)
        print(f"ERRO {rel} — {len(errors)} problema(s)")
        lines = source.decode("utf-8", "replace").split("\n")
        for err in errors[:10]:
            row = err.start_point[0]
            col = err.start_point[1]
            snippet = lines[row].strip() if row < len(lines) else ""
            if err.is_missing:
                kind = "(ausente)"
            elif err.text:
                kind = err.text.decode("utf-8", "replace")
            else:
                kind = "?"
            print(f"     linha {row + 1}:{col + 1}  {kind}  |  {snippet[:80]}")

    print()
    if total_errors == 0:
        print(f"Todos os {len(files)} arquivos Dart são sintaticamente válidos.")
        return 0
    print(f"{total_errors} problema(s) de sintaxe em {len(files)} arquivos.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
