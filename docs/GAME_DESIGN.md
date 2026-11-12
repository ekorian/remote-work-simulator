# Game design: what is in the slice

This describes the game as implemented. Numbers are in `scripts/core/config.gd`
and next to the system that uses them.

## The loop

A workday is 08:59 to 17:00 at 1.25 game minutes per real second (about 6.5
minutes), followed by a free evening that ends when you sleep. A run is five
days. Timed activities fast-forward the clock, so a typical run lands between
20 and 40 minutes.

The central tension: **the desk is where you defend yourself, and everywhere
else is where you recover.**

- At the desk you can answer messages, fake progress and manage gadgets, and you
  show as Available. But sitting there slowly drains Health, and every lie costs
  Energy.
- Away from the desk you restore Health and Energy, but your status turns Away
  within minutes, Suspicion climbs, and you may not even notice messages.

Everything else is a way to bend that trade-off.

## Resources

| | Falls | Rises |
| --- | --- | --- |
| Health | Real work, accepted responsibilities, each meeting question, time at the desk | Leisure, food, sleep |
| Energy | Lies, fake work, bureaucracy, walking, gadget upkeep | Food, coffee, naps, sleep |
| Suspicion | Convincing answers, real work, Illusion above 60 | Unexplained absence, ignored messages, missed meetings, failed lies, contradictions, gadget failures, failed scans, missed deadlines |
| Productivity Illusion | Time (faster when away), missed meetings and deadlines, failures | Fake updates, fake reports, emoji reactions, jargon, the Desk Bird, closed tickets |

Illusion saturates: the more impressive you already look, the less each fake
update adds, and the faster it fades. It has to be fed all week.

## Presence

Your status is computed every minute: Offline (router unplugged), Updating
(laptop), In a meeting, Focusing, Available (at the desk, recent input, a mug
on the spacebar, or a running Mouse Jiggler), At lunch (12:00 to 12:45, free
cover), otherwise Away. Away or Offline with no accepted story costs Suspicion
every minute, and after 45 minutes Todd asks where you are.

## Actions and their classes

Every action carries one class, shown as a badge wherever it is offered:

- **REAL WORK**: costs Health (2 / 8 / 20 by difficulty) and logs worked
  minutes. On Professional Unemployed it ends the run.
- **RESPONSIBILITY**: volunteering and accepting duties. Costs Health, never
  ends the run, usually hands you another ticket.
- **FAKE WORK**, **DELEGATE**, **DECEPTION**, **BUREAUCRACY**, **SOCIAL**,
  **LEISURE**, **UPKEEP**: all allowed, each with its own costs and risks.

## Deception

Nine excuses. Each has a base credibility, modified by current Suspicion and
Illusion, coffee jitters, exhaustion, outfit (on video), and how often you have
used it.

- **Evidence** makes an excuse much stronger: the router really unplugged, the
  laptop really updating, a printed doctor's note, a calendar block that covers
  the time, high Illusion for "deep work".
- **Verification**: outage excuses are checked by IT about 12 minutes later. If
  the router is still plugged in, that is a contradiction.
- **Wear**: every reuse costs credibility; a fourth use is an automatic
  contradiction.
- An accepted excuse grants **cover**: a period during which absence is
  explained and routine pings wait.
- Everything is logged in the Alibi Notebook (ShadowIT), and the Friday review
  is assembled from that record.

## Tickets

Each ticket shows two bars: what Todd sees and what exists.

- **Fake update** raises the visible bar. At 100% the ticket "looks done" and
  usually auto-closes at its deadline. Three or more updates make Todd ask for
  a live demo. If QA opens a faked ticket, it fails.
- **Request clarification** pushes the deadline a day (once per ticket).
- **Form 27-B** buries a ticket in a steering committee (one per day).
- **Favour**: a colleague does it properly. Favours come from covering for
  colleagues, or a gift card.
- **Delegatron** (gadget) does a ticket in the background, with a small chance
  of hallucinating.
- **Do the actual work** is always available, clearly marked, and hurts.

## Meetings and calls

Scheduled meetings ring at their start time; surprise calls come unannounced.
You can join (from the computer, or camera-off from the phone), decline through
a calendar conflict you created, send your LoopCam, make an excuse, or let it
ring out. Inside a call each question is timed; every answer is classified like
any other action, and silence is its own outcome. Friday's performance review
cannot be avoided.

## Gadgets

Bought at the gaming PC, new stock each day, managed from ShadowIT or the
keyboard. Running gadgets **wear** (worn gadgets fail far more often; servicing
costs Energy) and generate **Heat**, which is what SynerWatch scans look for.
Switch them off before a scan.

| Gadget | Effect |
| --- | --- |
| Mouse Jiggler 3000 | Status stays Available while you are away |
| Desk Bird Typist | Slowly raises Illusion |
| Wrist Buzzer | You notice messages and calls anywhere |
| Buzzword Generator Pro | Fake updates, reports and jargon cost no Energy |
| ReplyGuy Auto-Responder | Answers routine pings for you |
| Report-o-Matic | Sends the daily fake report at a time you choose |
| LoopCam Nodding Rig | Attends meetings for you (record a loop daily) |
| Delegatron AI Intern | Does one ticket in the background |
| AltTab Pro Fake Screen | Passes screen-share checks |

## The apartment

Every interactive object has a purpose:

| Room | Object | Purpose |
| --- | --- | --- |
| Office | Work Computer | SynerOS: Teams, Tasks, Calendar, Mail, ShadowIT |
| | Keyboard & Mouse | Wiggle to stay Available; switch and service gadgets |
| | Coffee Mug | A sip of Energy; wedge it on the spacebar to fake typing |
| | Company Laptop | Force an update (30 excused minutes); record the LoopCam loop |
| | Office Chair | Stage a busy desk; nap near the keyboard |
| | Gaming PC | The shop |
| | Printer | Forge a doctor's note (can jam) |
| | Router | Create a real outage: evidence, but you go dark |
| Living room | Sofa, Television, Console | Health and Energy; TV can inspire an excuse |
| | Bookshelf | Fluent in Buzzword: better jargon |
| | Exercise Bike | Health, clears jitters, cheaper actions for a while |
| Kitchen | Refrigerator, Microwave, Table | Food; limited stock per day |
| | Coffee Machine | Energy; refills the mug; too many cause jitters |
| Bedroom | Bed | Naps by day; sleep ends the evening |
| | Wardrobe | Outfit: a shirt helps on video, pajamas help you relax |
| | Phone Charger | Dock to charge; a docked phone cannot be answered |

## The week

Each day has scripted beats plus scheduled filler scaled by difficulty.

- **Monday**: onboarding, first tickets, standup, sprint planning, the timesheet.
- **Tuesday**: a phishing test, the calendar-conflict trick, a reply-all storm.
- **Wednesday**: a device scan, a production outage, compliance training,
  Mandatory Fun.
- **Thursday**: SynerWatch goes live (unannounced scans), the all-hands, a 1:1,
  a blackmail attempt.
- **Friday**: another scan, a demo demand, and the performance review.

## Winning and losing

- **Win**: reach Friday 17:00. Surviving is only a pass. The grade is made of
  **paid slacking**: minutes of leisure taken between 09:00 and 17:00. With zero
  real work, 8 hours of it over the week earns an A and 14 hours an S. Any real
  work caps the grade at B. This is what stops "sit at the desk all week" from
  being the best strategy: the desk keeps you safe, but only the sofa scores.
- **Fired**: Suspicion reaches 100.
- **Burnout**: Health reaches 0.
- **Disqualified**: any real work on Professional Unemployed.

## Not in the slice

Listed so nobody goes looking: multiple weeks or a campaign, promotions and
raises, more apartments, additional bosses, Steam features, localisation,
gamepad support, and accessibility options beyond volume and camera-shake.
