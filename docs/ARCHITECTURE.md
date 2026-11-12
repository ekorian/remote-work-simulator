# Architecture

Three layers with one dependency direction:

```
scripts/ui, scripts/apartment, scripts/player      views
                 |
                 v
scripts/core, simulation, deception,               simulation: rules + state,
        automation, events, npcs                   no scenes, no Controls
                 |
                 v
scripts/data  +  resources/*.tres                  static content
```

The simulation never references a scene, a Control or a Node3D. The UI and the
3D world are views over it. That is what lets test bots play whole weeks
headlessly through the same API the UI uses.

## Directory layout

```
scenes/          main.tscn plus one folder per area: main_menu, apartment,
                 player, workstation, ui, events
scripts/core/        GameManager, TimeManager, PlayerStats, EconomyManager,
                     SaveManager, Bus, Cfg, audio, prefs, main (screen flow)
scripts/simulation/  WorkSystem, Comms, Home, Presence, Activities
scripts/deception/   DeceptionManager, Claim
scripts/automation/  AutomationManager
scripts/events/      EventDirector, Dialogue, Tutorial
scripts/npcs/        NPCManager
scripts/data/        Resource classes (one per content type) and Db
scripts/player/      Player, Character, CameraRig
scripts/apartment/   World, Apartment, Interactable, Kit
scripts/ui/          HUD, SynerOS desktop, dialogs, menus, shared widgets
resources/           all authored content, as .tres
tests/               headless tests and the screenshot/autoplay harness
tools/               setup, validation, tests, screenshots, audio generation
```

## The systems

`Game` (GameManager) is the composition root: it creates one instance of each
system as a child node and exposes it as a typed member.

| Access | Class | Responsibility |
| --- | --- | --- |
| `Game` | GameManager | Run lifecycle, difficulty, day flow, victory and loss, run statistics |
| `Game.time` | TimeManager | Simulated clock, calendar position, time advancement, timers |
| `Game.stats` | PlayerStats | Health, energy, suspicion, productivity illusion, buffs |
| `Game.economy` | EconomyManager | Money, salary and bonuses, prices, favours |
| `Game.work` | WorkSystem | Work classification and penalties; tickets and deadlines |
| `Game.deception` | DeceptionManager | Claims, facts, evidence, contradictions |
| `Game.automation` | AutomationManager | Gadgets, levels, reliability, heat, combinations |
| `Game.events` | EventDirector | Scheduling, conditions, pacing, firing events |
| `Game.npcs` | NPCManager | Relationship, mood, knowledge, escalation per person |
| `Game.saves` | SaveManager | Save slots, versioning |
| `Game.presence` | Presence | Online status; whether an absence is explained |
| `Game.activities` | Activities | The timed activity in progress |
| `Game.home` | Home | What each apartment object does; state of the flat |
| `Game.comms` | Comms | Threads, prompts, mail, calendar, meetings, live calls |
| `Game.tutor` | Tutorial | Per-day checklist and one-off hints |

Every system extends `GameSystem` and implements `setup_run()`, `new_day()`,
`save_state()` and `load_state()`.

### Autoloads

There are four, each because it must exist before any scene does:

- `Game`: the simulation root described above.
- `Bus`: signals that cross from the simulation to the views (toasts, "a
  prompt arrived", "an activity started"). It holds no state.
- `Sfx` and `Prefs`: audio and player settings, needed by the menus before a
  run exists.

Everything else is reached through `Game` or is a static class (`Cfg`, `Db`,
`UI`, `Kit`, `Dialogue`).

### State and saving

Each system owns its own state as members. There is no shared state object.
`Game.save_state()` asks every system for its slice and adds a version number;
`SaveManager` writes the result with Godot's binary Variant format (objects
disabled), so ints stay ints. `Game.load_state()` refuses a save whose version
does not match rather than half-loading it.

State is a mix of typed classes and plain collections. Claims are a typed
class (`Claim`) because the engine reasons about them; tickets, prompts,
meetings and mails are Dictionaries in typed systems. Converting those to
classes is a mechanical follow-up, not a redesign.

### Static content is Resources

Everything authored lives under `resources/` as `.tres` files of the classes
in `scripts/data/`:

| Folder | Class | Content |
| --- | --- | --- |
| `resources/events` | EventDef | Messages, mails, meetings, calls, system events |
| `resources/dialogue` | DialogueDef | Meeting and call scripts |
| `resources/deception` | ClaimDef | The ten excuse categories |
| `resources/gadgets` | GadgetDef | Gadgets and their levels |
| `resources/gadgets/combos` | ComboDef | Gadget combinations |
| `resources/npcs` | NpcDef | People |
| `resources/tasks` | TaskDef | Tickets |
| `resources/balancing` | DifficultyDef | The four difficulties |
| `resources/text` | TextBankDef | Flavour lines |

`Db.load_all()` reads them once into dictionaries keyed by id. The files are
the source of truth and can be edited in the Godot inspector or as text.
`tests/rules_test` loads every one and checks every id they reference.

### The clock

`TimeManager.tick()` is one game minute, in a fixed order: presence, passive
stat drift, the current activity, buffs, due timers, then `minute_passed`
(which the other systems listen to), then the end-of-day check. In play,
`_process` calls it at `Cfg.MIN_PER_SEC` times `speed`. Tests set
`Game.time.manual` and call `advance(n)`. Because everything is driven by the
minute tick, the simulation is identical at any speed.

### Work classification: one place

`WorkSystem.DEFS` declares every player action with a class (`WORK`, `STRESS`,
`FAKE`, `DELEGATE`, `AUTOMATE`, `DECEIVE`, `BUREAU`, `SOCIAL`, `LEISURE`,
`UPKEEP`, `NEUTRAL`). Gameplay code never applies a work penalty itself:

```gdscript
if not Game.work.perform("fake_update", ctx):
    return
```

`perform` handles the energy cost, the health penalty, the worked-minutes log
and the Professional Unemployed instant loss. `badge(id)` is what every button
uses to label itself, so "REAL WORK" looks the same everywhere. The tests
assert that every `WORK` action ends an Extreme run and that no other action
does.

## The deception engine

1. **Claims.** `Game.deception.attempt(type, context, listener, ...)` rolls
   credibility and appends a `Claim` to the ledger: id, type, subject,
   timestamp, expiry, witnesses, contradicting facts, evidence, risk, status.
   Witnesses are recorded in `NPCManager` as things that person knows.
2. **Facts.** Systems report what the player visibly does:
   `Game.deception.observe("video_meeting")`. The fact vocabulary is
   `DeceptionManager.FACTS`. Status ("you show as Available") is observed
   every minute.
3. **Contradictions.** A fact listed in a live claim's `contradicted_by`
   marks it contradicted, raises suspicion, costs the witness's trust, and
   schedules a confrontation prompt built from the claim type's `exposed`
   line and `recoveries`.
4. **Verification.** Claim types can schedule `followups`: `verify` (someone
   checks a fact after a delay; the outcome depends on what is true then) or
   `event` (a follow-up event, such as being asked for the doctor's note).
5. **Evidence.** `has_evidence(id)` reads the state of the world (router
   unplugged, calendar block, form filed). Evidence raises credibility and
   makes verification pass.

A claim that expires or is verified without being caught counts as a
successful deception.

## Automation

A gadget level lists abilities in `can` (`presence`, `illusion`, `auto_reply`,
`auto_updates`, `auto_report`, `meeting_answers`, `auto_answer`,
`attend_meetings`, `do_tickets`, `screen_fake`, `free_jargon`, `pass_scan`,
`autonomous`). Other systems ask `Game.automation.can("auto_reply")` and never
name a gadget, so adding one is adding a resource file. Combinations
(`ComboDef`) contribute named modifiers read with `effect(key)`.

Reliability is rolled per use (or every half hour for continuous gadgets) and
scaled by wear. A failure breaks the gadget and fires its `fail_event`.

## Events

An `EventDef` says how it can happen:

- `schedule`: fixed slots `[{day, at}]`, optionally with `chance` or `diffs`.
- `pool`: filler the director draws from each morning (`boss`, `peer`, `call`).
- `trigger`: `state` (checked every minute against `conditions`) or
  `call_join` (may inject dialogue beats when a call starts).
- Otherwise it only fires when something calls `Game.events.fire(id, ctx)`:
  a choice outcome, a claim follow-up, a gadget failure.

`conditions` keys: `day_min`, `day_max`, `from`, `to`, `flag`, `not_flag`,
`owns`, `ability`, `susp_min/max`, `ill_min/max`, `absent_min`, `status`,
`escalation_min`, `claim`, `open_task`, `urgent_task`, `faked_task`.

Pacing (`can_interrupt`): nothing interrupts a call; two calls never ring at
once; a conversation with a pending prompt gets no second one; at most three
prompts wait at a time; filler respects a minimum gap. A blocked event is
deferred and retried, not dropped.

### Choice format

Used by chat events, mails, dialogue beats and claim recoveries, and resolved
in one place (`Comms.resolve`):

```
{t: text, a: action id,
 p: base % for a bluff roll | ability: gadget ability to roll |
 evidence: id (succeeds only if true) | match: subject (memory check),
 tags: [...], req: {ability|favor|money|evidence},
 ok: {...}, ko: {...}}
```

Outcome keys: `susp`, `ill`, `hp`, `en`, `money`, `favor`, `rel`, `cover`,
`buff`, `flag`, `say`, `end`, `task`, `progress`, `give`, `claim`,
`claim_status`, `fix_gadget`, `due_in`, `event`, `later {in, ev}`, `stat`.

## Views

- `World` instantiates the apartment, player and camera from scenes, drives
  lighting from the clock, and turns clicks into `Game.home.use(...)`.
- `Apartment` builds meshes, colliders, pick volumes and an `AStarGrid2D`
  procedurally. An `Interactable` only knows its `thing_id`.
- `Character` is a procedural rig with code-driven animation.
- UI is built in code from the helpers in `ui.gd`; each screen is a scene
  with one script. `main.gd` owns the screen flow and decides who has input
  and whether the clock runs.

## Decisions worth knowing

- **Procedural art and audio.** No imported models, textures or samples. It
  keeps the slice free of licensing questions and makes the look consistent;
  `Kit` and `tools/gen_audio.py` are the places to replace when real assets
  arrive.
- **UI in code, not hand-edited scenes.** Scenes exist per screen, but the
  node trees are built by their scripts. Layout lives next to the logic that
  fills it, and can be regenerated; the cost is that the editor shows an
  empty root for those scenes.
- **Explicit pacing over emergent pacing.** The director refuses and defers
  events rather than letting systems fire freely, so "no two interruptions
  at once" is a rule that is tested, not a hope.
- **One suspicion number.** Management suspicion is the Suspicion resource.
  NPCs add relationship, mood and knowledge on top rather than each holding
  a separate hidden meter the player cannot read.

## Adding content

- **An event:** add an `EventDef` resource. Give it a `schedule`, a `pool` or
  a `trigger`. Nothing else needs to change.
- **A gadget:** add a `GadgetDef` with levels and abilities, and a failure
  event. For a new ability, read it where it applies with
  `Game.automation.can(...)`.
- **An excuse category:** add a `ClaimDef`. For new evidence, add a case to
  `DeceptionManager.has_evidence`; for a new fact, add it to `FACTS` and
  call `observe` where it happens.
- **A character:** add an `NpcDef`. They get relationship, mood and knowledge
  tracking automatically and can be the `from` of any event.
- **An apartment object:** add it to `Home.THINGS`, give it options in
  `Home.options()`/`use()`, and build its mesh in `apartment.gd`.
- **An action:** declare it in `WorkSystem.DEFS` first. Undeclared ids are
  rejected with a warning.

After adding a `class_name`, run `tools/check.sh` (it re-imports so the class
cache is refreshed). `tools/validate.sh` checks every reference.

## Known limitations

- Tickets, prompts, meetings and mails are Dictionaries, not typed classes.
- One save version; older saves are rejected rather than migrated.
- Ambience is not positional.
- Text is English only and not routed through Godot's translation system.
- Keyboard and mouse only; no gamepad mapping or rebinding UI.
- The AI Doppelganger is the simplified version: it attends meetings, works
  one ticket and occasionally makes a decision for you. There is no clone
  storyline.
