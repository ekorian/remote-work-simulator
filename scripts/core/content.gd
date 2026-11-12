extends Node
## Content — all authored data: people, threads, tickets, pings, calls, mail,
## and the scripted beats of the week. No rules live here.
##
## Choice format (see Corp.resolve):
##   {t: text, a: action id (Actions.DEFS), p: base % for a bluff roll, tags: [],
##    gadget: id (roll on the gadget instead), req: {gadget|favor|money|loop},
##    ok: {...}, ko: {...}}
## Outcome keys: susp, ill, hp, en, money, favor, cover, buff, flag, say, end,
##   task (assign ticket), progress (hours on most urgent ticket), give (hand
##   ticket to colleague), later {in, ev, args}, stat.

const PEOPLE := {
	"todd": {"name": "Todd Brackett", "role": "VP of Synergy Enablement", "color": "ff8c5a"},
	"priya": {"name": "Priya Nair", "role": "Staff Engineer (does everything)", "color": "5ad1c8"},
	"kevin": {"name": "Kevin Marsh", "role": "Associate Rockstar Ninja", "color": "4fb3ff"},
	"dave": {"name": "Dave Kowalski", "role": "Senior Engineer (allegedly)", "color": "ffd166"},
	"linda": {"name": "Linda from HR", "role": "People & Culture & Compliance", "color": "ff9ecb"},
	"it": {"name": "IT Helpdesk", "role": "Have you tried rebooting?", "color": "b48cff"},
	"bot": {"name": "SynerBot", "role": "Automated notifications", "color": "8a86a8"},
	"me": {"name": "You", "role": "", "color": "5ad17a"},
}

const THREADS := {
	"todd": {"name": "Todd Brackett", "kind": "dm"},
	"team": {"name": "# team-synergy", "kind": "group"},
	"general": {"name": "# general", "kind": "group"},
	"priya": {"name": "Priya Nair", "kind": "dm"},
	"dave": {"name": "Dave Kowalski", "kind": "dm"},
	"kevin": {"name": "Kevin Marsh", "kind": "dm"},
	"it": {"name": "IT Helpdesk", "kind": "dm"},
}
const THREAD_ORDER := ["todd", "team", "general", "priya", "dave", "kevin", "it"]


func person_name(who: String) -> String:
	return str(PEOPLE.get(who, {"name": who}).name)


func person_color(who: String) -> Color:
	return Color(str(PEOPLE.get(who, {"color": "c9c4e6"}).color))


func dm_thread(who: String) -> String:
	if who == "linda" or who == "bot":
		return "general"
	return who if THREADS.has(who) else "team"


# ---------------------------------------------------------------------------
# Tickets
# ---------------------------------------------------------------------------

const TASKS := {
	"pipeline": {"key": "SYN-101", "title": "Migrate the legacy synergy pipeline to the new synergy pipeline", "desc": "The new pipeline is the old pipeline with a different logo. Nobody knows what either one does.", "prio": 2, "effort": 3, "due_day": 1, "due_t": 1000},
	"button": {"key": "SYN-108", "title": "Bug: the Submit button is 'too button-y'", "desc": "Reported by the CEO's nephew. No reproduction steps. Marked 'urgent-ish'.", "prio": 3, "effort": 1, "due_day": 1, "due_t": 720},
	"deck": {"key": "SYN-112", "title": "Q3 Alignment Deck (42 slides, 'make it pop')", "desc": "Todd wants more arrows. And a slide that 'tells the story of the arrows'.", "prio": 1, "effort": 3, "due_day": 1, "due_t": 990},
	"retro": {"key": "SYN-115", "title": "Write up the retro notes", "desc": "Summarise what went well (nothing) and what to improve (everything) in a positive tone.", "prio": 3, "effort": 1, "due_day": 1, "due_t": 900},
	"postmortem": {"key": "SYN-120", "title": "Incident postmortem: 'Who unplugged prod?'", "desc": "Blameless format. Everyone knows it was Kevin.", "prio": 1, "effort": 2, "due_day": 1, "due_t": 960},
	"audit": {"key": "SYN-124", "title": "Annual licence audit spreadsheet (1,100 rows)", "desc": "Row 1: SynerCorp owns 400 licences for software that was discontinued in 2011.", "prio": 2, "effort": 2, "due_day": 1, "due_t": 1000},
	"okr": {"key": "SYN-130", "title": "Draft Q4 OKRs for the OKR Committee", "desc": "Objectives must be 'ambitious yet already achieved'.", "prio": 2, "effort": 2, "due_day": 1, "due_t": 900},
	"selfreview": {"key": "SYN-133", "title": "Complete your self-assessment for Friday's review", "desc": "Rate yourself 1-5 on 'Ownership', 'Bias for Synergy' and 'Showing Up'.", "prio": 1, "effort": 1, "due_day": 1, "due_t": 900},
	"oncall": {"key": "SYN-137", "title": "Cover Kevin's on-call shift handover doc", "desc": "Kevin's notes read, in full: 'it should be fine'.", "prio": 2, "effort": 1, "due_day": 1, "due_t": 840},
}

const FAKE_UPDATES := [
	"{key}: good momentum today, operationalising the core learnings. ~{pct}% there.",
	"{key} update: unblocked a key dependency (myself). Now at {pct}%.",
	"Quick one on {key}: de-risked the critical path, converging on done. {pct}%.",
	"{key}: refactored the approach to be more outcome-oriented. {pct}% and climbing.",
	"{key} is tracking green. Socialising the solution with stakeholders. {pct}%.",
	"Heads up: {key} is in the 'last 10%' phase (the long one). {pct}%.",
]

const REPORT_BITS := {
	"verb": ["Operationalised", "Socialised", "Right-sized", "Double-clicked on", "Future-proofed", "Aligned on", "De-risked", "Pressure-tested"],
	"noun": ["the deliverables runway", "cross-functional synergies", "our north-star metrics", "the stakeholder narrative", "key learnings", "the strategic backlog", "a holistic paradigm"],
	"tail": ["ahead of the curve.", "with strong tailwinds.", "pending alignment.", "at 110% velocity.", "per the roadmap.", "to move the needle."],
}

const BLOCK_TITLES := ["Vendor Sync (External)", "Deep Work: Strategic Runway", "1:1 w/ Skip-Level (tentative)", "Architecture Guild", "Client Discovery Call", "Roadmap Grooming", "Dentist (do not book)"]

const AUTO_REPLIES := [
	"Great point - let me circle back with a fuller answer shortly!",
	"100%. Adding this to my radar.",
	"Yes! Thanks for flagging. On it.",
	"Love this. Let's take it offline.",
	"Acknowledged - will action and revert.",
]

const MISSED_LINES := [
	"We waited five minutes for you in \"{m}\". Where were you?",
	"You missed \"{m}\". That's going in my little notebook.",
	"\"{m}\" happened without you. Kevin took your action items. Then gave them back.",
]

const CHATTER := [
	["general", "kevin", "Just hit a 5am gym session AND shipped two PRs before standup. Grindset."],
	["general", "linda", "Reminder: the 'Wellness Wednesday' webinar is mandatory. Attendance is how we measure wellness."],
	["general", "dave", "Does anyone know who owns the 'legacy-do-not-touch' server? Asking for a friend who touched it."],
	["team", "priya", "Fixed the build. Again. You're welcome. Again."],
	["general", "it", "The VPN will be down for maintenance during the hours you need it."],
	["team", "kevin", "Can we get a retro on why the retro ran over?"],
	["general", "linda", "Someone left a fish in the 4th floor microwave. This is a culture issue."],
	["team", "dave", "brb, 'vendor sync'"],
	["general", "kevin", "Thrilled to announce I've been nominated for Synergist of the Month by me."],
	["team", "todd", "Team, let's be more intentional about our intentionality."],
	["general", "it", "Please stop naming your laptops 'Todd's Problem'."],
	["team", "priya", "If anyone needs me I'll be doing all of your jobs."],
	["general", "todd", "Just read a book summary about a book about focus. Game changer."],
	["general", "dave", "Whoever keeps booking the 'Focus Pod' for naps: respect."],
]


func fake_update_line(t: Dictionary) -> String:
	return str(Game.pick(FAKE_UPDATES)).replace("{key}", str(t.key)).replace("{pct}", str(int(t.fake)))


func fake_report_text() -> String:
	var lines: Array = []
	for i in 4:
		lines.append("- %s %s %s" % [Game.pick(REPORT_BITS.verb), Game.pick(REPORT_BITS.noun), Game.pick(REPORT_BITS.tail)])
	return "Hi Todd,\n\nToday's highlights:\n%s\n\nNext steps: continue to continue.\n\nBest,\n{name}" % "\n".join(lines)


# ---------------------------------------------------------------------------
# Pings (chat prompts)
# ---------------------------------------------------------------------------

const PINGS := {
	"welcome": {
		"from": "todd", "routine": true, "window": 30,
		"text": "Morning {name}! Big week. Can I count on you to crush it?",
		"choices": [
			{"t": "Absolutely. Crushing is imminent.", "a": "jargon", "p": 88, "tags": ["jargon"], "ok": {"ill": 3, "say": "That's what I like to hear!"}, "ko": {"susp": 3, "say": "...OK. Weird energy, but OK."}},
			{"t": "What specifically needs crushing?", "a": "honest", "ok": {"susp": 2, "say": "You know. IT. The stuff. Check SynerTasks."}},
		],
		"expire": {"susp": 5, "say": "Not a great start to the week, {name}."},
	},
	"you_there": {
		"from": "todd", "routine": true, "window": 14,
		"text": "You there?",
		"choices": [
			{"t": "Yep! Heads down on the thing.", "a": "bluff", "p": 84, "ok": {"susp": -1, "ill": 1, "say": "Good good. Carry on."}, "ko": {"susp": 5, "say": "Which thing? Never mind. Just... be around."}},
			{"t": "Here. What do you need? (Invite more work)", "a": "accept_duty", "ok": {"susp": -4, "ill": 3, "say": "Love the attitude. I'll find you something."}},
		],
		"expire": {"susp": 8, "say": "Guess not."},
	},
	"why_away": {
		"from": "todd", "window": 16,
		"text": "Your status has been Away for a while. Everything OK over there?",
		"choices": [
			{"t": "I was reading documentation. On paper.", "a": "bluff", "p": 52, "ok": {"susp": -2, "cover": 20, "say": "Old school. Respect."}, "ko": {"susp": 7, "say": "We don't have paper documentation. We barely have documentation."}},
			{"t": "Whiteboarding the architecture away from the screen.", "a": "jargon", "p": 60, "tags": ["jargon"], "ok": {"susp": -2, "ill": 3, "cover": 25, "say": "Send me a photo of the whiteboard later!"}, "ko": {"susp": 6, "say": "You don't own a whiteboard. I've seen your background."}},
		],
		"expire": {"susp": 10, "say": "OK. I'm noting this."},
	},
	"quick_q": {
		"from": "todd", "routine": true, "window": 22,
		"text": "Quick q - what's our north star for the Q3 alignment initiative?",
		"choices": [
			{"t": "Customer-centric synergy at scale.", "a": "jargon", "p": 72, "tags": ["jargon"], "ok": {"ill": 3, "susp": -1, "say": "YES. Putting that on a slide."}, "ko": {"susp": 5, "say": "That was last quarter's north star. Keep up."}},
			{"t": "Look it up and give a precise answer", "a": "real_answer", "ok": {"ill": 6, "susp": -4, "say": "Wow, thorough. Thanks!"}},
			{"t": "Great question for Priya, actually.", "a": "deflect", "p": 64, "ok": {"say": "Good shout. @Priya?"}, "ko": {"susp": 5, "say": "I asked YOU."}},
		],
		"expire": {"susp": 7},
	},
	"thoughts": {
		"from": "todd", "routine": true, "window": 22,
		"text": "Thoughts on my email?",
		"choices": [
			{"t": "Strongly agree. Especially the second part.", "a": "bluff", "p": 66, "ok": {"ill": 2, "susp": -1, "say": "Right?! Glad someone gets it."}, "ko": {"susp": 6, "say": "It was one sentence. There is no second part."}},
			{"t": "Could you summarise the key ask?", "a": "clarify", "p": 74, "tags": ["jargon"], "ok": {"ill": 1, "say": "Sure - the ask is: thoughts."}, "ko": {"susp": 4, "say": "The ask is that you read it."}},
			{"t": "Actually read it and reply thoughtfully", "a": "real_answer", "ok": {"ill": 6, "susp": -4, "say": "This is genuinely helpful. Are you feeling OK?"}},
		],
		"expire": {"susp": 7},
	},
	"numbers": {
		"from": "todd", "window": 24,
		"text": "Can you pull the engagement numbers for my 3pm? Need them in 20.",
		"choices": [
			{"t": "Send numbers that feel right.", "a": "bluff", "p": 56, "ok": {"ill": 5, "say": "Up and to the right. Perfect."}, "ko": {"susp": 9, "ill": -3, "say": "Finance says engagement can't be 140%."}},
			{"t": "Pull the real numbers", "a": "real_answer", "ok": {"ill": 7, "susp": -5, "say": "Lifesaver."}},
			{"t": "Call in a favour: have Priya pull them", "a": "delegate_colleague", "req": {"favor": 1}, "ok": {"ill": 5, "susp": -2, "say": "Got them from Priya, thanks for coordinating!"}},
		],
		"expire": {"susp": 9, "ill": -3, "say": "I went into my 3pm with no numbers. Thanks for that."},
	},
	"task_status": {
		"from": "todd", "window": 22,
		"text": "Where are we on {task}?",
		"choices": [
			{"t": "\"Nearly there, just polishing.\"", "a": "fake_update", "p": 70, "tags": ["jargon"], "ok": {"ill": 3, "susp": -1, "say": "Great. Keep polishing."}, "ko": {"susp": 6, "say": "You said that yesterday. Show me something soon.", "later": {"in": 25, "ev": "demo_demand", "args": {}}}},
			{"t": "\"Blocked on another team.\"", "a": "blame", "p": 58, "ok": {"cover": 15, "say": "Ugh. I'll chase them. (I won't.)"}, "ko": {"susp": 7, "say": "I just asked them. They've never heard of you."}},
			{"t": "Stop everything and work on it now", "a": "work_task", "ok": {"progress": 1, "susp": -3, "say": "That's the spirit."}},
		],
		"expire": {"susp": 8, "say": "Silence is also an answer, I suppose."},
	},
	"favor_dave": {
		"from": "dave", "window": 30,
		"text": "Sneaking out to the driving range. If Todd asks, I'm in a 'vendor sync'. Cover for me?",
		"choices": [
			{"t": "Cover for Dave.", "a": "do_favor", "p": 80, "ok": {"favor": 1, "say": "Legend. I owe you one."}, "ko": {"favor": 1, "susp": 5, "say": "Todd asked which vendor. You said 'the usual one'. He bought it, barely. Still owe you."}},
			{"t": "Sorry, can't risk it.", "a": "honest", "ok": {"say": "Cold. OK."}},
		],
		"expire": {"susp": 0, "say": "I'll take that as a no."}, "no_excuse": true,
	},
	"favor_kevin": {
		"from": "kevin", "window": 30,
		"text": "Hey! Could you review my PR? It's only 4,000 lines. Mostly whitespace. Some of it is prod config.",
		"choices": [
			{"t": "\"LGTM\" (do not open it).", "a": "react", "p": 70, "ok": {"ill": 2, "say": "Fastest review ever, thanks!!"}, "ko": {"susp": 8, "ill": -3, "say": "Uh. You approved the one that deletes the staging database."}},
			{"t": "Actually review all 4,000 lines", "a": "help_colleague", "ok": {"favor": 1, "ill": 5, "susp": -2, "say": "Wow, 37 comments. You're a real one. I owe you."}},
			{"t": "Tell Kevin you're swamped.", "a": "deflect", "p": 72, "ok": {"say": "No worries, I'll ask Priya."}, "ko": {"susp": 3, "say": "Swamped? Your status says 'Away'."}},
		],
		"expire": {"susp": 2}, "no_excuse": true,
	},
	"favor_priya": {
		"from": "priya", "window": 30,
		"text": "I'm drowning. Can you tell Todd the release notes are 'in review' so he stops pinging me?",
		"choices": [
			{"t": "Run interference with Todd.", "a": "do_favor", "p": 78, "ok": {"favor": 1, "say": "Thank you. Genuinely. I'll remember this."}, "ko": {"favor": 1, "susp": 4, "say": "He asked you follow-up questions, huh. Thanks for trying."}},
			{"t": "Offer to write the release notes yourself", "a": "help_colleague", "ok": {"favor": 2, "ill": 4, "say": "Are you... offering to WORK? Who are you? Thank you."}},
			{"t": "Stay out of it.", "a": "honest", "ok": {"say": "Fair."}},
		],
		"expire": {"susp": 0}, "no_excuse": true,
	},
	"volunteer": {
		"from": "todd", "thread": "team", "window": 22,
		"text": "I need a volunteer to own the incident postmortem. {name}, you've been quiet.",
		"choices": [
			{"t": "Volunteer.", "a": "volunteer", "ok": {"susp": -7, "ill": 6, "task": "postmortem", "say": "Ownership! Love it. It's yours."}},
			{"t": "\"This is a real growth opportunity for Kevin.\"", "a": "deflect", "p": 66, "tags": ["jargon"], "ok": {"ill": 1, "say": "Great call. Kevin, it's yours."}, "ko": {"susp": 5, "task": "postmortem", "say": "Nice try. It's yours, {name}."}},
		],
		"expire": {"susp": 6, "task": "postmortem", "say": "Silence means yes. It's yours, {name}."},
	},
	"outage": {
		"from": "todd", "thread": "team", "window": 16,
		"text": "PROD IS DOWN. All hands on deck. {name}, what are you seeing?",
		"choices": [
			{"t": "\"Looking at the logs now.\" (Look at nothing.)", "a": "pretend_investigate", "p": 70, "ok": {"ill": 5, "susp": -2, "say": "Good. Keep digging."}, "ko": {"susp": 7, "say": "Which logs? Paste them. ...Hello?"}},
			{"t": "\"Smells like the last deploy.\" (Kevin's.)", "a": "blame", "p": 60, "ok": {"ill": 3, "say": "KEVIN."}, "ko": {"susp": 8, "say": "The last deploy was yours. From March."}},
			{"t": "Roll up your sleeves and fix prod", "a": "fix_bug", "ok": {"susp": -10, "ill": 12, "say": "You FIXED it? I didn't know you could do that."}},
		],
		"expire": {"susp": 10, "ill": -5, "say": "Prod was down for an hour and you said nothing."},
	},
	"timesheet": {
		"from": "bot", "thread": "general", "window": 35, "no_excuse": true,
		"text": "TIMESHEET REMINDER: log your 8.0 hours for today before 17:00.",
		"choices": [
			{"t": "Log 8.0h of 'strategic alignment'.", "a": "fake_timesheet", "p": 82, "ok": {"ill": 3, "say": "Timesheet accepted."}, "ko": {"susp": 6, "say": "Timesheet flagged for manager review: category 'strategic alignment' exceeds weekly cap."}},
			{"t": "Reconstruct an accurate timesheet", "a": "real_timesheet", "ok": {"ill": 4, "susp": -3, "say": "Timesheet accepted. Accuracy score: 100%."}},
			{"t": "Log what you really did today.", "a": "honest", "ok": {"susp": 12, "say": "Timesheet flagged: 'Napping' is not a valid project code."}},
		],
		"expire": {"susp": 5, "say": "Timesheet not submitted. Your manager has been notified."},
	},
	"screen_check": {
		"from": "todd", "window": 14,
		"text": "SynerWatch flagged 'low screen activity' on your machine. Share your screen for a sec?",
		"choices": [
			{"t": "Share the AltTab Pro fake screen.", "a": "bluff", "gadget": "fakescreen", "req": {"gadget": "fakescreen"}, "ok": {"susp": -5, "ill": 5, "say": "Whoa, that's a lot of code. OK, false alarm."}, "ko": {"susp": 12, "say": "Why does your screen say DEMO MODE?"}},
			{"t": "Frantically open a spreadsheet, then share.", "a": "bluff", "p": 44, "ok": {"susp": -2, "ill": 2, "say": "Looks busy enough. Carry on."}, "ko": {"susp": 9, "say": "That spreadsheet is empty and titled 'asdf'."}},
			{"t": "Do some real work so there's something to show", "a": "live_demo", "ok": {"susp": -8, "ill": 8, "progress": 1, "say": "Great, thanks. Carry on."}},
		],
		"expire": {"susp": 11, "say": "No screen share. I'm logging that."},
	},
	"demo_demand": {
		"from": "todd", "window": 18,
		"text": "You said {task} is nearly done. Hop on and show me a quick demo?",
		"choices": [
			{"t": "Demo a slideshow with total confidence.", "a": "bluff", "p": 40, "tags": ["jargon"], "ok": {"ill": 6, "susp": -3, "say": "The arrows really tell a story. Nice."}, "ko": {"susp": 12, "ill": -6, "say": "That was a slideshow of stock photos."}},
			{"t": "Share the AltTab Pro fake screen.", "a": "bluff", "gadget": "fakescreen", "req": {"gadget": "fakescreen"}, "ok": {"susp": -4, "ill": 6, "say": "Looks complicated. Good."}, "ko": {"susp": 12, "say": "Why does your screen say DEMO MODE?"}},
			{"t": "\"It works on my machine. Demo gods, you know.\"", "a": "blame", "p": 50, "ok": {"say": "Ha, classic. Tomorrow then."}, "ko": {"susp": 9, "say": "Then show me your machine."}},
			{"t": "Build the thing live in front of him", "a": "live_demo", "ok": {"progress": 1, "susp": -6, "ill": 6, "say": "Oh. It's real. Good!"}},
		],
		"expire": {"susp": 12, "ill": -5, "say": "No demo. So it's not nearly done. Got it."},
	},
	"block_audit": {
		"from": "todd", "window": 20,
		"text": "Saw \"{title}\" on your calendar. What was that about?",
		"choices": [
			{"t": "Cross-functional pre-alignment. Very productive.", "a": "jargon", "p": 66, "tags": ["jargon"], "ok": {"ill": 2, "say": "Love a pre-alignment."}, "ko": {"susp": 8, "say": "I asked the people in it. There were no people in it."}},
			{"t": "Personal appointment. Sorry, should've flagged.", "a": "bluff", "p": 60, "ok": {"say": "No worries. Flag it next time."}, "ko": {"susp": 6, "say": "It was titled 'Architecture Guild'."}},
		],
		"expire": {"susp": 8},
	},
	"kevin_snitch": {
		"from": "kevin", "window": 25, "no_excuse": true,
		"text": "Funny thing - your status was 'Available' while your cursor drew circles for an hour. Anyway! Could you take my on-call handover doc?",
		"choices": [
			{"t": "Take the handover doc.", "a": "accept_duty", "ok": {"task": "oncall", "favor": 1, "say": "You're the best! Our secret. ;)"}},
			{"t": "Buy his silence with a $40 'coffee'.", "a": "flatter", "req": {"money": 40}, "ok": {"say": "Coffee received. What circles? I saw nothing."}},
			{"t": "Call his bluff.", "a": "bluff", "p": 50, "ok": {"say": "Ha, just kidding around! ...Unless?"}, "ko": {"susp": 10, "say": "OK. I'll just mention it to Todd then. For transparency."}},
		],
		"expire": {"susp": 9, "say": "No reply? I'll ask Todd what he thinks."},
	},
	"article": {
		"from": "todd", "routine": true, "window": 24,
		"text": "Sharing a must-read: '7 Habits of Highly Synergistic People'. Thoughts?",
		"choices": [
			{"t": "\"Habit 4 really resonated.\"", "a": "bluff", "p": 68, "ok": {"ill": 2, "susp": -1, "say": "RIGHT? Habit 4. Wow."}, "ko": {"susp": 4, "say": "There are only three habits. The title is clickbait."}},
			{"t": "Read it properly and reply with notes", "a": "real_answer", "ok": {"ill": 5, "susp": -3, "say": "You READ it? Nobody reads them. I'm touched."}},
		],
		"expire": {"susp": 4},
	},
	"blockers": {
		"from": "todd", "routine": true, "window": 22,
		"text": "Any blockers I should know about?",
		"choices": [
			{"t": "\"None. Full steam ahead.\"", "a": "bluff", "p": 78, "ok": {"ill": 2, "say": "Music to my ears."}, "ko": {"susp": 4, "say": "Then why is nothing moving on the board?"}},
			{"t": "Invent an impressive-sounding blocker.", "a": "jargon", "p": 60, "tags": ["jargon"], "ok": {"ill": 2, "cover": 20, "cover_cat": "focus", "say": "Ooh. That sounds gnarly. Take the time you need."}, "ko": {"susp": 6, "say": "'Quantum dependency drift' isn't a thing. I asked Priya."}},
		],
		"expire": {"susp": 5},
	},
	"weekend": {
		"from": "todd", "window": 24,
		"text": "Could you jump on a quick thing this Saturday? Should only take the whole day.",
		"choices": [
			{"t": "\"I'll be out of signal range, sadly.\"", "a": "bluff", "p": 70, "ok": {"say": "No worries. I'll ask Kevin."}, "ko": {"susp": 5, "say": "Out of range? You live above a phone shop."}},
			{"t": "\"Sure.\"", "a": "accept_duty", "ok": {"susp": -6, "ill": 4, "say": "Knew I could count on you."}},
		],
		"expire": {"susp": 5, "say": "I'll take the silence as a maybe."},
	},
	"emoji": {
		"from": "todd", "thread": "team", "routine": true, "window": 22, "no_excuse": true,
		"text": "Team! Drop a :rocket: if you're pumped for Q3!",
		"choices": [
			{"t": ":rocket:", "a": "react", "ok": {"ill": 2, "say": "THAT'S the energy."}},
			{"t": "Write a heartfelt paragraph about Q3", "a": "real_answer", "ok": {"ill": 5, "susp": -3, "say": "Screenshotting this for the board."}},
		],
		"expire": {"susp": 3, "say": "{name}? No rocket? Noted."},
	},
	"kevin_brag": {
		"from": "kevin", "thread": "team", "routine": true, "window": 26, "no_excuse": true,
		"text": "Shipped the new dashboard at 2am! Would love feedback from {name} specifically.",
		"choices": [
			{"t": "\"Looks great! Love the colours.\"", "a": "bluff", "p": 78, "ok": {"ill": 2, "say": "Thanks!! Means a lot."}, "ko": {"susp": 3, "say": "It's a command-line tool. It has no colours."}},
			{"t": "Test it properly and file real bugs", "a": "help_colleague", "ok": {"favor": 1, "ill": 4, "say": "14 bugs?! OK, fair. Thank you. I owe you."}},
		],
		"expire": {"susp": 2},
	},
	"it_survey": {
		"from": "it", "routine": true, "window": 30, "no_excuse": true,
		"text": "MANDATORY SURVEY: rate your IT experience from 1 to 10.",
		"choices": [
			{"t": "\"10.\" (Fastest answer.)", "a": "react", "ok": {"ill": 1, "say": "Thank you for your feedback. Your ticket from 2023 remains open."}},
			{"t": "Write detailed, constructive feedback", "a": "real_answer", "ok": {"ill": 4, "susp": -2, "say": "This is the first response we've ever received with words in it."}},
		],
		"expire": {"susp": 2, "say": "Survey incomplete. Your manager has been notified."},
	},
	"priya_branch": {
		"from": "priya", "window": 26, "no_excuse": true,
		"text": "Which branch did you push the hotfix to? I can't find it anywhere.",
		"choices": [
			{"t": "\"It's on my machine. Pushing shortly.\"", "a": "bluff", "p": 62, "ok": {"say": "OK. 'Shortly'. Sure."}, "ko": {"susp": 5, "say": "You said that on Monday. I'm telling Todd it's not done."}},
			{"t": "Come clean: there is no hotfix.", "a": "honest", "ok": {"favor": -1, "say": "lol. I figured. Fine, I'll write it. You owe me."}},
			{"t": "Write the hotfix right now", "a": "fix_bug", "ok": {"favor": 1, "ill": 5, "susp": -3, "say": "It works?! Who ARE you today?"}},
		],
		"expire": {"susp": 5, "say": "No answer. Telling Todd it's missing."},
	},
	"linda_form": {
		"from": "linda", "thread": "general", "routine": true, "window": 30, "no_excuse": true,
		"text": "{name}, you have not signed the updated Desk Ergonomics Policy (v14).",
		"choices": [
			{"t": "Sign without reading.", "a": "ack", "ok": {"ill": 1, "say": "Signed. You have agreed to sit up straight."}},
			{"t": "Read all 40 pages first", "a": "do_training", "ok": {"ill": 4, "susp": -2, "say": "You found a typo on page 31. HR is in your debt."}},
		],
		"expire": {"susp": 3, "say": "Unsigned. Escalating to your manager."},
	},
	"dave_cover": {
		"from": "dave", "window": 28, "no_excuse": true,
		"text": "Todd's asking where the release checklist is. I told him you had it. You don't, do you. Play along?",
		"choices": [
			{"t": "Play along: \"Finalising it now.\"", "a": "do_favor", "p": 72, "ok": {"favor": 1, "say": "Beautiful. I owe you."}, "ko": {"favor": 1, "susp": 5, "say": "He asked to see it. Sorry. Still owe you."}},
			{"t": "\"Not my circus, Dave.\"", "a": "honest", "ok": {"say": "Brutal."}},
		],
		"expire": {"susp": 0, "say": "OK, I told him it was Kevin."},
	},
	"lunch_order": {
		"from": "linda", "thread": "general", "routine": true, "window": 40, "no_excuse": true,
		"text": "Poll: which 'fun' theme for Friday's virtual lunch? {name}, you haven't voted in 14 polls.",
		"choices": [
			{"t": "Vote for 'Hats'.", "a": "react", "ok": {"ill": 2, "say": "Thank you for participating in culture!"}},
			{"t": "Write a thoughtful paragraph about team rituals", "a": "real_answer", "ok": {"ill": 5, "susp": -3, "say": "Wow. I'm putting this in the newsletter."}},
		],
		"expire": {"susp": 2, "say": "15 polls."},
	},
}


# ---------------------------------------------------------------------------
# Mail
# ---------------------------------------------------------------------------

const MAILS := {
	"welcome_hr": {
		"from": "linda", "subject": "Welcome to Wellness Week!",
		"body": "Hi {name},\n\nThis week we celebrate YOU by adding four mandatory meetings about work-life balance.\n\nReminder: remote employees are expected to be 'visibly available' between 09:00 and 17:00. Lunch is 12:00-12:45 and nobody will ask where you are.\n\nStay well (it's a KPI),\nLinda",
	},
	"shady": {
		"from": "it", "subject": "[SPAM?] ShadyDeals.biz - Remote Work 'Solutions'",
		"body": "TIRED of MOVING your MOUSE like a PEASANT??\n\nMouse jigglers! Nodding webcam loops! AI interns that work while you nap!\n\nVisit ShadyDeals.biz from your PERSONAL computer (not the company one, we are not animals).\n\nNew stock unlocks every day this week.",
	},
	"phish": {
		"from": "it", "subject": "URGENT: Your pasword expires in 5 minuts - click here",
		"body": "Dear Valued Employe,\n\nYour SynerCorp pasword will expire. Click hear to keep your acount: http://synercorp-secure.totally-legit.biz\n\nRegards,\nThe Real IT Departmant",
		"window": 120,
		"choices": [
			{"t": "Report it as phishing. Look vigilant.", "a": "report_phish", "ok": {"ill": 5, "susp": -2, "say": "IT: Well spotted. You passed the phishing simulation. Gold star added to your file."}},
			{"t": "Click the link. Free password!", "a": "ack", "ok": {"susp": 6, "task": "audit", "say": "IT: You failed the phishing simulation. You've been assigned remedial paperwork."}},
		],
		"expire": {"susp": 1},
	},
	"training": {
		"from": "linda", "subject": "MANDATORY: Annual Compliance Training (40 min video + quiz)",
		"body": "Hi {name},\n\nYou are 212 days overdue on 'Ethics & You: A Journey'. The video cannot be skipped, sped up, or enjoyed.\n\nComplete it today.\n\nLinda",
		"window": 200,
		"choices": [
			{"t": "Let it play on mute and guess the quiz.", "a": "bg_training", "p": 74, "ok": {"ill": 3, "say": "Linda: Training complete. Quiz score: 60% (pass)."}, "ko": {"susp": 7, "say": "Linda: You answered 'C' to every question, including the one asking your name."}},
			{"t": "Watch all 40 minutes and take notes", "a": "do_training", "ok": {"ill": 5, "susp": -3, "say": "Linda: 100% on the quiz. Nobody has ever done that."}},
		],
		"expire": {"susp": 8, "say": "Linda: Training still incomplete. I've cc'd your manager."},
	},
	"storm": {
		"from": "kevin", "subject": "RE: RE: RE: RE: Who took my stapler (REPLY ALL)",
		"body": "214 people are replying-all to ask everyone to stop replying-all.\n\nThe whole company is distracted. Todd is three replies deep defending the stapler policy.",
		"window": 60,
		"choices": [
			{"t": "Reply-all: \"Great discussion, +1 to alignment.\"", "a": "reply_all", "p": 62, "ok": {"ill": 4, "say": "Todd liked your reply. Visibility!"}, "ko": {"susp": 4, "say": "The CEO replied to you: 'Who is this?'"}},
			{"t": "Mute the thread and slip away while they fight.", "a": "ignore", "ok": {"cover": 35, "cover_cat": "chaos", "say": "Nobody will notice you for a while."}},
		],
		"expire": {"susp": 0},
	},
	"synerwatch": {
		"from": "it", "subject": "Introducing SynerWatch(TM) Activity Monitoring",
		"body": "Team,\n\nStarting today, SynerWatch measures keyboard activity, 'screen liveliness' and unauthorised devices on every remote laptop.\n\nScans may now happen without notice. Automation tools generate 'heat' and WILL be found.\n\nThis is about trust.\n\nIT",
	},
	"audit_warn": {
		"from": "it", "subject": "Scheduled device scan in ~25 minutes",
		"body": "A routine scan for unauthorised USB devices and automation software will run shortly.\n\nIf you have nothing plugged in, you have nothing to worry about.\n\n(Open ShadowIT and switch things off. The scan checks your current Heat.)",
	},
	"review_invite": {
		"from": "todd", "subject": "Friday 15:30 - Your Weekly Performance Review",
		"body": "{name},\n\nHR will join us. Attendance is not optional and cannot be rescheduled, delegated, looped or excused.\n\nWear a shirt.\n\nTodd",
	},
	"payday": {
		"from": "bot", "subject": "Payroll: your daily deposit has landed",
		"body": "SynerCorp pays remote staff daily at 17:00 because the payroll system was configured wrong in 2009 and nobody dares touch it.\n\nBonuses apply for 'perceived impact' and for 'efficiency' (billing zero productive minutes).",
	},
}


# ---------------------------------------------------------------------------
# Calls and meetings
# ---------------------------------------------------------------------------

const BEAT_POOL := {
	"own_notes": {
		"who": "todd", "text": "Who wants to own the retro notes? ...Anyone?",
		"choices": [
			{"t": "Stay perfectly still. Become furniture.", "a": "deflect", "p": 74, "ok": {"say": "...Kevin? Thanks, Kevin."}, "ko": {"susp": 3, "task": "retro", "say": "{name}, you blinked. It's yours."}},
			{"t": "Volunteer.", "a": "volunteer", "ok": {"susp": -6, "ill": 5, "task": "retro", "say": "{name}! Great initiative."}},
		],
	},
	"camera": {
		"who": "todd", "text": "{name}, your camera looks... are you in bed?",
		"choices": [
			{"t": "\"It's an ergonomic floor desk.\"", "a": "bluff", "p": 58, "tags": ["video"], "ok": {"say": "Huh. Send me the link."}, "ko": {"susp": 6, "say": "That's a pillow."}},
			{"t": "\"Bandwidth issues - turning my camera off.\"", "a": "bluff", "p": 70, "ok": {"say": "OK, we'll miss your face."}, "ko": {"susp": 4, "say": "Everyone else's works fine."}},
		],
	},
	"opinion": {
		"who": "priya", "text": "{name}, you worked on this area. Do we go with option A or option B?",
		"choices": [
			{"t": "\"I'd want to double-click on both before committing.\"", "a": "jargon", "p": 70, "tags": ["jargon"], "ok": {"ill": 3, "say": "...That's not an answer, but fine."}, "ko": {"susp": 5, "say": "We need an answer today."}},
			{"t": "\"B.\" (Coin flip.)", "a": "bluff", "p": 55, "ok": {"ill": 4, "say": "Agreed, B. Nice."}, "ko": {"susp": 5, "ill": -2, "say": "B is the one that's on fire."}},
			{"t": "Explain the real trade-offs", "a": "real_answer", "ok": {"ill": 7, "susp": -5, "say": "That's... actually really clear. Thank you."}},
		],
	},
	"silence": {
		"who": "todd", "text": "...and that's the plan. Any questions? {name}?",
		"choices": [
			{"t": "\"No questions - super clear, thanks.\"", "a": "bluff", "p": 86, "ok": {"susp": -1, "say": "Great."}, "ko": {"susp": 3, "say": "You were on mute the whole time, weren't you."}},
			{"t": "Ask a question that sounds deep.", "a": "jargon", "p": 62, "tags": ["jargon"], "ok": {"ill": 5, "say": "Ooh. Let's take that offline. Great question."}, "ko": {"susp": 4, "say": "I literally just covered that."}},
		],
	},
}

const CALLS := {
	"standup": {
		"beats": [
			{
				"who": "todd", "text": "Standup time. {name}: yesterday, today, blockers. Go.",
				"choices": [
					{"t": "\"Synergised the pipeline. Today: more synergy. No blockers.\"", "a": "jargon", "p": 70, "tags": ["jargon"], "ok": {"susp": -3, "ill": 5, "say": "Crisp. Next."}, "ko": {"susp": 6, "say": "That's word-for-word what you said yesterday."}},
					{"t": "\"Same as yesterday.\"", "a": "bluff", "p": 54, "ok": {"susp": -1, "ill": 2, "say": "OK. Next."}, "ko": {"susp": 5, "say": "And what was yesterday?"}},
					{"t": "Give a real, detailed status", "a": "real_answer", "ok": {"susp": -6, "ill": 8, "say": "Detail! In standup! Everyone take note."}},
				],
			},
		],
		"pool": ["own_notes", "camera", "silence"], "pick": 1,
		"after": {"ill": 2},
	},
	"planning": {
		"beats": [
			{
				"who": "todd", "text": "Sprint planning. How many story points is the pipeline migration, {name}?",
				"choices": [
					{"t": "\"Thirteen.\" (Sounds like a lot.)", "a": "bluff", "p": 68, "ok": {"ill": 3, "say": "Thirteen. Big. OK."}, "ko": {"susp": 4, "say": "Last sprint you said two."}},
					{"t": "\"It's hard to estimate without a discovery spike.\"", "a": "jargon", "p": 72, "tags": ["jargon"], "ok": {"ill": 3, "susp": -1, "say": "Good instinct. Let's add a spike."}, "ko": {"susp": 4, "say": "We did a spike. You led it."}},
					{"t": "Break it down properly on the spot", "a": "real_answer", "ok": {"ill": 7, "susp": -5, "say": "This is the most useful thing said in planning all year."}},
				],
			},
			{
				"who": "todd", "text": "We have capacity for one more ticket. Who's light this sprint?",
				"choices": [
					{"t": "Look intensely at a second monitor.", "a": "deflect", "p": 66, "tags": ["video"], "ok": {"say": "Dave, you're up."}, "ko": {"susp": 3, "task": "audit", "say": "{name}, you look light. Licence audit's yours."}},
					{"t": "\"I'm at 120% already, honestly.\"", "a": "bluff", "p": 60, "ok": {"ill": 2, "say": "Wow. Don't burn out. Dave?"}, "ko": {"susp": 6, "task": "audit", "say": "SynerTasks says you're at 20%. It's yours."}},
					{"t": "Take it.", "a": "accept_duty", "ok": {"susp": -6, "ill": 5, "task": "audit", "say": "Team player!"}},
				],
			},
		],
		"pool": ["opinion", "silence"], "pick": 1,
		"after": {"ill": 2},
	},
	"sync": {
		"beats": [
			{
				"who": "todd", "text": "Thanks for hopping on. Quick sync - what are you working on RIGHT now?",
				"choices": [
					{"t": "Name your most urgent ticket with a straight face.", "a": "bluff", "p": 64, "tags": ["video"], "ok": {"susp": -3, "ill": 3, "say": "Good, good. That one matters."}, "ko": {"susp": 7, "say": "It doesn't look like you've opened it since Monday."}},
					{"t": "\"Deep in discovery. Lots of moving parts.\"", "a": "jargon", "p": 66, "tags": ["jargon", "video"], "ok": {"ill": 3, "say": "Discovery. Love it."}, "ko": {"susp": 6, "say": "Discover faster."}},
					{"t": "Walk him through real progress", "a": "real_answer", "ok": {"susp": -7, "ill": 8, "say": "This is great. You should talk more."}},
				],
			},
		],
		"pool": ["camera", "opinion"], "pick": 1,
		"after": {"susp": -1},
	},
	"alignment": {
		"beats": [
			{
				"who": "kevin", "text": "Welcome to the Cross-Functional Alignment Sync! Let's go around: one word for how you're feeling.",
				"choices": [
					{"t": "\"Aligned.\"", "a": "jargon", "p": 86, "tags": ["jargon"], "ok": {"ill": 2, "say": "Yes!! Love that."}, "ko": {"susp": 2, "say": "Someone already said that. Pick another."}},
					{"t": "\"Tired.\"", "a": "honest", "ok": {"susp": 3, "say": "Oof. OK. Let's unpack that offline."}},
				],
			},
		],
		"pool": ["opinion", "own_notes", "silence"], "pick": 2,
		"after": {"ill": 2},
	},
	"fun": {
		"beats": [
			{
				"who": "linda", "text": "Welcome to MANDATORY FUN! Two truths and a lie. {name}, you're first!",
				"choices": [
					{"t": "Tell three lies. Nobody will check.", "a": "bluff", "p": 78, "tags": ["video"], "ok": {"ill": 3, "say": "A lion tamer AND a twin? Wow!"}, "ko": {"susp": 3, "say": "Dave says you told a different three last year."}},
					{"t": "Share something genuine and vulnerable", "a": "honest", "ok": {"hp": -4, "ill": 2, "say": "...Thank you for sharing. Moving on."}},
				],
			},
			{
				"who": "linda", "text": "Now: virtual scavenger hunt! Find something in your home that represents SYNERGY!",
				"choices": [
					{"t": "Hold up the nearest object. \"This.\"", "a": "bluff", "p": 72, "tags": ["video"], "ok": {"ill": 2, "say": "A... sock. Because it has a partner! Love it."}, "ko": {"susp": 3, "say": "That's a parking ticket."}},
					{"t": "Sprint around the flat with real enthusiasm", "a": "volunteer", "ok": {"en": -8, "ill": 5, "susp": -3, "say": "THAT is the energy we need!"}},
				],
			},
		],
		"pool": ["camera"], "pick": 1,
		"after": {"susp": -2},
	},
	"allhands": {
		"beats": [
			{
				"who": "todd", "text": "All-hands. I'm excited to announce a reorg. Nothing changes, except everything. Reactions?",
				"choices": [
					{"t": "React with a party emoji.", "a": "react", "ok": {"ill": 2, "say": "Love the energy in the chat."}},
					{"t": "Ask what the reorg actually changes.", "a": "honest", "ok": {"susp": 3, "say": "Great question. We'll share more when we know what we decided."}},
				],
			},
			{
				"who": "todd", "text": "We're forming a tiger team for 'Project Phoenix 2: Phoenix Again'. I'm looking for hands.",
				"choices": [
					{"t": "Experience a brief audio glitch.", "a": "bluff", "p": 70, "ok": {"say": "{name}, you cut out. I'll ask Priya."}, "ko": {"susp": 5, "task": "okr", "say": "You came through loud and clear. You're on the team."}},
					{"t": "Raise your hand.", "a": "volunteer", "ok": {"susp": -7, "ill": 6, "task": "okr", "say": "A tiger! Welcome."}},
				],
			},
		],
		"pool": ["silence"], "pick": 1,
		"after": {"ill": 1},
	},
	"one_on_one": {
		"beats": [
			{
				"who": "todd", "text": "1:1 time. How do you feel about your workload?",
				"choices": [
					{"t": "\"Stretched, but in a growth-y way.\"", "a": "jargon", "p": 74, "tags": ["jargon", "video"], "ok": {"ill": 3, "susp": -2, "say": "That's the sweet spot."}, "ko": {"susp": 5, "say": "Stretched? Your board is empty."}},
					{"t": "\"I could take on more!\"", "a": "accept_duty", "ok": {"susp": -8, "ill": 5, "task": "okr", "say": "Music to my ears. I have just the thing."}},
					{"t": "\"Honestly, I don't know what I do here.\"", "a": "honest", "ok": {"susp": 10, "say": "...Neither do I, now that you mention it."}},
				],
			},
			{
				"who": "todd", "text": "Be honest: do people on the team seem... engaged? Like, really working?",
				"choices": [
					{"t": "\"Everyone's crushing it. Especially me.\"", "a": "bluff", "p": 62, "tags": ["video"], "ok": {"susp": -3, "say": "That's my read too."}, "ko": {"susp": 6, "say": "Hm. That's not what SynerWatch says."}},
					{"t": "Subtly throw Kevin under the bus.", "a": "blame", "p": 58, "tags": ["video"], "ok": {"susp": -4, "say": "Interesting. I've had my eye on him."}, "ko": {"susp": 7, "say": "Kevin said the same thing about you."}},
					{"t": "Praise Priya (she deserves it).", "a": "chat", "ok": {"favor": 1, "say": "She IS great. I should tell her. (He won't.)"}},
				],
			},
		],
		"pool": [], "pick": 0,
		"after": {"susp": -1},
	},
}


func build_call(m: Dictionary) -> Array:
	## Beats for a meeting, assembled from its script. The review is generated
	## from how the week actually went.
	var script: String = str(m.script)
	if script == "review":
		return _review_beats()
	var def: Dictionary = CALLS.get(script, CALLS["sync"])
	var beats: Array = def.beats.duplicate(true)
	var pool: Array = def.get("pool", []).duplicate()
	for i in int(def.get("pick", 0)):
		if pool.is_empty():
			break
		var key: String = pool[Game.rng.randi() % pool.size()]
		pool.erase(key)
		beats.append(BEAT_POOL[key].duplicate(true))
	return beats


func _review_beats() -> Array:
	var wk: Dictionary = Game.s.week
	var done := int(wk.tasks_done) + int(wk.tasks_faked)
	var failed := int(wk.tasks_failed)
	var contra := int(wk.contradictions)
	var p_achieve := clampf(46.0 + 9.0 * float(done) - 10.0 * float(failed), 15.0, 90.0)
	var beats: Array = [
		{
			"who": "todd", "no_excuse": true,
			"text": "Performance review. HR is on the line. {name}: what was your biggest achievement this week?",
			"choices": [
				{"t": "List your closed tickets with total confidence.", "a": "bluff", "p": p_achieve, "tags": ["video", "jargon"], "ok": {"susp": -5, "ill": 5, "say": "Linda: That matches the board. Noted."}, "ko": {"susp": 9, "say": "Linda: The board shows something rather different."}},
				{"t": "\"Achievement is a journey, not a deliverable.\"", "a": "jargon", "p": 52, "tags": ["jargon", "video"], "ok": {"ill": 3, "say": "Todd: ...I'm writing that down."}, "ko": {"susp": 7, "say": "Linda: Please answer the question."}},
				{"t": "Present real, documented accomplishments", "a": "real_answer", "ok": {"susp": -9, "ill": 8, "say": "Linda: Thorough. Very thorough."}},
			],
			"silence": {"susp": 9, "say": "Linda: Let the record show the employee said nothing."},
		},
	]
	if contra > 0 or int(wk.excuses) >= 6:
		beats.append({
			"who": "linda", "no_excuse": true,
			"text": "We logged %d absence explanations this week, %d of which contradicted our records. Care to comment?" % [int(wk.excuses), contra],
			"choices": [
				{"t": "\"Each one was documented. Check your system.\"", "a": "bluff", "p": 62.0 - 13.0 * float(contra), "tags": ["video"], "ok": {"susp": -4, "say": "Linda: ...The system does lose things. Fine."}, "ko": {"susp": 11, "say": "Linda: I am the system."}},
				{"t": "\"It's been a hard week. Family, sushi, routers.\"", "a": "bluff", "p": 44.0 - 6.0 * float(contra), "tags": ["video"], "ok": {"susp": -2, "say": "Todd: Let's show some empathy here, Linda."}, "ko": {"susp": 9, "say": "Linda: All in the same week. Remarkable."}},
				{"t": "Come clean about the excuses.", "a": "honest", "ok": {"susp": 14, "say": "Linda: Thank you for your honesty. It will be held against you."}},
			],
			"silence": {"susp": 10, "say": "Linda: Silence. Noted."},
		})
	else:
		beats.append({
			"who": "linda", "no_excuse": true,
			"text": "Your attendance record is... surprisingly clean. How do you stay so available?",
			"choices": [
				{"t": "\"Discipline. And a very good chair.\"", "a": "bluff", "p": 80, "tags": ["video"], "ok": {"susp": -4, "ill": 3, "say": "Linda: We should all be so lucky."}, "ko": {"susp": 4, "say": "Linda: Hm."}},
				{"t": "\"I never really log off.\" (Technically true.)", "a": "honest", "ok": {"susp": -2, "say": "Todd: That's the spirit!"}},
			],
			"silence": {"susp": 6, "say": "Linda: Noted."},
		})
	beats.append({
		"who": "todd", "no_excuse": true,
		"text": "Last one. Where do you see yourself in five years?",
		"choices": [
			{"t": "\"Driving synergy at scale, wherever the roadmap takes me.\"", "a": "jargon", "p": 76, "tags": ["jargon", "video"], "ok": {"ill": 4, "susp": -3, "say": "Todd: Beautiful."}, "ko": {"susp": 5, "say": "Linda: That's the mission statement from our lobby wall."}},
			{"t": "\"In your chair, Todd.\"", "a": "bluff", "p": 34, "tags": ["video"], "ok": {"susp": -9, "ill": 8, "say": "Todd: HA! I love ambition."}, "ko": {"susp": 10, "say": "Todd: ...Excuse me?"}},
			{"t": "\"Honestly? On a beach. Still on payroll.\"", "a": "honest", "ok": {"susp": 9, "say": "Linda: I'm writing down 'retention risk'."}},
		],
		"silence": {"susp": 8, "say": "Todd: Deep thinker. OK."},
	})
	return beats


# ---------------------------------------------------------------------------
# The week
# ---------------------------------------------------------------------------

## Scheduled meetings per day.
const WEEK_MEETINGS := [
	[
		{"title": "Daily Standup", "start": 570, "dur": 15, "script": "standup", "mandatory": true},
		{"title": "Sprint Planning", "start": 840, "dur": 50, "script": "planning", "mandatory": false},
	],
	[
		{"title": "Daily Standup", "start": 570, "dur": 15, "script": "standup", "mandatory": true},
		{"title": "Cross-Functional Alignment Sync", "start": 660, "dur": 45, "script": "alignment", "who": "kevin", "mandatory": false},
	],
	[
		{"title": "Daily Standup", "start": 570, "dur": 15, "script": "standup", "mandatory": true},
		{"title": "Mandatory Fun: Virtual Team Building", "start": 900, "dur": 45, "script": "fun", "who": "linda", "mandatory": true},
	],
	[
		{"title": "Daily Standup", "start": 570, "dur": 15, "script": "standup", "mandatory": true},
		{"title": "All-Hands: Exciting Changes", "start": 630, "dur": 40, "script": "allhands", "mandatory": false},
		{"title": "1:1 with Todd", "start": 840, "dur": 30, "script": "one_on_one", "mandatory": true},
	],
	[
		{"title": "Daily Standup", "start": 570, "dur": 15, "script": "standup", "mandatory": true},
		{"title": "Weekly Performance Review", "start": 930, "dur": 40, "script": "review", "mandatory": true, "no_dodge": true},
	],
]

## Scripted events per day: [minute, event, args].
const WEEK_EVENTS := [
	[
		[544, "ping", {"id": "welcome"}],
		[551, "task", {"id": "pipeline"}],
		[615, "task", {"id": "button"}],
		[655, "ping", {"id": "favor_dave"}],
		[700, "mail", {"id": "welcome_hr"}],
		[905, "mail", {"id": "shady"}],
		[965, "ping", {"id": "timesheet"}],
	],
	[
		[548, "task", {"id": "deck"}],
		[592, "mail", {"id": "phish"}],
		[625, "say", {"who": "priya", "text": "Tip: the Alignment Sync at 11 is optional-ish. Block your calendar over it in SynerCalendar, then hit 'Decline: conflict'. The system approves it by itself."}],
		[775, "ping", {"id": "favor_kevin"}],
		[835, "task", {"id": "audit"}],
		[912, "mail", {"id": "storm"}],
		[965, "ping", {"id": "timesheet"}],
	],
	[
		[546, "mail", {"id": "audit_warn"}],
		[572, "audit", {"warned": true}],
		[672, "ping", {"id": "outage"}],
		[735, "mail", {"id": "training"}],
		[790, "ping", {"id": "favor_priya"}],
		[815, "task", {"id": "okr"}],
		[965, "ping", {"id": "timesheet"}],
	],
	[
		[545, "mail", {"id": "synerwatch"}],
		[546, "flag", {"id": "synerwatch"}],
		[600, "mail", {"id": "review_invite"}],
		[705, "ping", {"id": "volunteer"}],
		[765, "ping", {"id": "kevin_snitch"}],
		[800, "ping", {"id": "lunch_order"}],
		[880, "task", {"id": "selfreview"}],
		[925, "ping", {"id": "screen_check"}],
		[965, "ping", {"id": "timesheet"}],
	],
	[
		[550, "mail", {"id": "audit_warn"}],
		[577, "audit", {"warned": true}],
		[640, "demo_demand", {}],
		[745, "ping", {"id": "favor_dave"}],
		[815, "ping", {"id": "screen_check"}],
		[985, "ping", {"id": "timesheet"}],
	],
]

## Messages from Priya that double as the in-fiction tutorial voice.
const PRIYA_INTRO := [
	"psst. you're the new remote hire, right? rule one at SynerCorp: nobody checks the work. they check whether you LOOK busy.",
	"keep your Productivity Illusion up and your Suspicion down. and whatever you do, don't actually do the tickets. it'll wreck your health.",
]
