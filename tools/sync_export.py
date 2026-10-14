"""Grava no repositorio os scripts exportados do Studio.

Uso: python3 tools/sync_export.py <arquivo-tool-result> <missao|main-lobby> [bytes_esperados...]
O arquivo e a saida do execute_luau no formato: "LOTE " + JSON [{p, c, s}] (+ "\n#PAD#..." opcional).
Recusa gravar se encontrar require(<numero>), getfenv ou loadstring.
"""
import json, os, re, sys

EXT = {"Script": ".server.lua", "LocalScript": ".client.lua", "ModuleScript": ".lua"}
BAD = [re.compile(r"require\s*\(\s*\d"), re.compile(r"getfenv"), re.compile(r"loadstring")]

src, place = sys.argv[1], sys.argv[2]
raw = open(src, encoding="utf-8").read()
assert raw.startswith("LOTE "), "formato inesperado"
body = raw[5:].split("\n#PAD#")[0]
items = json.loads(body)
root = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), place)
for it in items:
    for b in BAD:
        if b.search(it["s"]):
            sys.exit(f"RECUSADO: padrao suspeito em {it['p']}")
for it in items:
    parts = it["p"].split(".")
    path = os.path.join(root, *parts[:-1], parts[-1] + EXT[it["c"]])
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(it["s"])
    print(f"{len(it['s'].encode('utf-8')):>7} bytes  {os.path.relpath(path, root)}")
