"""Build RocketField.rbxlx: the Laser Tag template (base/) + our scripts from src/.

  src/shared  -> ReplicatedStorage/RocketShared            (ModuleScripts)
  src/server  -> ServerScriptService/RocketServer           (*.server.luau = Script, others ModuleScript)
  src/client  -> StarterPlayer/StarterPlayerScripts/RocketClient (*.client.luau = LocalScript)

The template's laser blasters are removed from StarterPack (our launchers replace them).
usage: python3 tools/build_place.py [--base base/LaserTag-Template.rbxlx] [--out RocketField.rbxlx]
"""
import argparse
import itertools
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_ref = itertools.count(1)
REMOVE_FROM_STARTERPACK = {"Blaster", "AutoBlaster"}


def name_of(i):
    return i.findtext("Properties/string[@name='Name']")


def item(parent, cls, name):
    it = ET.SubElement(parent, "Item", {"class": cls, "referent": f"RBXROCKET{next(_ref):06d}"})
    props = ET.SubElement(it, "Properties")
    ET.SubElement(props, "string", {"name": "Name"}).text = name
    return it


def script(parent, path: Path):
    n = path.name
    if n.endswith(".server.luau"):
        cls, name = "Script", n[: -len(".server.luau")]
    elif n.endswith(".client.luau"):
        cls, name = "LocalScript", n[: -len(".client.luau")]
    else:
        cls, name = "ModuleScript", n[: -len(".luau")]
    it = item(parent, cls, name)
    ET.SubElement(it.find("Properties"), "ProtectedString", {"name": "Source"}).text = path.read_text(encoding="utf-8")


def folder_tree(parent, directory: Path, name: str):
    for old in [c for c in parent.findall("Item") if name_of(c) == name]:
        parent.remove(old)
    f = item(parent, "Folder", name)
    for p in sorted(directory.iterdir()):
        if p.is_dir():
            folder_tree(f, p, p.name)
        elif p.suffix == ".luau":
            script(f, p)


def service(root, cls):
    return next(i for i in root.findall("Item") if i.get("class") == cls)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=str(ROOT / "base/LaserTag-Template.rbxlx"))
    ap.add_argument("--out", default=str(ROOT / "RocketField.rbxlx"))
    a = ap.parse_args()
    tree = ET.parse(a.base)
    root = tree.getroot()

    sp = service(root, "StarterPack")
    for t in [c for c in sp.findall("Item") if name_of(c) in REMOVE_FROM_STARTERPACK]:
        sp.remove(t)
        print("removed StarterPack/" + name_of(t))

    folder_tree(service(root, "ReplicatedStorage"), ROOT / "src/shared", "RocketShared")
    folder_tree(service(root, "ServerScriptService"), ROOT / "src/server", "RocketServer")
    player = service(root, "StarterPlayer")
    sps = next(c for c in player.findall("Item") if c.get("class") == "StarterPlayerScripts")
    folder_tree(sps, ROOT / "src/client", "RocketClient")

    tree.write(a.out, encoding="utf-8", xml_declaration=True)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
