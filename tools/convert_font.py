"""Converte os WOFF do pacote @fontsource/inter em TTF para uso no Flutter.

Uso:
    python3 tools/convert_font.py <dir_extraido_do_npm_pack> <destino>

O pacote npm `@fontsource/inter` distribui apenas WOFF/WOFF2, que o Flutter
não lê. Este script converte para TTF cru, mantendo os mesmos pesos.
"""
import os
import sys

from fontTools.ttLib import TTFont

TARGETS = [
    (400, "Inter-Regular.ttf"),
    (500, "Inter-Medium.ttf"),
    (600, "Inter-SemiBold.ttf"),
    (700, "Inter-Bold.ttf"),
]


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)

    src_dir = sys.argv[1]
    out_dir = sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

    for weight, filename in TARGETS:
        src = os.path.join(src_dir, f"inter-latin-{weight}-normal.woff")
        if not os.path.exists(src):
            raise SystemExit(f"fonte ausente: {src}")

        font = TTFont(src)
        font.flavor = None  # garante saída TTF crua
        target = os.path.join(out_dir, filename)
        font.save(target)
        print(f"{filename}: {os.path.getsize(target)} bytes")

    print("OK")


if __name__ == "__main__":
    main()
