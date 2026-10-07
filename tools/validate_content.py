"""检查内容清单结构；通过不代表玩法正确或视觉已验收。"""

import argparse
import json
from pathlib import Path
import re
import sys

DEFAULT_MANIFEST = Path(__file__).resolve().parents[1] / "game/content/6.83d/manifest.json"
STATES = {"unverified", "sourced", "implemented", "behavior_verified", "visual_verified", "accepted"}


def validate(data, release=False):
    errors = []
    if not isinstance(data, dict):
        return ["manifest must be an object"]
    for field, expected in {
        "schema_version": 1, "ruleset_id": "dota-6.83d", "engine_version": "4.7.2",
        "protocol_version": 1, "players_per_match": 10, "team_size": 5,
    }.items():
        if type(data.get(field)) is not type(expected) or data.get(field) != expected:
            errors.append(f"{field} must be {expected!r}")
    if data.get("status") not in {"scaffold", "development", "release_candidate"}:
        errors.append("invalid content status")
    heroes = data.get("heroes")
    if not isinstance(heroes, list):
        errors.append("heroes must be an array")
        heroes = []
    seen = set()
    for index, hero in enumerate(heroes):
        if not isinstance(hero, dict):
            errors.append(f"heroes[{index}] must be an object")
            continue
        hero_id = hero.get("id")
        if not isinstance(hero_id, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", hero_id):
            errors.append(f"heroes[{index}] has invalid id")
        elif hero_id in seen:
            errors.append(f"duplicate hero id: {hero_id}")
        else:
            seen.add(hero_id)
        if hero.get("status") not in STATES:
            errors.append(f"heroes[{index}] has invalid status")
        if release and hero.get("status") != "accepted":
            errors.append(f"heroes[{index}] is not accepted")
    if release:
        if data.get("status") != "release_candidate":
            errors.append("content is not a release candidate")
        digest = data.get("reference_map_sha256")
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            errors.append("reference map SHA-256 is missing or invalid")
        if data.get("reference_roster_verified") is not True:
            errors.append("reference hero roster is not verified")
        expected = data.get("expected_hero_count")
        if type(expected) is not int or expected < 1 or len(heroes) != expected:
            errors.append("hero count does not match a verified nonempty roster")
        score = data.get("ui_acceptance_score")
        if type(score) not in (int, float) or not 95 <= score <= 100:
            errors.append("UI acceptance score must be between 95 and 100")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--release", action="store_true", help="Check recorded release inventory gates")
    args = parser.parse_args()
    try:
        errors = validate(json.loads(args.manifest.read_text(encoding="utf-8")), args.release)
    except (OSError, ValueError) as exc:
        errors = [str(exc)]
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    if errors:
        return 1
    print("Inventory checks passed. Gameplay, asset fidelity and recorded evidence require separate acceptance.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
