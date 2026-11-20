#!/usr/bin/env python3
"""Detecta imports não utilizados e símbolos locais nunca referenciados.

Regras simplificadas inspiradas no `flutter analyze`:

1. Import cujo prefixo do símbolo não aparece no corpo do arquivo.
2. Variável local declarada (`final x = ...` / `var x = ...`) que nunca é
   lida depois da declaração.

Uso:
    python3 tools/check_unused.py [raiz-do-projeto-flutter]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

IMPORT_RE = re.compile(r"^import\s+'([^']+)'", re.MULTILINE)
CLASS_DECL_RE = re.compile(r"^(?:abstract\s+)?class\s+(\w+)", re.MULTILINE)
ENUM_DECL_RE = re.compile(r"^enum\s+(\w+)", re.MULTILINE)
MIXIN_DECL_RE = re.compile(r"^mixin\s+(\w+)", re.MULTILINE)
EXTENSION_DECL_RE = re.compile(r"^extension\s+(\w+)", re.MULTILINE)
TYPEDEF_DECL_RE = re.compile(r"^typedef\s+(\w+)", re.MULTILINE)
FUNC_DECL_RE = re.compile(r"^(?:[\w<>,\s\?]+)\s+(\w+)\s*\(", re.MULTILINE)

# Declarações de variáveis locais simples.
LOCAL_VAR_RE = re.compile(
    r"^\s{4,}(?:final|const|var)\s+(?:[\w<>,\s\?\[\]]+\s+)?(\w+)\s*=",
    re.MULTILINE,
)


def strip_code(src: str) -> str:
    """Remove comentários e literais de string, preservando interpolação.

    Interpolations como `${dir.path}` precisam continuar visíveis para que
    o uso de uma variável dentro de uma string não seja considerado morto.
    """
    src = re.sub(r"//.*", "", src)
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.DOTALL)

    # Substitui apenas o texto literal da string, mantendo as interpolações.
    def keep_interpolations(match: re.Match) -> str:
        literal = match.group(0)
        return re.sub(r"\$\{[^}]*\}", lambda m: m.group(0), literal)

    src = re.sub(r"'(\\.|[^'\\])*'", keep_interpolations, src)
    src = re.sub(r'"(\\.|[^"\\])*"', keep_interpolations, src)
    return src


def exported_symbols(path: Path) -> set[str]:
    """Nomes públicos declarados em um arquivo Dart.

    Para imports internos (`../../models/recording.dart`) o nome exportado
    não corresponde ao nome do arquivo, então precisamos ler o alvo.
    """
    if not path.exists():
        return set()

    src = path.read_text(encoding="utf-8")
    names: set[str] = set()
    names |= set(CLASS_DECL_RE.findall(src))
    names |= set(ENUM_DECL_RE.findall(src))
    names |= set(MIXIN_DECL_RE.findall(src))
    names |= set(EXTENSION_DECL_RE.findall(src))
    names |= set(TYPEDEF_DECL_RE.findall(src))

    # Funções e getters de topo de nível.
    for m in re.finditer(
        r"^(?:[\w<>,\s\?\[\]]+\s+)?([a-z]\w*)\s*\(", src, re.MULTILINE
    ):
        names.add(m.group(1))

    # Variáveis de topo de nível.
    for m in re.finditer(
        r"^(?:final|const|var)\s+(?:[\w<>,\s\?\[\]]+\s+)?(\w+)\s*=",
        src,
        re.MULTILINE,
    ):
        names.add(m.group(1))

    return names


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "app").resolve()
    lib_dir = root / "lib"
    problems: list[str] = []

    for file in sorted(lib_dir.rglob("*.dart")):
        raw = file.read_text(encoding="utf-8")
        src = strip_code(raw)

        # ----------------------------------------------------------
        # 1. Imports não utilizados
        # ----------------------------------------------------------
        body_start = 0
        imports: list[tuple[str, str, int]] = []
        for m in IMPORT_RE.finditer(src):
            imports.append((m.group(1), m.group(0), m.start()))
            body_start = max(body_start, m.end())

        body = src[body_start:]

        for path, statement, _ in imports:
            if path.startswith("dart:"):
                continue

            if path.startswith("package:scrott_voice/"):
                target = root / "lib" / path[len("package:scrott_voice/"):]
            elif path.startswith("package:"):
                # Pacotes externos: não temos o código-fonte, entãopulamos.
                continue
            elif path.startswith(("dart:", "../", "./")):
                target = (file.parent / path).resolve()
                if not target.exists():
                    target = (root / "lib" / path).resolve()
            else:
                continue

            symbols = exported_symbols(target)
            if not symbols:
                continue

            used = [
                s for s in symbols
                if re.search(rf"\b{re.escape(s)}\b", body)
            ]

            if not used:
                problems.append(
                    f"{file.relative_to(root)}: import possivelmente não "
                    f"utilizado -> {path}"
                )

        # ----------------------------------------------------------
        # 2. Variáveis locais nunca lidas
        # ----------------------------------------------------------
        for name in set(LOCAL_VAR_RE.findall(src)):
            # Conta usos além da própria declaração.
            uses = len(re.findall(rf"\b{re.escape(name)}\b", src))
            if uses <= 1:
                problems.append(
                    f"{file.relative_to(root)}: variável local '{name}' "
                    f"nunca é lida"
                )

    for p in problems:
        print(p)
    print()
    if problems:
        print(f"{len(problems)} aviso(s).")
        return 1
    print("Nenhum import/variável obviamente sem uso.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
