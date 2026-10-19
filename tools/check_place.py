"""Structural check of RocketField.rbxlx: our scripts are in place, laser blasters kept, template patched and intact."""
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASES = {
    "shared": ["ReplicatedStorage", "RocketShared"],
    "server": ["ServerScriptService", "RocketServer"],
    "client": ["StarterPlayer", "StarterPlayerScripts", "RocketClient"],
}


def name_of(i):
    return i.findtext("Properties/string[@name='Name']")


def main(path):
    root = ET.parse(path).getroot()
    services = {i.get("class"): i for i in root.findall("Item")}
    errors = []

    def find(path):
        node = services.get(path[0])
        for n in path[1:]:
            node = next((c for c in node.findall("Item") if name_of(c) == n), None) if node is not None else None
        return node

    for top, base in BASES.items():
        for f in sorted((ROOT / "src" / top).rglob("*.luau")):
            rel = f.relative_to(ROOT / "src" / top)
            stem = f.name.split(".")[0]
            cls = "Script" if f.name.endswith(".server.luau") else "LocalScript" if f.name.endswith(".client.luau") else "ModuleScript"
            node = find(base + list(rel.parent.parts) + [stem])
            label = "/".join(base + list(rel.parent.parts) + [stem])
            if node is None or node.get("class") != cls:
                errors.append(f"missing {cls} {label}")
                continue
            src = next((c.text or "" for c in node.find("Properties") if c.get("name") == "Source"), "")
            if re.sub(r"\s+", "", src) != re.sub(r"\s+", "", f.read_text(encoding="utf-8")):
                errors.append(f"source mismatch {label}")
            else:
                print(f"ok   {cls:12s} {label}")

    sp = services.get("StarterPack")
    left = [name_of(c) for c in sp.findall("Item")] if sp is not None else []
    for n in ("Blaster", "AutoBlaster"):
        if n in left:
            print("ok   StarterPack/" + n + " (personal weapon)")
        else:
            errors.append("StarterPack/" + n + " missing")

    def source(path):
        node = find(path)
        if node is None:
            return None
        return next((c.text or "" for c in node.find("Properties") if c.get("name") == "Source"), "")

    scoring = source(["ServerScriptService", "Gameplay", "Scripts", "Scoring"])
    if scoring is None or "team:SetAttribute(Constants.TEAM_SCORE_ATTRIBUTE, score)" in scoring:
        errors.append("Scoring not patched (team score still summed from players)")
    else:
        print("ok   Scoring patched")
    tdm = source(["ServerScriptService", "Gameplay", "Scripts", "Modes", "TDM"])
    want = (ROOT / "tools/patches/TDM.luau").read_text(encoding="utf-8")
    if tdm is None or re.sub(r"\s+", "", tdm) != re.sub(r"\s+", "", want):
        errors.append("TDM mode not replaced")
    else:
        print("ok   TDM replaced (destroy-the-camp)")

    for need in (
        ["ServerScriptService", "Gameplay", "Scripts", "Scoring"],
        ["ServerScriptService", "Gameplay", "Scripts", "Rounds"],
        ["ServerScriptService", "Blaster", "Events", "Eliminated"],
        ["ServerScriptService", "Blaster", "Events", "Tagged"],
        ["ReplicatedStorage", "Blaster", "Utility", "canPlayerDamageHumanoid"],
        ["ServerStorage", "Laser Tag Template Library", "Props", "CrateSmall"],
        ["Workspace", "Layout", "Walls"],
        ["Workspace", "SpawnLocations", "PinkSpawnLocation"],
        ["Workspace", "SpawnLocations", "GreenSpawnLocation"],
    ):
        if find(need) is None:
            errors.append("missing template piece " + "/".join(need))
        else:
            print("ok   template " + "/".join(need))

    if errors:
        print("\nFAILED:\n  - " + "\n  - ".join(errors))
        for e in errors[:10]:
            print("::error::" + e)
        sys.exit(1)
    print("\nPlace file structure OK")


if __name__ == "__main__":
    main(sys.argv[1])
