# Korean readings of kanji (Unihan)

| | |
|---|---|
| Data | Unicode Han Database (Unihan) 18.0.0: `kHangul`, `kJoyoKanji`, `kJinmeiyoKanji`, `kJapaneseOldVariant`, `kTraditionalVariant`, `kSemanticVariant`, `kZVariant` |
| Source | https://www.unicode.org/Public/18.0.0/ucd/Unihan.zip (sha256 `4c93ea9c1f636451729a840978f1667a53886af37ba854fdcce109721c63d43e`) |
| License | Unicode License v3 (`LICENSE`, from https://www.unicode.org/license.txt) |

`tools/extract/build_extract_data.py` keeps the Joyo and Jinmeiyo kanji and writes their Korean
readings to `packages/core/lib/src/extract/data/hanja_readings.dart`. A Japanese simplified form
without a `kHangul` value takes the readings of its old or traditional form (験 → 驗 → 험).
The zip itself is not committed (the script downloads it into `tools/extract/.cache/`).
An app that ships the extractor must show this notice and the license in its about screen.
