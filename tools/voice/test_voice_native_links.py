"""Archive links that only leave their folder through another link, and a member that
would write through a link made before it, are refused (tools/voice/voice_native.py)."""
from __future__ import annotations

import io
import stat
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import voice_native  # noqa: E402
from voice_sources import SourceError  # noqa: E402


def _zip(entries: list[tuple[str, bytes | str, bool]]) -> Path:
    """A zip of (name, content, is_link) entries in this order, in a temporary file."""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as z:
        for name, content, is_link in entries:
            if is_link:
                info = zipfile.ZipInfo(name)
                info.create_system = 3
                info.external_attr = (stat.S_IFLNK | 0o755) << 16
                z.writestr(info, content)
            else:
                z.writestr(name, content)
    path = Path(tempfile.mkdtemp()) / "a.zip"
    path.write_bytes(buf.getvalue())
    return path


class LinkChainTest(unittest.TestCase):
    def setUp(self) -> None:
        self.base = Path(tempfile.mkdtemp())
        self.into = self.base / "unpack"
        self.into.mkdir()

    def test_a_chain_of_links_that_leaves_the_folder_is_refused(self) -> None:
        archive = _zip([
            ("top/s", ".", True),
            ("top/e", "s/..", True),
            ("top/f", "e/..", True),
            ("top/g", "f/..", True),
        ])
        with self.assertRaises(SourceError):
            voice_native._unzip_folder(archive, "top", self.into)

    def test_a_file_member_does_not_write_through_an_earlier_link(self) -> None:
        archive = _zip([
            ("top/h", "other", True),
            ("top/h", b"written", False),
        ])
        with self.assertRaises(SourceError):
            voice_native._unzip_folder(archive, "top", self.into)
        self.assertFalse((self.into / "top" / "other").exists())

    def test_links_inside_the_folder_still_work(self) -> None:
        archive = _zip([
            ("top/Versions/A/lib", b"binary", False),
            ("top/Versions/Current", "A", True),
            ("top/lib", "Versions/Current/lib", True),
        ])
        out = voice_native._unzip_folder(archive, "top", self.into)
        self.assertEqual((out / "lib").read_bytes(), b"binary")


if __name__ == "__main__":
    unittest.main()
