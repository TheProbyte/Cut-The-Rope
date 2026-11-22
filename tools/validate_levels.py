#!/usr/bin/env python3
"""Validates worlds.json and every JSON level definition for DRIP."""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLDS_PATH = os.path.join(ROOT, "data", "levels", "worlds.json")
VALID_STATES = {"water", "ice", "steam"}
VALID_DIRS = {"left", "right", "up", "down"}


def check_point(pt, label: str, errors: list[str]) -> None:
    if not isinstance(pt, list) or len(pt) != 2:
        errors.append(f"{label}: expected [x, y], got {pt!r}")
        return
    x, y = pt
    if not (0 <= x <= 720 and 80 <= y <= 1220):
        errors.append(f"{label}: point {pt} outside playfield bounds (0..720, 80..1220)")


def validate_level(path: str, expected_world: str) -> list[str]:
    errors: list[str] = []
    if not os.path.exists(path):
        return [f"Missing level file: {path}"]
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as exc:
        return [f"Invalid JSON in {path}: {exc}"]

    for key in ("id", "world", "title", "spawn", "seedling", "collectibles"):
        if key not in data:
            errors.append(f"{path}: missing required key '{key}'")

    if data.get("world") != expected_world:
        errors.append(f"{path}: world '{data.get('world')}' != '{expected_world}'")

    spawn = data.get("spawn", {})
    check_point(spawn.get("pos"), f"{path} spawn.pos", errors)
    state = str(spawn.get("state", "water")).lower()
    if state not in VALID_STATES:
        errors.append(f"{path}: invalid spawn.state '{state}'")

    seedling = data.get("seedling", {})
    check_point(seedling.get("pos"), f"{path} seedling.pos", errors)

    collectibles = data.get("collectibles", [])
    if len(collectibles) != 3:
        errors.append(f"{path}: expected 3 collectibles, found {len(collectibles)}")
    for idx, col in enumerate(collectibles):
        pos = col.get("pos") if isinstance(col, dict) else col
        check_point(pos, f"{path} collectibles[{idx}]", errors)

    for seg_key in ("platforms", "grates", "glass_panes", "cold_pipes"):
        for idx, item in enumerate(data.get(seg_key, [])):
            if "from" in item and "to" in item:
                check_point(item["from"], f"{path} {seg_key}[{idx}].from", errors)
                check_point(item["to"], f"{path} {seg_key}[{idx}].to", errors)
            elif "pos" in item:
                check_point(item["pos"], f"{path} {seg_key}[{idx}].pos", errors)
            else:
                errors.append(f"{path} {seg_key}[{idx}]: needs 'from'/'to' or 'pos'")

    for zone_key in ("heat_lamps", "freezer_zones"):
        for idx, z in enumerate(data.get(zone_key, [])):
            check_point(z.get("pos"), f"{path} {zone_key}[{idx}].pos", errors)
            sz = z.get("size")
            if not isinstance(sz, list) or len(sz) != 2 or sz[0] <= 0 or sz[1] <= 0:
                errors.append(f"{path} {zone_key}[{idx}].size invalid: {sz!r}")

    for idx, fan in enumerate(data.get("fans", [])):
        check_point(fan.get("pos"), f"{path} fans[{idx}].pos", errors)
        d = fan.get("direction", "right")
        if isinstance(d, str) and d.lower() not in VALID_DIRS:
            errors.append(f"{path} fans[{idx}].direction invalid: {d!r}")

    for idx, drain in enumerate(data.get("drains", [])):
        check_point(drain.get("pos"), f"{path} drains[{idx}].pos", errors)

    for idx, hp in enumerate(data.get("hot_plates", [])):
        check_point(hp.get("pos"), f"{path} hot_plates[{idx}].pos", errors)

    for idx, sp in enumerate(data.get("sponges", [])):
        check_point(sp.get("pos"), f"{path} sponges[{idx}].pos", errors)

    for idx, mp in enumerate(data.get("moving_platforms", [])):
        check_point(mp.get("from"), f"{path} moving_platforms[{idx}].from", errors)
        check_point(mp.get("to"), f"{path} moving_platforms[{idx}].to", errors)

    return errors


def main() -> int:
    with open(WORLDS_PATH, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    all_errors: list[str] = []
    seen_ids: set[str] = set()
    total_levels = 0

    for world in manifest.get("worlds", []):
        world_id = world["id"]
        for res_path in world.get("levels", []):
            rel = res_path.replace("res://", "", 1)
            full_path = os.path.join(ROOT, rel)
            errs = validate_level(full_path, world_id)
            all_errors.extend(errs)
            if not errs:
                with open(full_path, "r", encoding="utf-8") as lf:
                    lvl_id = json.load(lf)["id"]
                if lvl_id in seen_ids:
                    all_errors.append(f"Duplicate level id: {lvl_id}")
                seen_ids.add(lvl_id)
            total_levels += 1

    if all_errors:
        print("Level validation FAILED:", file=sys.stderr)
        for e in all_errors:
            print("  -", e, file=sys.stderr)
        return 1

    print(f"Validated {total_levels} levels cleanly.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
