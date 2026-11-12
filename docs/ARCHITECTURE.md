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
scripts/npcs/        NPCManager, Social
scripts/data/        Resource classes (one per content type) and Db
scripts/player/      Player (first person), Character (the body in the menus)
scripts/apartment/   World, Apartment, Interactable, Holdable, Kit, FoodKit
scripts/town/        Town, TownPerson
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
| `Game.social` | Social | Colleagues: friendship tiers, telling on you, favours, small talk, gifts |
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
| `resources/npcs` | NpcDef | People: who they are, their voice, and for colleagues how readily they tell on you and which favours they do |
| `resources/tasks` | TaskDef | Tickets |
| `resources/balancing` | DifficultyDef | The four difficulties |
| `resources/text` | TextBankDef | Flavour lines |
| `resources/food` | FoodDef | Junk food: name, model, bites, energy, health, fullness, what it leaves |

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

## Colleagues

`NPCManager` keeps the numbers for every character; `Social` gives them
consequences for the ones whose `NpcDef` says `colleague = true`. Nothing in
either names a person.

- **Tiers.** `Social.tier(id)` reads the relationship as one of five
  `Social.Tier` values. `TIERS` holds, per tier, the multiplier on telling and
  on gossip (both zero from Friendly up).
- **Telling on you.** Everything that leaves a colleague hanging goes through
  one door, `Social.unanswered(id, how, declined)`: an expired prompt
  (`Comms._expire`), a call that rang out or was rejected (`Comms._miss`).
  It rolls `snitch_chance(id)` (the NpcDef's `snitch` times the tier
  multiplier), and on a hit raises suspicion and either has the manager say
  so or fires the `snitch_followup` event with `{who}` in its context.
- **Favours.** An NpcDef lists `favours`: `{id, type, tier, cost, ...}`.
  `favour_view()` says whether one can be asked (tier, favours owed, once a
  day) and `ask()` performs it. Types that are asked for: `ticket`, `bury`,
  `cover`, `vouch`, `intel`, `distract`, `skip_meeting`. Types that simply
  hold while the friendship does (`passive`): `tipoff` (the director calls
  `Social.tip_off` before any event with a `tip`), `wingman` (an extra answer
  in team meetings, added by `Comms.call_choices`), `hype` (daily praise).
- **Casual calls.** A meeting created for a caller of kind `coworker` or
  `stranger` is `casual`: no fatigue, the time is logged as slacking, the
  clone does not attend, and missing it goes to `Social.unanswered` instead
  of the manager. A stranger's call creates no facts for the deception
  engine; a colleague's does.

## Voices

`tools/gen_audio.py` synthesises three takes of gibberish per voice
(`assets/audio/voice_<id>_<n>.wav`): a sawtooth source through vowel
formants, syllable by syllable, with per-voice pitch, pace and melody, then
effects for the damaged lines (echo, ring modulation, bit crushing, stutter,
drop-outs). An NpcDef names its `voice`; a call can override it for everyone
(`meeting.voice_id`, e.g. Dave on a bad line) and a beat for one line
(`voice`). `Sfx.voice(id)` plays a take and returns its length, and the call
screen reveals the line's text over that time.

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
`not_flags`, `owns`, `tier_min`/`tier_max` (`{npc: tier}`), `ability`,
`susp_min/max`, `ill_min/max`, `absent_min`, `status`, `escalation_min`,
`claim`, `open_task`, `urgent_task`, `faked_task`.

A call event's `meeting` dictionary may set `voice` (audio only), `voice_id`,
`ask` (the caller asks by message first, and only rings if you agree),
`cast`, `private` and `casual`. The `weird` pool holds the strange calls: the
director places at most one a day, before the filler takes the gaps. An event
with a `tip` (`scan`, `call`, `screen`) is something a well-informed friend
warns you about: `EventDirector.upcoming_checks()` is what both the warnings
and the "what is Martin planning" favour read.

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
 tags: [...], req: {ability|favor|money|evidence|flag|tier},
 if: {conditions under which the choice exists at all},
 ok: {...}, ko: {...}}
```

Outcome keys: `susp`, `ill`, `hp`, `en`, `money`, `favor`, `rel`,
`rels {npc: delta}`, `cover`, `buff`, `flag`, `flags`, `say`, `end`, `task`,
`progress`, `give`, `claim`, `claim_status`, `fix_gadget`, `due_in`, `event`,
`later {in, ev}`, `call`, `call_in`, `block {title, dur}`, `boss_busy`,
`lose_task`, `intel`, `toast`, `stat`.

A dialogue beat may carry an `if` too: beats whose condition does not hold
are skipped, which is how a call branches on what was said a moment ago or
earlier in the week.

## Loose items

The rules for things you can pick up live in `Home`, like everything else
about the flat: `Home.items` is a list of dictionaries (`id`, `food`, `bites`,
`hot`, `trash`, `spot`, `at`), `Home.held` is the id in your hand, and
`eat`, `bin`, `hold`, `release`, `add_item` are the only ways they change.
Headless tests use exactly that. A `FoodDef` says what an item is; where it
turns up is a *spot name* (`"desk"`, `"doormat"`), which only the apartment
can turn into a position.

The view follows: `World._sync_items()` runs on `Bus.items_changed` and makes
the `Holdable` bodies match the list (spawn, refresh, remove, put the held one
in the hand). A `Holdable` is a `RigidBody3D` built by `FoodKit` from the
item's model id, with a slightly generous pick volume for the crosshair.
Positions are the view's business until a save, when they are written back
into `at`. What lies about each morning is drawn from its own random stream
(seeded from the run and the day), so it cannot change what else happens.

## The town

`Town.build(apartment)` adds the street to the Apartment node: geometry,
colliders, shop tills and other `Interactable`s (registered in
`apartment.things` like any object in the flat), named item spots, shelf
slots, bin and hoop triggers. Because it is the same node, one navigation
grid covers flat and street, joined by the front doorway.

The rules stay in the simulation and know nothing of the street's shape:

- `Home.SHOPS` says what each shop sells and when; `shop_stock(shop)` is the
  day's selection (its own dice, seeded by run, day and shop), `buy` takes
  the money and puts the item in your hand. `World._stock_shelves()` only
  shows that list: one model and one pick volume per shelf slot.
- `Home.pockets` is a list of item ids. A pocketed item has no body in the
  world; `_sync_items` skips it. `hold` pockets what was in the hand when it
  fits, `stow`, `draw`, `cycle` move things between hand and pockets.
- `Home.PROPS` are the objects that are not food: what a click does with
  one, whether it fits a pocket, whether it counts as an ornament.
- `Town.PEOPLE` lists who is about, where, and during which hours. A
  `TownPerson` is a `Character` with a pick volume; colleagues use the look
  from their `NpcDef`. Twice a second the world asks each colleague who is
  present whether the player is in front of them and close; if so it calls
  `Social.spotted(id)`, which decides (excused? once today? how likely is
  this person to tell?) and reuses the same path as an ignored message.

`ItemIcons` renders a small picture of each carried thing once, from the same
`FoodKit` model, in its own `SubViewport`; headless runs fall back to names.

## Views

- `World` owns what you see: lighting from the clock, the crosshair's ray
  (`_look_hits`: pick volumes, loose items first, nothing through a wall),
  the hand, and turning E and clicks into `Game.home.use(...)`. In the menus
  it switches to a second camera that looks at your character from outside.
- `Player` is a first-person `CharacterBody3D`: mouse look, WASD, a head that
  moves to seat height when you sit or lie, and a hand under the camera.
  It also has an autopilot (`go_to`, `face`) along the apartment's nav grid;
  only the tests and the scripted captures use it.
- `Apartment` builds meshes, colliders, pick volumes, named item spots, bin
  triggers and an `AStarGrid2D` procedurally. An `Interactable` only knows
  its `thing_id`.
- `Character` is a procedural rig with code-driven animation. In play it is
  hidden (you are inside it); the menus show it.
- The ink outline is one full-screen quad drawn after the scene, comparing
  depth and normals between neighbouring pixels. It can be switched off.
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
  tracking automatically and can be the `from` of any event. Set `colleague`
  and give them `favours` and they can be befriended and may tell on you.
- **A voice:** add an entry to `VOICES` in `tools/gen_audio.py` (and a case in
  `wreck()` if the line should sound damaged), run it, and name the voice on
  an NpcDef or a call.
- **A call:** an `EventDef` of kind `call` plus a `DialogueDef`. A schedule
  makes it part of someone's story; `pool = "weird"` makes it a strange call.
- **An apartment object:** add it to `Home.THINGS`, give it options in
  `Home.options()`/`use()`, and build its mesh in `apartment.gd`.
- **A junk food:** add a `FoodDef` and a model to `FoodKit` (a function that
  builds it from `Kit` primitives and says which parts vanish as it is
  eaten). `tests/harness/food_sheet.tscn` renders it next to the others.
- **An action:** declare it in `WorkSystem.DEFS` first. Undeclared ids are
  rejected with a warning.

After adding a `class_name`, run `tools/check.sh` (it re-imports so the class
cache is refreshed). `tools/validate.sh` checks every reference.

## Known limitations

- Tickets, prompts, meetings and mails are Dictionaries, not typed classes.
- One save version (5); older saves are rejected rather than migrated.
- People in the street do not collide with you or with each other, and walk
  fixed routes; cars are parked for good.
- The street is lit with real sun shadows; the flat is not (see `_update_sky`),
  so the two look slightly different through the open door.
- Held items are drawn in the world, not on a separate layer: pressed against
  a wall, what you are holding can poke into it.
- The windows are lit panes, not openings: there is nothing outside.
- Ambience is not positional.
- Text is English only and not routed through Godot's translation system.
- Keyboard and mouse only; no gamepad mapping or rebinding UI. Menus and the
  work computer are still mouse-driven 2D screens over the first-person view.
- Voices are gibberish. The text carries the meaning; nothing is lip-synced
  and the meter on the call screen follows a clock, not the audio.
- Colleagues exist in chat and on calls only: none of them visits the flat.
- The AI Doppelganger is the simplified version: it attends meetings, works
  one ticket and occasionally makes a decision for you. There is no clone
  storyline.
