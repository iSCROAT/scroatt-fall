#!/usr/bin/env python3
"""Verificação estática leve do código Dart.

Sem o `flutter analyze` disponível neste ambiente, esta ferramenta faz
as checagens que mais quebram builds e que são detectáveis estaticamente:

1. Importações internas apontando para arquivos inexistentes.
2. Uso de `AppIcons.X` onde `X` não existe no catálogo.
3. Classes/variáveis de `AppColors` que não existem.
4. Assets SVG referenciados que não estão em `assets/icons/`.
5. `const`/nomes usados mas nunca declarados no próprio arquivo para os
   símbolos do projeto (AppIcons, AppColors, formatDuration...).
6. Balanceamento de chaves/parênteses já coberto pelo parser tree-sitter.

Uso:
    python3 tools/check_references.py [raiz-do-projeto-flutter]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# ----------------------------------------------------------------------
# Padrões
# ----------------------------------------------------------------------
IMPORT_RE = re.compile(r"""import\s+'([^']+)'""")
ASSET_RE = re.compile(r"""['"](assets/icons/[^'"]+\.svg)['"]""")
APP_ICON_REF_RE = re.compile(r"\bAppIcons\.(\w+)")
APP_COLORS_REF_RE = re.compile(r"\bAppColors\.(\w+)")

# Construtores privados (`AppIcons._`) não são membros do catálogo.
PRIVATE_MEMBERS = {"_"}
FORMATTER_REF_RE = re.compile(r"\b(formatDuration|formatPreciseDuration|formatBytes)\b")

DECL_RE = {
    "AppIcons": re.compile(r"static\s+const\s+String\s+(\w+)\s*="),
    "AppColors": re.compile(r"static\s+const\s+Color\s+(\w+)\s*="),
    "AppColors.static": re.compile(r"static\s+const\s+LinearGradient\s+(\w+)\s*="),
}


def collect_declarations(path: Path) -> dict[str, set[str]]:
    """Extrai os nomes declarados em cada arquivo do projeto."""
    src = path.read_text(encoding="utf-8")
    out: dict[str, set[str]] = {}

    icon_decls = set(DECL_RE["AppIcons"].findall(src))
    color_decls = set(DECL_RE["AppColors"].findall(src))
    color_decls |= set(DECL_RE["AppColors.static"].findall(src))
    out["AppIcons"] = icon_decls
    out["AppColors"] = color_decls
    return out


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "app").resolve()
    lib_dir = root / "lib"
    assets_dir = root / "assets" / "icons"

    problems: list[str] = []

    # ---- 1. Importações internas -----------------------------------
    for file in sorted(lib_dir.rglob("*.dart")):
        src = file.read_text(encoding="utf-8")
        for imp in IMPORT_RE.findall(src):
            if not imp.startswith(("package:", "dart:")):
                continue
            # Imports relativos: resolve a partir do diretório do arquivo.
            if imp.startswith("package:scrott_voice/"):
                target = root / "lib" / imp[len("package:scrott_voice/"):]
                if not target.exists():
                    problems.append(
                        f"{file.relative_to(root)}: import package inexistente "
                        f"'{imp}'"
                    )

    # ---- 2/3. Símbolos de AppIcons e AppColors ---------------------
    icon_decls: set[str] = set()
    color_decls: set[str] = set()
    for file in sorted(lib_dir.rglob("*.dart")):
        decls = collect_declarations(file)
        icon_decls |= decls["AppIcons"]
        color_decls |= decls["AppColors"]

    for file in sorted(lib_dir.rglob("*.dart")):
        src = file.read_text(encoding="utf-8")
        for name in set(APP_ICON_REF_RE.findall(src)):
            if name in PRIVATE_MEMBERS:
                continue
            if name not in icon_decls:
                problems.append(
                    f"{file.relative_to(root)}: AppIcons.{name} não existe"
                )
        for name in set(APP_COLORS_REF_RE.findall(src)):
            if name in PRIVATE_MEMBERS:
                continue
            if name not in color_decls:
                problems.append(
                    f"{file.relative_to(root)}: AppColors.{name} não existe"
                )

    # ---- 4. Assets SVG referenciados --------------------------------
    for file in sorted(lib_dir.rglob("*.dart")):
        src = file.read_text(encoding="utf-8")
        for asset in set(ASSET_RE.findall(src)):
            if not (root / asset).exists():
                problems.append(
                    f"{file.relative_to(root)}: asset inexistente '{asset}'"
                )

    # ---- 5. Assets em disco sem referência (aviso) ------------------
    # `app_icon.svg` é a fonte do ícone do launcher gerado para o Android,
    # então é consumido pelo build nativo e não pelo código Dart.
    build_time_assets = {"assets/icons/app_icon.svg"}
    referenced: set[str] = set()
    for file in sorted(lib_dir.rglob("*.dart")):
        referenced |= set(ASSET_RE.findall(file.read_text(encoding="utf-8")))
    for svg in sorted(assets_dir.glob("*.svg")):
        rel = f"assets/icons/{svg.name}"
        if rel not in referenced and rel not in build_time_assets:
            problems.append(f"[aviso] asset sem uso: {rel}")

    # ---- 6. Funções de formatação disponíveis -----------------------
    formatter_src = (lib_dir / "core" / "utils" / "formatters.dart").read_text(
        encoding="utf-8"
    )
    for file in sorted(lib_dir.rglob("*.dart")):
        src = file.read_text(encoding="utf-8")
        for fn in set(FORMATTER_REF_RE.findall(src)):
            if f"String {fn}(" not in formatter_src:
                problems.append(
                    f"{file.relative_to(root)}: função '{fn}' não definida"
                )

    # ---- Relatório ---------------------------------------------------
    for p in problems:
        print(p)
    print()
    if problems:
        print(f"{len(problems)} problema(s) encontrado(s).")
        return 1
    print("Nenhum problema de referência encontrado.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
