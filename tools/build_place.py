"""Build RocketField.rbxlx: the Laser Tag template (base/) + our scripts from src/.

  src/shared  -> ReplicatedStorage/RocketShared            (ModuleScripts)
  src/server  -> ServerScriptService/RocketServer           (*.server.luau = Script, others ModuleScript)
  src/client  -> StarterPlayer/StarterPlayerScripts/RocketClient (*.client.luau = LocalScript)

The template's laser Blaster and AutoBlaster stay in StarterPack as the personal weapons.
Template patches: Scoring no longer sums player scores into the team "score" (our camps write it),
and the TDM mode is replaced with tools/patches/TDM.luau (destroy the enemy camp).
usage: python3 tools/build_place.py [--base base/LaserTag-Template.rbxlx] [--out RocketField.rbxlx]
"""
import argparse
import itertools
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_ref = itertools.count(1)
REMOVE_FROM_STARTERPACK: set = set()
SCORING_TEAM_LINE = "team:SetAttribute(Constants.TEAM_SCORE_ATTRIBUTE, score)"
SCORING_PATCH = "-- ميدان الصواريخ: نتيجة الفريق = نسبة تدمير معسكر العدو (RocketServer/Camps)\n\tlocal _ = score"

# من مبنى القالب نبقي غرفتي الظهور فقط (طرفي المبنى) كثكنات للفريقين، والوسط يتشال ويصير ساحة مفتوحة.
# المناطق بإحداثيات العالم (x0, x1, z0, z1)
KEEP_REGIONS = [
    (-160.0, -20.0, -50.0, 26.0),   # ثكنة الوردي
    (-160.0, -20.0, 294.0, 370.0),  # ثكنة الأخضر
]
CARVE_FOLDERS = {"Layout", "Level_Art", "Forcefields"}
DROP_FOLDERS = {"playerContainment"}


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


def _props(it):
    p = it.find("Properties")
    return p if p is not None else ET.Element("Properties")


def _vec(props, name):
    node = next((c for c in props if c.get("name") == name), None)
    if node is None:
        return None, None
    return node, {e.tag: float(e.text) for e in node}


def _world_extent(cf, size):
    hx = abs(cf["R00"]) * size["X"] / 2 + abs(cf["R01"]) * size["Y"] / 2 + abs(cf["R02"]) * size["Z"] / 2
    hz = abs(cf["R20"]) * size["X"] / 2 + abs(cf["R21"]) * size["Y"] / 2 + abs(cf["R22"]) * size["Z"] / 2
    return (cf["X"] - hx, cf["X"] + hx, cf["Z"] - hz, cf["Z"] + hz)


def _axis_aligned(cf):
    vals = [cf[k] for k in ("R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")]
    return all(abs(v) < 1e-3 or abs(abs(v) - 1) < 1e-3 for v in vals) and abs(abs(cf["R11"]) - 1) < 1e-3


def carve_building(root):
    """Keep the two spawn rooms of the template building, remove the middle (open field)."""
    ws = service(root, "Workspace")
    parent = {}
    for p in ws.iter("Item"):
        for c in p.findall("Item"):
            parent[c] = p
    removed = kept = cropped = 0
    for folder in [c for c in ws.findall("Item") if name_of(c) in CARVE_FOLDERS]:
        for drop in [c for c in folder.iter("Item") if name_of(c) in DROP_FOLDERS]:
            parent[drop].remove(drop)
        for it in list(folder.iter("Item")):
            props = _props(it)
            cfn, cf = _vec(props, "CFrame")
            szn, size = _vec(props, "size")
            if cf is None or size is None or "R00" not in cf:
                continue
            x0, x1, z0, z1 = _world_extent(cf, size)
            inside = any(a <= cf["X"] <= b and c <= cf["Z"] <= d for a, b, c, d in KEEP_REGIONS)
            overlap = None
            for a, b, c, d in KEEP_REGIONS:
                ox0, ox1, oz0, oz1 = max(x0, a), min(x1, b), max(z0, c), min(z1, d)
                if ox1 - ox0 > 0.5 and oz1 - oz0 > 0.5:
                    overlap = (ox0, ox1, oz0, oz1)
            if overlap and it.get("class") == "Part" and _axis_aligned(cf):
                ox0, ox1, oz0, oz1 = overlap
                if (ox0, ox1, oz0, oz1) != (x0, x1, z0, z1):
                    wx, wz = ox1 - ox0, oz1 - oz0
                    swapped = abs(cf["R02"]) > 0.5  # المحور المحلي X على محور العالم Z
                    for e in szn:
                        if e.tag == ("Z" if swapped else "X"):
                            e.text = repr(wx)
                        elif e.tag == ("X" if swapped else "Z"):
                            e.text = repr(wz)
                    for e in cfn:
                        if e.tag == "X":
                            e.text = repr((ox0 + ox1) / 2)
                        elif e.tag == "Z":
                            e.text = repr((oz0 + oz1) / 2)
                    cropped += 1
                kept += 1
            elif inside:
                kept += 1
            elif it in parent:
                parent[it].remove(it)
                removed += 1
    print(f"building carved: kept {kept}, cropped {cropped}, removed {removed}")


def find_path(root, path):
    node = service(root, path[0])
    for n in path[1:]:
        node = next((c for c in node.findall("Item") if name_of(c) == n), None)
        if node is None:
            raise SystemExit("template piece missing: " + "/".join(path))
    return node


def source_node(it):
    return next(c for c in it.find("Properties") if c.get("name") == "Source")


def patch_template(root):
    scoring = source_node(find_path(root, ["ServerScriptService", "Gameplay", "Scripts", "Scoring"]))
    if SCORING_TEAM_LINE not in (scoring.text or ""):
        raise SystemExit("Scoring: team score line not found (template changed?)")
    scoring.text = scoring.text.replace(SCORING_TEAM_LINE, SCORING_PATCH)
    tdm = source_node(find_path(root, ["ServerScriptService", "Gameplay", "Scripts", "Modes", "TDM"]))
    tdm.text = (ROOT / "tools/patches/TDM.luau").read_text(encoding="utf-8")
    print("patched template Scoring + TDM (destroy-the-camp mode)")


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

    carve_building(root)
    patch_template(root)
    folder_tree(service(root, "ReplicatedStorage"), ROOT / "src/shared", "RocketShared")
    folder_tree(service(root, "ServerScriptService"), ROOT / "src/server", "RocketServer")
    player = service(root, "StarterPlayer")
    sps = next(c for c in player.findall("Item") if c.get("class") == "StarterPlayerScripts")
    folder_tree(sps, ROOT / "src/client", "RocketClient")

    tree.write(a.out, encoding="utf-8", xml_declaration=True)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
