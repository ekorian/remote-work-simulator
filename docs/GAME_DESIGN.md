# Game design: what is in the slice

This describes the game as implemented. Numbers live in `scripts/core/config.gd`
and in the resources under `resources/`.

## How you see it

First person, from inside the flat: four rooms with full-height walls, doorways
between them, a ceiling, curtains and pictures. You look with the mouse and walk
with WASD. A dot in the middle of the screen is your reach (about two metres):
put it on an object and its name and what it does appear; E or a click uses it.
Sitting and lying move your eyes to where your head would be, and you can
still look around from the sofa. The work computer, the phone and calls are
flat screens over the view, and the mouse becomes a pointer while they are up.

The look is a cartoon family home: saturated colours, chunky low-poly
furniture, soft lighting, and a dark ink line around everything.

## The loop

A workday is 08:59 to 17:00 at 1.25 game minutes per real second (about 6.5
minutes), followed by a free evening that ends when you sleep. A run is five
days. Timed activities fast-forward the clock, so a run lands between 20 and
40 minutes.

The central tension: **the desk is where you defend yourself, and everywhere
else is where you recover.**

- At the desk you can answer messages, fake progress and manage gadgets, and
  you show as Available. But sitting there slowly drains Health, and every lie
  costs Energy.
- Away from the desk you restore Health and Energy, but your status turns Away
  within minutes, Suspicion climbs, and you may not even notice messages.

Everything else is a way to bend that trade-off: lies explain an absence,
gadgets fake a presence, bureaucracy and favours make work disappear.

## Resources

| | Falls | Rises |
| --- | --- | --- |
| Health | Real work, accepted responsibilities, each meeting question, time at the desk | Leisure, food, sleep |
| Energy | Lies, fake work, bureaucracy, walking, gadget upkeep | Food, coffee, naps, sleep |
| Suspicion | Convincing answers, stories that check out, real work, Illusion above 60, a friend vouching for you | Unexplained absence, ignored messages, missed meetings, failed lies, contradictions, gadget failures, failed scans, missed deadlines, a colleague telling Martin you can't be reached |
| Productivity Illusion | Time (faster when away), missed meetings and deadlines, failures | Fake updates, fake reports, emoji reactions, jargon, the Keyboard Duck, closed tickets |

Illusion saturates: the more impressive you already look, the less each fake
update adds and the faster it fades. Suspicion has a floor of 12 that looking
busy cannot get under.

## Difficulty

| | Suspicion | Work costs | Also |
| --- | --- | --- | --- |
| Intern | x0.6 | 2 HP | Forgiving boss, long reaction windows, generous recovery, cheaper gadgets |
| Corporate Survivor | x1.0 | 8 HP | The intended experience |
| Senior Bullshitter | x1.7 | 20 HP | More frequent checks, less reliable gadgets, harder lies |
| Professional Unemployed | x1.5 | run over | Any legitimate work action ends the run |

## Actions and their classes

Every action carries one class, shown as a badge wherever it is offered:

- **REAL WORK** costs Health and logs worked minutes. On Professional
  Unemployed it ends the run.
- **RESPONSIBILITY** (volunteering, accepting duties) costs Health, never ends
  the run, and usually hands you another ticket.
- **FAKE WORK**, **DELEGATE**, **AUTOMATION**, **DECEPTION**, **BUREAUCRACY**,
  **SOCIAL**, **LEISURE**, **UPKEEP** are all allowed, each with its own costs
  and risks.

The distinction the game enforces: writing a real report is work, generating a
fake one is not; fixing the bug is work, pretending to investigate is not;
doing the ticket is work, handing it to a colleague or an AI clone is not.

## Deception

Every lie is remembered. Telling one creates a **claim** in the Alibi Ledger
(ShadowIT on the work computer), and while it is active the game watches what
you do.

**Example.** At 10:00 you tell Martin your internet is down. The claim is on
record for an hour: you must not appear Available, send anything from your
work computer, or join a call on camera. IT pings your router about twelve
minutes later. If you join the 10:15 meeting on video, the game detects the
contradiction: Suspicion rises, Martin trusts you less, and a few minutes
later he asks, "You're on camera. In HD. I thought your internet wasn't
working?" You then have to explain: "It just came back", "I'm tethering", or
come clean. Joining from your phone would have been fine.

Each of the ten categories has its own evidence, weak points and follow-up:

| Category | Stronger with | Exposed by | May lead to |
| --- | --- | --- | --- |
| Internet outage | Router unplugged; a reported outage | Anything your computer does online; IT pinging the router | |
| Computer crash | Laptop really updating | Posting, ticket updates, gadgets, video | IT opening a remote session |
| Medical appointment | Doctor's note; calendar block | Showing as Available, desk activity | HR asking for the note |
| Family emergency | | Cheerful chat in channels, video calls | Martin asking who it was (you must remember) |
| Conflicting meeting | Calendar block over the time | Martin checking your calendar | Being asked for the notes |
| Production incident | A real incident in progress | Nobody else knowing about it | Being asked to write the postmortem |
| Data validation | Looking busy | Hard to disprove | Being asked for the results |
| Waiting for another team | A clarification request on the ticket | That team denying it; touching the ticket | A call to "unblock" you |
| Corporate process blocker | A Form 27-B on file | No paperwork; touching the ticket | Martin "expediting" the approval |
| Hardware malfunction | A jammed printer | Joining any call on camera for five hours | An IT hardware diagnostic (a scan) |

Rules that apply to all of them:

- Credibility depends on Suspicion, Illusion, the listener's trust in you,
  evidence, your outfit on video, coffee jitters, and how often you have used
  that story. A fourth use backfires by itself.
- Two stories that cannot both be true (at the doctor *and* firefighting an
  incident) are caught the moment the second is told to someone who heard the
  first. Colleagues gossip, so a story told to Kevin can reach Martin.
- An accepted story gives **cover**: your absence is explained while it lasts.
- A story that expires or is verified without incident counts as a successful
  deception. From Wednesday, Martin checks far more of what he is told.

## Junk food

Every morning there is junk food lying about the flat: on the desk, the coffee
table, the kitchen counter, the nightstand. Nobody remembers buying it.

- **38 kinds** in five groups: sweet (donut, cookie, chocolate bar, cupcake,
  cake, pretzel...), frozen (cone, tub, ice lolly, pudding), crunchy (crisps,
  popcorn, nachos, dry cereal, onion rings), hot (pizza, burger, hot dog,
  fries, nuggets, taco, burrito, toastie, drumsticks, corn dog, noodles,
  pancakes, waffle) and drinks (cola, energy drink, large soda, milkshake,
  chocolate milk). Each has its own model.
- **You hold one thing at a time.** E picks it up, right click sets it down
  where you are looking, Q throws it. It goes where you go: to the sofa, to
  the desk, into a meeting.
- **A click is a bite.** Each bite gives a share of the item's Energy (and for
  comfort food a little Health), and the model shrinks: fries leave the
  carton one by one, slices leave the box.
- **Your stomach has a limit.** Every bite fills you up; past the limit you
  cannot eat, and near it you are Stuffed and walk slower. It settles with
  time. A whole pizza is more than one sitting.
- **The fridge** hands out cold things (three a day, shared with eating at the
  fridge). **The microwave** heats what you are holding if it is the kind of
  thing that should be hot: 40% more from every bite. An **energy drink**
  counts as a coffee, jitters included.
- **A pizza** can be ordered at the Gaming PC: eight slices on the doormat
  twenty minutes later, once a day.
- **What is left** is a wrapper, a can, a box. Carry it to the kitchen bin or
  throw it at one (there is a recycling bin in the office): a little Health
  for tidying, and for a long shot. Rubbish still lying about when you wake up
  costs Health, up to five points.
- What you carried off is replaced the next morning; what you left untouched
  is still there, so the flat never offers more than five new things a day.

Two toys live on the desk: a stress ball (squeezing it helps, a little, a few
times a day) and a rubber duck (it squeaks).

## Tickets

Each ticket shows what Martin sees and what exists.

- **Fake update** raises the visible bar. At 100% it "looks done" and usually
  auto-closes at the deadline. Three or more make Martin ask for a demo.
- **Tell Martin it's blocked** attaches a story to the ticket (another team,
  process, data validation, an incident) and buys time. Touching the ticket
  afterwards contradicts it.
- **Clarification request** and **Form 27-B** are paperwork: they are the
  evidence that makes those stories check out. The form may also bury the
  ticket for good.
- **Favour**: a colleague does it. Priya is fast and flawless, Kevin is quick
  and cuts corners, Dave is slow, and Gerald can make the ticket stop existing.
  Favours come from covering for colleagues, from their calls, or a gift card.
- **AI Doppelganger** (level 2) works one ticket in the background.
- **Do the actual work** is always available, clearly marked, and hurts.

## Meetings and calls

Scheduled meetings ring at their start time; surprise calls come unannounced.
You can join from the computer or (camera off) from the phone, decline through
a calendar conflict you created, send your clone, make an excuse, or let it
ring out. Inside a call each question is timed; every answer is classified
like any other action, and silence is its own outcome. Friday's performance
review cannot be avoided, and its questions are built from your week.

Calls from colleagues and from unknown numbers are a different thing: see
"Colleagues" and "Strange calls" below.

## Automation

Bought at the gaming PC, managed from ShadowIT or the keyboard. Each gadget
has three levels, a reliability, a Heat (how visible it is to a SynerWatch
scan), and a failure with its own consequences. Running gadgets wear, worn
gadgets fail, and servicing costs Energy.

| Gadget | Does | Level 2 | Level 3 | When it fails |
| --- | --- | --- | --- | --- |
| MouseMover.exe (Tue) | Keeps your status Available | More reliable, less Heat | Passes activity scans | IT notices the identical circles and asks |
| Keyboard Duck (Tue) | Slowly raises Illusion | Fake code window passes screen checks | Fake work costs no Energy | It posts gibberish to the team channel |
| Chatbot Team (Wed) | Answers routine messages | Posts fictional ticket updates | Sends the daily report | It invents a project and a customer |
| Meeting Assistant (Thu) | Offers to answer meeting questions | Steps in when you freeze | More reliable | It answers with something absurd |
| AI Doppelganger (Thu) | Attends optional meetings | Works a ticket | More reliable, more independent | It melts down on camera |

The Doppelganger needs the Chatbot Team and the Meeting Assistant first. It is
autonomous: now and then it decides something on your behalf (volunteers you,
asks for a raise, approves a pull request).

**Combinations** switch on when both gadgets run:

- **Ghost Shift** (MouseMover + Chatbot Team): routine messages are answered
  at once and never reach you. More Heat.
- **Desk Theatre** (MouseMover + Keyboard Duck): less Heat, more fragile.
- **Empty Chair** (Meeting Assistant + Doppelganger): the clone can attend
  mandatory meetings. Much higher risk of it going off-script.

Gadgets also create facts. A chatbot answering while your "internet is down"
contradicts you.

## Martin, and everyone else

Martin is corporate, slightly incompetent, obsessed with productivity and fond
of meetings. The game tracks, for him and for every other character:

- **Relationship**: rises when you help or flatter, falls when you are caught
  or ignore them.
- **Mood** (pleased to furious): shown in SynerTeams; it shifts how readily
  they believe you.
- **Knowledge**: which of your claims they have heard.
- **Caught count**: how often they have seen a story fall apart.

Martin additionally has an **escalation state** driven by Suspicion: Unbothered,
Keeping an eye on you, Micromanaging (hourly status lines), Building a case
(a formal warning, unannounced scans). Each step makes him contact you more
often and scrutinise meetings harder.

## Colleagues

Five people at SynerCorp are colleagues rather than management. Each one can
tell on you, and each one can be turned into the reason you don't have to work.

| | Who | Tells Martin when ignored | As a friend |
| --- | --- | --- | --- |
| Priya Nair | Does everyone's job | Sometimes | Takes tickets (fast, flawless), takes a question for you in team meetings, vouches for you to Martin |
| Kevin Marsh | Reports everything, loves visibility | Nearly always | Takes tickets (they may bounce), reads you Martin's calendar, talks you up in the channel every day, fixes your numbers on his dashboard |
| Dave Kowalski | Has not done a ticket since 2019 | Almost never | Covers for you (45 or 90 minutes of official absence), takes tickets (slowly), warns you before surprise checks |
| Brenda Okafor | Office manager, knows everything | Often | Warns you before surprise checks, loses your invite to a meeting, keeps Martin busy for 45 minutes |
| Gerald Pym | Records, sub-basement 3 | Never | Misfiles a ticket so it stops existing, puts you on the basement rota (an hour of official absence) |

**Friendship** is the relationship value (0 to 100) every character already
had, read in five tiers: Has it in for you, Cold, Colleague, Friendly, Partner
in crime. It rises when you pick up their calls, cover for them, answer
kindly, make small talk (once a day each) or send a gift card (one a day),
and falls when you ignore, refuse or blame them. Each colleague's page in
SynerTeams shows the tier, how far the next one is, and what it unlocks.

**Telling on you.** When a colleague's message expires or their call rings
out, they may tell Martin: Suspicion rises, and four times out of ten he then
asks you about it himself, naming who told him. The chance is the colleague's
own readiness to tell (Kevin 75%, Brenda 40%, Priya 20%, Dave 8%, Gerald 0%)
scaled by the tier: more for someone cold or hostile, and zero from Friendly
up. Rejecting a call halves it, an accepted excuse cancels it, and nobody
tells on someone who is officially out. A colleague tells at most twice a
day. One who has it in for you also reports any absence of 25 minutes.

**Friends** never tell on you, keep your stories to themselves (stories told
to people who dislike you reach Martin faster), and do favours. Some are
automatic once the friendship is there (warnings, a wingman in meetings,
public praise); the rest are asked for on their SynerTeams page and cost
favours, the currency colleagues owe you.

**Their calls.** Colleagues ring you, sometimes asking by message first.
These calls are not meetings: they cost no Health, the time counts as paid
slacking, and missing one never reaches Martin unless the caller takes it
there. Each colleague has a story told over the week in calls, and what you
said earlier changes what comes next:

- **Brenda** introduces the cast on Monday, trades secrets on Wednesday
  (what you learn about Kevin or Dave is a card you can play once, on
  anything they ask of you), and tells you what is in your review file on
  Friday.
- **Dave** rings from the driving range on Tuesday needing a fake vendor, and
  on Thursday when Martin asks for the vendor's name.
- **Priya** needs someone to listen on Tuesday, and on Thursday has her
  resignation written. If she sends it, her work lands on you.
- **Kevin** shows you a dashboard on Wednesday on which your status is green
  99.7% of the time, including at 3am.
- **Gerald** rings from sub-basement 3 on Tuesday, and on Friday a box has
  split and some of your tickets are on the floor.

A colleague whose call you miss tries once more later that day.

## Strange calls

From Tuesday, unknown numbers ring. Nobody at SynerCorp ever hears about
these calls, so they can be rejected freely, but most are worth taking:

| Call | Sounds like | Worth it for |
| --- | --- | --- |
| The chair-warranty robocall | A robot, one word at a time | Leave it on speaker: a 25-minute "vendor call" appears in your calendar |
| A fax machine | A fax machine | Screech back convincingly and it faxes you a Form 27-B, which is evidence for a process blocker |
| Somebody's Nana | A warbling landline | She thinks you are Tobias. Stay on and she will back up a family emergency |
| Number withheld | A cheap voice changer | Sells you what Martin does at two on Tuesdays and Thursdays: a card to play on him, once |
| Martin's pocket | Fabric | Say nothing and you overhear the rest of his plans for the day |
| You | You, corrupted | Your AI Doppelganger wants Fridays and a name (only if you own one) |

Every character has a voice: gibberish, but with their own pitch, pace and
melody, played line by line on calls. Dave on the driving range has one bar
of signal, and Gerald sounds like he is at the bottom of a lift shaft.

## The week

| Day | Introduces | Notable events |
| --- | --- | --- |
| Monday | Controls, the workstation, messaging, fake progress, the first lie | Standup, sprint planning, first tickets, the timesheet, Brenda's welcome call |
| Tuesday | Automation: MouseMover and the Keyboard Duck go on sale | Phishing test, the calendar-conflict trick, a reply-all storm, Gerald, Dave at the driving range, Priya |
| Wednesday | "Trust, but verify": stories get checked; the Alibi Ledger | A device scan, a production incident, the connection-trouble question, Mandatory Fun, Brenda's secrets, Kevin's dashboard |
| Thursday | Gadget strain, failures and combinations | SynerWatch goes live, the skip-level with senior management, a productivity audit, a 1:1, Dave's vendor, Priya's resignation |
| Friday | The performance review | Another scan, a demo demand, Gerald's box, Brenda on your file, the review at 15:30 |

The ten events the design calls for: a surprise boss message, the daily
standup, an urgent unfinished task (when a deadline is close and nothing is
done), an accidental screen share (during a video call), the internet-outage
excuse, a mouse-jiggler malfunction, a surprise video call, the corporate
productivity audit, the meeting with senior management, and the Friday
review. Around sixty more fill the week, among them ten scripted calls from
colleagues and six strange ones.

## The apartment

Every interactive object has a purpose:

| Room | Object | Purpose |
| --- | --- | --- |
| Office | Work Computer | SynerOS: Teams, Tasks, Calendar, Mail, ShadowIT |
| | Keyboard & Mouse | Wiggle to stay Available; switch and service gadgets |
| | Coffee Mug | A sip of Energy; wedge it on the spacebar to fake typing |
| | Company Laptop | Force an update: 30 excused minutes, and evidence for a crash |
| | Office Chair | Stage a busy desk; nap near the keyboard |
| | Gaming PC | The shop; order a pizza |
| | Printer | Forge a doctor's note (can jam, which is evidence too) |
| | Router | Create a real outage: evidence, but you go dark |
| Living room | Sofa, Television, Console | Health and Energy; TV can inspire an excuse |
| | Bookshelf | Fluent in Buzzword: better jargon |
| | Exercise Bike | Health, clears jitters, cheaper actions for a while |
| Kitchen | Refrigerator, Microwave, Table | Food; limited stock per day. The fridge also hands you something to carry; the microwave heats what you hold |
| | Kitchen Bin | Rubbish goes here (by hand, or thrown) |
| | Coffee Machine | Energy; refills the mug; too many cause jitters |
| Bedroom | Bed | Naps by day; sleep ends the evening |
| | Wardrobe | Outfit: a shirt helps on video, pajamas help you relax |
| | Phone Charger | Dock to charge; a docked phone cannot be answered |

## Winning and losing

- **Win**: reach Friday 17:00 employed and alive.
- **Fired**: Suspicion reaches 100.
- **Burnout**: Health reaches 0.
- **Disqualified**: any real work on Professional Unemployed.

The final screen shows work avoidance (the share of paid time with no real
work), salary earned, actual work time, successful deceptions, final suspicion,
final health and automation efficiency. A week with zero real work earns the
special rating **IMMACULATE**. It also counts the colleagues you befriended,
the favours you called in and how often you were told on.

The letter grade is separate and is made of *paid slacking*: leisure taken
between 09:00 and 17:00, time on the phone with colleagues included. With zero real work, 8 hours of it over the week is
an A and 14 hours an S; any real work caps the grade at B. This is what stops
"sit at the desk all week" from being the best strategy.

## Not in the slice

Multiple weeks or a campaign, promotions and raises, more apartments, more
bosses, the full AI-clone storyline, Steam features, localisation, gamepad
support, jumping and crouching, cooking, carrying furniture, a view out of the
windows, and accessibility options beyond volume, sensitivity, field of view
and head bob.
