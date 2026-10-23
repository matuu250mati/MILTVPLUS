"""Unit tests for the production schema dump release gate."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("validate_supabase_schema_dump.py")
REQUIRED = {
    "channels": {"id", "title", "url_stream", "stream_urls", "category", "country_code", "is_published", "sort_order", "logo"},
    "movies": {"id", "tmdb_id", "title", "synopsis", "category", "genres", "logo", "backdrop_url", "url_stream", "stream_urls", "release_year", "duration_seconds", "country_code", "is_published", "created_at", "updated_at"},
    "series": {"id", "tmdb_id", "title", "synopsis", "category", "genres", "logo", "backdrop_url", "release_year", "country_code", "is_published", "created_at", "updated_at"},
    "episodes": {"id", "series_id", "title", "synopsis", "logo", "url_stream", "duration_seconds", "is_published", "season_number", "episode_number", "created_at"},
    "content_submissions": {"id", "title", "description", "stream_url", "poster_url", "duration_seconds", "series_title", "season_number", "episode_number", "media_type", "moderation_status", "rights_confirmed", "created_at"},
}


def make_dump(missing=None):
    chunks = []
    for table, columns in REQUIRED.items():
        selected = sorted(columns - ({missing[1]} if missing and missing[0] == table else set()))
        chunks.append(
            f"CREATE TABLE public.{table} (\n"
            + ",\n".join(f"    {column} text" for column in selected)
            + "\n);"
        )
    return "\n\n".join(chunks) + "\n"


class SchemaDumpValidatorTests(unittest.TestCase):
    def run_validator(self, content):
        with tempfile.TemporaryDirectory() as directory:
            dump = Path(directory) / "schema.sql"
            dump.write_text(content, encoding="utf-8")
            return subprocess.run(
                [sys.executable, str(SCRIPT), str(dump)],
                capture_output=True, text=True, check=False,
            )

    def test_accepts_all_required_catalog_columns(self):
        result = self.run_validator(make_dump())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("5 catalog tables", result.stdout)

    def test_rejects_missing_stream_urls_column(self):
        result = self.run_validator(make_dump(("movies", "stream_urls")))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("movies: missing required columns: stream_urls", result.stderr)

    def test_rejects_empty_dump(self):
        result = self.run_validator("")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing or empty", result.stderr)


if __name__ == "__main__":
    unittest.main()
