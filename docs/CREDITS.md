# Credits and licences

Everything shipped with the game is listed here with its origin and terms.
Add an entry before adding any third-party file.

## Third-party

| What | Where | Licence | Attribution required |
| --- | --- | --- | --- |
| Fredoka (variable font) | `assets/fonts/Fredoka.ttf` | SIL Open Font License 1.1 (`assets/fonts/Fredoka-OFL.txt`) | Keep the licence file with the font. Copyright 2016 The Fredoka Project Authors. |
| Inter (variable font) | `assets/fonts/Inter.ttf` | SIL Open Font License 1.1 (`assets/fonts/Inter-OFL.txt`) | Keep the licence file with the font. Copyright 2020 The Inter Project Authors. |
| Godot Engine 4.7 | not in the repository; fetched by `tools/setup_godot.sh` | MIT | Exported builds must include Godot's licence text and its third-party notices (see the Godot documentation, "Complying with licenses"). |

Both fonts were downloaded from the Google Fonts repository
(`github.com/google/fonts`, `ofl/fredoka` and `ofl/inter`).

## Original to this project

| What | Where | How it was made |
| --- | --- | --- |
| All 3D models | built at runtime by `scripts/apartment/` and `scripts/player/character.gd` | Procedural geometry from primitives |
| All icons | `scripts/ui/icon.gd` | Drawn in code |
| All sound effects, ambience and music | `assets/audio/*.wav` | Synthesised by `tools/gen_audio.py`; no samples |
| All voices | `assets/audio/voice_*.wav` | Formant synthesis in `tools/gen_audio.py`: generated gibberish, not recordings of anyone and not derived from any voice model |
| All writing, names and UI | `resources/`, `scripts/ui/` | Written for this project |

SynerCorp, its staff and its products are fictional. The corporate desktop
(SynerOS, SynerTeams, SynerTasks, SynerCalendar, SynerMail) is an original
design; it does not use artwork, layouts or trademarks from any real product.

## Not yet cleared for release

Nothing. If this list is ever non-empty, the build is not shippable.
