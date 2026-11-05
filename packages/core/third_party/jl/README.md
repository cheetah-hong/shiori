# Deconjugation rules (JL)

| | |
|---|---|
| File | `deconjugation_rules.json`, unchanged |
| Source | https://github.com/rampaa/JL/blob/d8011e289eb4cd265fd4e3beb3fd155e8a764004/JL.Core/Resources/deconjugation_rules.json |
| Project | JL, https://github.com/rampaa/JL (commit `d8011e289eb4cd265fd4e3beb3fd155e8a764004`, fetched 2026-11-05) |
| License | Apache License 2.0 (`LICENSE`, copied from the same commit) |
| Origin | JL credits Nazeka (https://github.com/wareya/nazeka, Apache License 2.0) for its deconjugation rules |

The rules are compiled into `packages/core/lib/src/extract/data/deconjugation_rules.dart` as a raw
string by `tools/extract/build_extract_data.py`; the Dart deconjugator that reads them is written
for this project (`packages/core/lib/src/extract/deconjugator.dart`). No code was copied.
An app that ships the extractor must show this notice and the license in its about screen.
