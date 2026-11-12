# Architecture

The project is split into three layers with a strict dependency direction:

```
scripts/ui  ─┐
             ├──>  scripts/core   (autoloads: rules + state, no scenes)
scripts/world┘
```

`core` never references a scene, a Control or a Node3D. The UI and the 3D world
are views over it. That is what lets the whole game be played headlessly by the
test bots.

## State

The entire run lives in one plain Dictionary, `Game.s`. Every system reads and
writes its own keys in it (`s.tasks`, `s.prompts`, `s.gadgets`, `s.things`, ...).

- Saving is one call: `SaveSys.save()` writes `Game.s` with Godot's binary
  Variant format (objects disabled), so ints stay ints and floats stay floats.
- Loading replaces `Game.s` and emits `Bus.state_loaded`; views rebuild from it.
- Nothing transient may hold gameplay state. If it matters after a reload, it
  belongs in `Game.s`.

## Autoloads (`scripts/core`)

| Autoload | File | Owns |
| --- | --- | --- |
| `Cfg` | `config.gd` | Tuning constants, difficulty table, input actions |
| `Bus` | `bus.gd` | Global signals between core, world and UI |
| `Content` | `content.gd` | All authored data: people, tickets, pings, mail, calls, the week |
| `Game` | `game.gd` | Run lifecycle, clock, the four resources, presence, activities, day flow |
| `Actions` | `actions.gd` | The action catalogue and the work classification |
| `Deception` | `deception.gd` | Excuses, the ledger, credibility maths, contradiction checks |
| `Interact` | `interact.gd` | What every apartment object does |
| `Auto` | `automation.gd` | Gadgets: shop, wear, failures, heat |
| `Corp` | `corp.gd` | Threads, prompts, tickets, calendar, calls, mail |
| `Director` | `director.gd` | Schedules the day and reacts to how you are doing |
| `SaveSys` | `save_system.gd` | Save slots |
| `Sfx` | `audio.gd` | Sound effects, loops, music |
| `Prefs` | `prefs.gd` | Player settings |
| `Tutor` | `tutor.gd` | Tutorial checklist and one-off hints |

### The clock

`Game.tick()` advances one game minute: presence, passive drains, the current
activity, buffs, then `minute_passed`, which every other system listens to.
In normal play `_process` calls it at `Cfg.MIN_PER_SEC` times `Game.speed`.
Tests set `Game.manual = true` and call `Game.advance(n)`. Because everything
is driven by the minute tick, the simulation is identical at any speed.

### Resources: one write path

Health, Energy, Suspicion and Productivity Illusion are only ever changed by
`Game.add(stat, delta, reason)`. It applies difficulty multipliers, clamps,
records statistics, emits `stat_changed`, and ends the run at 0 health or 100
suspicion. Data-driven effect bundles go through `Game.apply_fx()`.

### Work classification: one place

`Actions.DEFS` declares every player action with a class (`WORK`, `STRESS`,
`FAKE`, `DELEGATE`, `DECEIVE`, `BUREAU`, `SOCIAL`, `LEISURE`, `UPKEEP`,
`NEUTRAL`). Gameplay code never applies a work penalty itself. It calls

```gdscript
if not Actions.perform("fake_update", ctx):
    return
```

and `perform` handles the energy cost, the health penalty, the worked-minutes
log, and the Professional Unemployed instant loss. `Actions.badge(id)` is what
every button uses to label itself, so "REAL WORK" looks the same everywhere.
`tests/sim_test.gd` asserts that every `WORK` action ends an Unemployed run and
that no other action does.

### Choices

Chat prompts, mail and call questions all use one choice format, documented at
the top of `content.gd`, and one resolver, `Corp.resolve()`. A choice names an
action id, an optional bluff chance or gadget roll, requirements, and `ok`/`ko`
outcome bundles.

## World (`scripts/world`)

- `kit.gd`: primitive builders (boxes, low-poly cylinders and spheres with
  flat shading), cached materials.
- `apartment.gd`: builds the flat, colliders, mouse-pick volumes and an
  `AStarGrid2D` navigation grid. Props are modelled facing +Z, then rotated.
- `interactable.gd`: one usable object: where to stand, where to sit, the
  highlight overlay. It only knows its `thing_id`; behaviour is in `Interact`.
- `character.gd`: the procedural character and all its animations.
- `player.gd`: movement, path following, sitting.
- `camera_rig.gd`: orthographic isometric camera.
- `world.gd`: lighting by time of day, cutaway walls, live prop visuals
  (router LEDs, jiggler, screens), and the interaction flow.

## UI (`scripts/ui`)

Everything is built in code from the helpers in `ui.gd`. There are no hand-edited
scene files beyond the one-node roots.

- `hud.gd`: clock, resources, inbox, tutorial card, prompts, toasts.
- `desktop.gd`: SynerOS and its five apps.
- `choices.gd`: the shared answer list, including the excuse picker.
- `overlays.gd`: ring dialog, call screen, phone, shop.
- `screens.gd`: main menu, new game, pause, day report, results.
- `main.gd` owns the screen flow and decides who has input and whether the
  clock runs (`_refresh()`).

## Adding content

- **A ping, mail or call**: add an entry to `Content.PINGS`, `MAILS` or `CALLS`,
  then schedule it in `Content.WEEK_EVENTS` / `WEEK_MEETINGS` or add its id to
  the pools in `director.gd`. The content test checks every action id, ticket
  id and gadget id you reference, and that the prompt can be answered without
  real work.
- **A gadget**: add it to `Auto.GADGETS` and `Auto.ORDER`, then give it an
  effect where it applies (see how `replyguy` or `fakescreen` are used).
- **An apartment object**: add it to `Interact.THINGS`, give it options in
  `Interact.options()`/`use()`, and build its mesh in `apartment.gd` with
  `_thing()`. `tests/world_test` verifies it is reachable.
- **A new action**: declare it in `Actions.DEFS` first. Undeclared ids are
  rejected with a warning.

After adding a `class_name`, run `tools/check.sh` (it re-imports so the class
cache is refreshed).

## Known limitations of the slice

- One save format version; no migration yet.
- Ambience is not positional.
- Text is English only and not yet routed through Godot's translation system.
- Keyboard and mouse only; no gamepad mapping or rebinding UI.
