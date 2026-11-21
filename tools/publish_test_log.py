#!/usr/bin/env python3
"""Publica um arquivo de log no repositorio, pela API do GitHub.

Uso:
    python3 tools/publish_test_log.py <arquivo-local> <caminho-no-repo> <mensagem>

O token vem de `GITHUB_TOKEN`, que o GitHub Actions injeta no runner.
"""
from __future__ import annotations

import base64
import json
import os
import sys
import urllib.error
import urllib.request


def main() -> int:
    if len(sys.argv) < 4:
        print("uso: publish_test_log.py <local> <destino> <mensagem>",
              file=sys.stderr)
        return 2

    local, destino, mensagem = sys.argv[1], sys.argv[2], sys.argv[3]

    with open(local, "rb") as fh:
        content = base64.b64encode(fh.read()).decode()

    repo = os.environ.get("GITHUB_REPOSITORY", "")
    ref = os.environ.get("GITHUB_REF_NAME", "main")
    token = os.environ.get("GITHUB_TOKEN", "")

    headers = {
        "Authorization": "Bearer " + token,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "Content-Type": "application/json",
    }
    base = "https://api.github.com/repos/%s/contents/%s" % (repo, destino)

    def call(url: str, method: str = "GET", body: dict | None = None):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method,
                                     headers=headers)
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read().decode() or "{}")

    sha = None
    try:
        sha = call(base + "?ref=" + ref).get("sha")
    except Exception:
        sha = None

    body = {"message": mensagem, "content": content, "branch": ref}
    if sha:
        body["sha"] = sha

    try:
        call(base, method="PUT", body=body)
    except urllib.error.HTTPError as exc:
        print("falha ao publicar:", exc.code, exc.read()[:200].decode(
            "utf-8", "replace"), file=sys.stderr)
        return 1
    except Exception as exc:  # noqa: BLE001
        print("falha ao publicar:", exc, file=sys.stderr)
        return 1

    print("log publicado em", destino)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
