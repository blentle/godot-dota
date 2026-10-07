import copy
import json
import unittest

from tools.validate_content import DEFAULT_MANIFEST, validate


class ContentValidationTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads(DEFAULT_MANIFEST.read_text(encoding="utf-8"))

    def test_scaffold_is_valid_but_not_releasable(self):
        self.assertEqual(validate(self.data), [])
        self.assertGreaterEqual(len(validate(self.data, release=True)), 5)

    def test_rejects_wrong_match_size_and_engine(self):
        self.data.update(players_per_match=9, engine_version="4.8.dev")
        errors = validate(self.data)
        self.assertTrue(any("players_per_match" in e for e in errors))
        self.assertTrue(any("engine_version" in e for e in errors))

    def test_duplicate_heroes_are_not_counted_as_complete(self):
        hero = {"id": "test_hero", "status": "accepted"}
        self.data["heroes"] = [hero, copy.deepcopy(hero)]
        self.assertTrue(any("duplicate" in e for e in validate(self.data)))

    def test_malformed_records_return_errors(self):
        for value in [None, [], "bad", 1]:
            self.assertTrue(validate(value))
        self.data["heroes"] = [None, {"id": [], "status": "unknown"}]
        self.assertEqual(len(validate(self.data)), 3)

    def test_boolean_is_not_an_integer_version(self):
        self.data["schema_version"] = True
        self.assertTrue(validate(self.data))

    def test_release_checks_inventory_only(self):
        self.data.update(
            status="release_candidate", reference_map_sha256="a" * 64,
            reference_roster_verified=True, expected_hero_count=1,
            heroes=[{"id": "fixture_only", "status": "accepted"}], ui_acceptance_score=95,
        )
        self.assertEqual(validate(self.data, release=True), [])
        self.data["heroes"][0]["status"] = "implemented"
        self.assertTrue(any("not accepted" in e for e in validate(self.data, release=True)))


if __name__ == "__main__":
    unittest.main()
