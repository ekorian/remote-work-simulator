#!/usr/bin/env python3
"""Seed resources for NPCs, deception claims, gadgets, combos and balancing."""
from lib import Color, clean, write, extract, ROOT
import os

# ---------------------------------------------------------------------------
# NPCs
# ---------------------------------------------------------------------------
NPCS = {
    "martin": dict(
        display_name="Martin Halloway", role="Manager, Synergy Enablement", color=Color("ff8c5a"), kind="manager",
        is_boss=True, chattiness=1.0, gullibility=0.0, start_relationship=50.0,
        look={"skin": 0, "hair": 4, "hair_color": 5, "shirt": 1, "pants": 1, "accessory": 1, "tie": True, "stache": True},
        mood_lines={
            "pleased": ["Honestly, {name}, you're one of the few people I don't worry about.", "Great energy this week. Keep leaning in."],
            "annoyed": ["Not loving the response times today, {name}.", "Let's tighten up, yeah? I shouldn't have to chase."],
            "suspicious": ["I'm going to be honest: I can't picture what your day looks like.", "I've started keeping notes. Just FYI. For alignment."],
            "furious": ["I am THIS close to looping in HR.", "Every time I look for you, you're somewhere else. Explain that to me."],
        },
        escalation_lines=[
            "",
            "{name}, I'm getting... vibes. Not great ones. Let's be more visible, yeah?",
            "New process, just for you: I want a status line from you every hour. I'll be checking.",
            "Formal heads-up: I've opened a file with People & Culture. Every gap from now on gets written down.",
        ],
    ),
    "priya": dict(display_name="Priya Nair", role="Staff Engineer (does everything)", color=Color("5ad1c8"), kind="coworker",
                  gullibility=-6.0, start_relationship=55.0, look={"skin": 3, "hair": 2, "hair_color": 0, "shirt": 6, "pants": 1, "accessory": 1}),
    "kevin": dict(display_name="Kevin Marsh", role="Associate Rockstar Ninja", color=Color("4fb3ff"), kind="coworker",
                  gullibility=4.0, start_relationship=45.0, look={"skin": 1, "hair": 3, "hair_color": 3, "shirt": 0, "pants": 0, "accessory": 2}),
    "dave": dict(display_name="Dave Kowalski", role="Senior Engineer (allegedly)", color=Color("ffd166"), kind="coworker",
                 gullibility=8.0, start_relationship=60.0, look={"skin": 2, "hair": 6, "hair_color": 1, "shirt": 4, "pants": 2, "accessory": 0, "stache": True}),
    "linda": dict(display_name="Linda from HR", role="People & Culture & Compliance", color=Color("ff9ecb"), kind="hr",
                  thread="general", has_dm=False, gullibility=-10.0, start_relationship=45.0,
                  look={"skin": 0, "hair": 1, "hair_color": 4, "shirt": 5, "pants": 1, "accessory": 1}),
    "it": dict(display_name="IT Helpdesk", role="Have you tried rebooting?", color=Color("b48cff"), kind="it",
               gullibility=-4.0, start_relationship=50.0, look={"skin": 4, "hair": 5, "hair_color": 7, "shirt": 3, "pants": 1, "accessory": 2}),
    "helena": dict(display_name="Helena Voss", role="SVP, Vertical Synergy", color=Color("e8546b"), kind="executive",
                   has_dm=False, thread="general", gullibility=-12.0, start_relationship=40.0,
                   look={"skin": 1, "hair": 1, "hair_color": 5, "shirt": 7, "pants": 1, "accessory": 0}),
    "bot": dict(display_name="SynerBot", role="Automated notifications", color=Color("8a86a8"), kind="bot",
                thread="general", has_dm=False),
}

# ---------------------------------------------------------------------------
# Deception: ten claim categories
# ---------------------------------------------------------------------------
OFFLINE = ["online_status", "desk_message", "video_meeting", "auto_message", "auto_report"]
CLAIMS = {
    "internet_outage": dict(
        title="Internet outage", line="My internet just died. Completely.",
        contexts=["chat", "meeting", "call"], base=54, duration=60, cover=60, reuse_penalty=16, risk=60,
        contradicted_by=OFFLINE + ["router_on"],
        conflicts=["prod_incident", "data_validation", "conflicting_meeting"],
        evidence={"router_off": 24, "outage_reported": 22},
        followups=[{"kind": "verify", "fact": "router_on", "who": "it", "after": [10, 14], "ok_line": "We pinged your router: dead. Confirmed outage on your end. Hang in there."}],
        strength="Explains total silence for an hour. Phone replies and phone meetings stay fine (mobile data).",
        weakness="IT pings your router in ~12 min: it must really be unplugged. Anything your computer does online exposes it, including your own gadgets.",
        accepted="Ugh, again? Fine. Ping me the second you're back.",
        rejected="Your status has been green all morning. Try again.",
        exposed={
            "default": "I thought your internet wasn't working?",
            "router_on": "IT just pinged your router. It answered. Happily. So what's actually going on?",
            "video_meeting": "You're on camera. In HD. I thought your internet wasn't working?",
            "online_status": "Your status has been green for ten minutes. On the internet you don't have.",
            "auto_report": "Your status report just arrived, right on schedule. From your dead internet.",
            "auto_message": "You just answered Kevin in chat. With what internet?",
        },
        recoveries=[
            {"t": "\"It literally just came back. This second.\"", "a": "bluff", "p": 50, "ok": {"susp": -2, "claim_status": "patched", "say": "Convenient. Fine. Welcome back."}, "ko": {"susp": 8, "claim_status": "exposed", "say": "It came back the moment I asked. Sure."}},
            {"t": "\"I'm tethering off my phone. It's costing me a fortune.\"", "a": "bluff", "p": 56, "ok": {"susp": -1, "claim_status": "patched", "say": "Oof. Expense it. (Don't expense it.)"}, "ko": {"susp": 7, "claim_status": "exposed", "say": "Tethering. With that upload speed. No."}},
        ],
    ),
    "computer_crash": dict(
        title="Computer crash", line="My laptop just blue-screened and it's installing 114 updates.",
        contexts=["chat", "meeting", "call", "ticket"], base=50, duration=45, cover=45, reuse_penalty=17, risk=45,
        contradicted_by=["online_status", "desk_message", "video_meeting", "ticket_activity", "auto_message", "auto_report"],
        conflicts=["data_validation", "prod_incident"],
        evidence={"laptop_updating": 30},
        effect={"extend": 240},
        followups=[{"kind": "event", "event": "it_remote_session", "after": [18, 30], "chance": 55}],
        strength="Much stronger while the company laptop really is updating. Buys a ticket four extra hours.",
        weakness="A crashed computer cannot post, update tickets or run gadgets. IT may open a remote session to 'help'.",
        accepted="IT strikes again. OK, shout when it's back.",
        rejected="IT says nothing was pushed to your machine today.",
        exposed={
            "default": "Your computer seems fine to me. It's doing things. Explain?",
            "ticket_activity": "Your 'crashed' laptop just updated a ticket. Explain?",
            "online_status": "Your crashed laptop is showing you as Available.",
            "video_meeting": "That's a very sharp picture for a laptop that's blue-screened.",
        },
        recoveries=[
            {"t": "\"I'm on my personal machine. Don't tell IT.\"", "a": "bluff", "p": 52, "ok": {"susp": -1, "claim_status": "patched", "say": "I heard nothing. Carry on."}, "ko": {"susp": 9, "claim_status": "exposed", "say": "Then I have to tell IT. Company policy."}},
            {"t": "\"It rebooted itself. Windows, eh?\"", "a": "blame", "p": 48, "ok": {"susp": -1, "claim_status": "patched", "say": "Ha. Classic."}, "ko": {"susp": 7, "claim_status": "exposed", "say": "You're on a Mac."}},
        ],
    ),
    "medical": dict(
        title="Medical appointment", line="I've got a {subject} appointment. It's been booked for weeks.",
        subjects=["dentist", "physio", "eye test", "dermatologist"],
        contexts=["chat", "meeting"], base=47, duration=90, cover=90, reuse_penalty=24, risk=30,
        contradicted_by=["online_status", "desk_message", "video_meeting", "ticket_activity", "auto_message"],
        conflicts=["prod_incident", "data_validation", "conflicting_meeting", "family_emergency"],
        evidence={"doctor_note": 34, "calendar_block": 18},
        followups=[{"kind": "event", "event": "hr_note_request", "after": [35, 70], "chance": 60}],
        strength="A long, guilt-free absence. A printed doctor's note makes it nearly bulletproof.",
        weakness="You are supposedly not at home: showing as Available (even via MouseMover) exposes it. HR may ask for the note.",
        accepted="Right, health first. See you after.",
        rejected="Weeks, you say. It's not in your calendar.",
        exposed={
            "default": "I thought you were at the {subject}?",
            "online_status": "You're showing as Available. From the {subject}'s chair?",
            "video_meeting": "Is the {subject} in the room with you right now?",
            "ticket_activity": "You updated a ticket from your {subject} appointment. Dedicated. Or lying.",
        },
        recoveries=[
            {"t": "\"They were running late, so I came home.\"", "a": "bluff", "p": 54, "ok": {"susp": -1, "claim_status": "patched", "say": "Typical. OK."}, "ko": {"susp": 8, "claim_status": "exposed", "say": "The appointment was twenty minutes ago."}},
            {"t": "\"I'm working from the waiting room. That's how committed I am.\"", "a": "jargon", "p": 46, "tags": ["jargon"], "ok": {"ill": 3, "claim_status": "patched", "say": "...That's actually impressive."}, "ko": {"susp": 8, "claim_status": "exposed", "say": "I can see your sofa."}},
        ],
    ),
    "family_emergency": dict(
        title="Family emergency", line="Family thing. It's my {subject}. I'd rather not get into it.",
        subjects=["grandmother", "brother", "aunt", "landlord (he's like family)"],
        contexts=["chat", "meeting", "call"], base=62, duration=120, cover=120, reuse_penalty=30, risk=15,
        contradicted_by=["social_post", "video_meeting", "auto_message"],
        conflicts=["prod_incident", "conflicting_meeting", "medical"],
        followups=[{"kind": "event", "event": "family_checkin", "after": [90, 150], "chance": 70}],
        strength="Nobody argues with it, and it covers two full hours.",
        weakness="Works once. Cheerful chat in group channels exposes it, and Martin WILL ask about your relative later: remember who it was.",
        accepted="Of course, of course. Family comes first. (After Q3.)",
        rejected="That's a lot of family for one week. How big is this family?",
        exposed={
            "default": "For someone in the middle of a family emergency, you seem remarkably chipper.",
            "social_post": "You just dropped a party emoji in #general. During your family emergency.",
            "video_meeting": "You're in a meeting. Smiling. How is your {subject}?",
            "auto_message": "You're replying 'Love this!' to Kevin. Is your {subject} OK or not?",
        },
        recoveries=[
            {"t": "\"It's how I cope. I keep busy.\"", "a": "bluff", "p": 50, "ok": {"susp": -1, "claim_status": "patched", "say": "...Fair. Take care of yourself."}, "ko": {"susp": 9, "claim_status": "exposed", "say": "With party emojis."}},
            {"t": "\"False alarm. Everyone's fine. Thanks for asking.\"", "a": "bluff", "p": 58, "ok": {"claim_status": "patched", "say": "Glad to hear it. So you're back, then."}, "ko": {"susp": 7, "claim_status": "exposed", "say": "That was a fast emergency."}},
        ],
    ),
    "conflicting_meeting": dict(
        title="Conflicting meeting", line="I'm double-booked with the {subject}. Can't get out of it.",
        subjects=["vendor sync", "client discovery call", "architecture guild", "skip-level"],
        contexts=["chat", "meeting"], base=46, duration=45, cover=45, reuse_penalty=14, risk=55,
        contradicted_by=["calendar_free"],
        conflicts=["internet_outage", "medical", "family_emergency"],
        evidence={"calendar_block": 34},
        followups=[
            {"kind": "verify", "fact": "calendar_free", "after": [5, 9], "ok_line": "Right, I see it on your calendar. Carry on."},
            {"kind": "event", "event": "other_meeting_notes", "after": [50, 80], "chance": 35},
        ],
        strength="Cheap and reusable. With a calendar block over the time, it checks out by itself.",
        weakness="Martin looks at your calendar within minutes. No block, no story. He may ask for notes afterwards.",
        accepted="Client first! Love the hustle.",
        rejected="Which meeting? I'm looking at your calendar and it's a desert.",
        exposed={"default": "I just checked your calendar. There is no {subject}. There is nothing. Explain?"},
        recoveries=[
            {"t": "\"It was an ad-hoc call. No invite.\"", "a": "bluff", "p": 48, "ok": {"susp": -1, "claim_status": "patched", "say": "Put it in the calendar next time. Visibility!"}, "ko": {"susp": 8, "claim_status": "exposed", "say": "With whom? Give me a name."}},
            {"t": "\"Calendar sync is broken again. Ask IT.\"", "a": "blame", "p": 44, "ok": {"claim_status": "patched", "say": "Ugh. I'll raise a ticket. (I won't.)"}, "ko": {"susp": 7, "claim_status": "exposed", "say": "IT says sync is fine."}},
        ],
    ),
    "prod_incident": dict(
        title="Production incident", line="I'm firefighting a production incident. All hands.",
        contexts=["chat", "meeting", "call", "ticket"], base=42, duration=60, cover=60, reuse_penalty=18, risk=65,
        contradicted_by=["no_incident"],
        conflicts=["internet_outage", "computer_crash", "medical", "family_emergency"],
        evidence={"incident_active": 40},
        effect={"ill": 5, "extend": 240},
        followups=[
            {"kind": "verify", "fact": "no_incident", "who": "priya", "after": [8, 14], "ok_line": "Confirmed, prod is on fire and {name} is in the channel. Leave them alone."},
            {"kind": "event", "event": "postmortem_request", "after": [45, 80], "chance": 70},
        ],
        strength="Makes you look like a hero: Productivity Illusion rises, and nobody interrupts a firefighter.",
        weakness="Only believable when something really is on fire. Otherwise Martin asks around. Heroes get asked to write the postmortem.",
        accepted="Go go go. I'll keep everyone off your back.",
        rejected="What incident? The dashboard is all green.",
        exposed={"default": "I asked Priya about the incident. She said 'what incident'. So did everyone else."},
        recoveries=[
            {"t": "\"I caught it before anyone noticed. You're welcome.\"", "a": "bluff", "p": 44, "tags": ["jargon"], "ok": {"ill": 4, "claim_status": "patched", "say": "...Proactive. I like it. Write it up."}, "ko": {"susp": 9, "claim_status": "exposed", "say": "There are no logs of anything happening. At all."}},
            {"t": "\"It was in staging. Still counts.\"", "a": "bluff", "p": 50, "ok": {"claim_status": "patched", "say": "Staging is not production. But fine."}, "ko": {"susp": 7, "claim_status": "exposed", "say": "Staging has been down since March."}},
        ],
    ),
    "data_validation": dict(
        title="Data validation", line="I'm validating the data before I touch anything. Can't rush it.",
        contexts=["chat", "ticket"], base=60, duration=75, cover=30, reuse_penalty=13, risk=20,
        contradicted_by=[],
        conflicts=["internet_outage", "computer_crash", "medical"],
        evidence={"high_illusion": 12},
        effect={"extend": 300},
        followups=[{"kind": "event", "event": "validation_results", "after": [55, 85], "chance": 85}],
        strength="Almost impossible to disprove on the spot. Buys a ticket five hours.",
        weakness="Martin will ask to see the validation results. You will have to produce something.",
        accepted="Good. Measure twice, cut once. Send me the results when you have them.",
        rejected="Validating what? The ticket is to rename a button.",
        exposed={"default": "You said you were validating the data. There is no data."},
        recoveries=[
            {"t": "\"The validation found that the data needs more validation.\"", "a": "jargon", "p": 46, "tags": ["jargon"], "ok": {"claim_status": "patched", "say": "...I can't argue with that. I want to. But I can't."}, "ko": {"susp": 8, "claim_status": "exposed", "say": "No."}},
        ],
    ),
    "waiting_team": dict(
        title="Waiting for another team", ticket_scoped=True, line="I'm blocked on the {subject} team. Ball's in their court.",
        subjects=["Platform", "Security", "Legal", "Data Engineering"],
        contexts=["chat", "ticket"], base=53, duration=180, cover=0, reuse_penalty=14, risk=50,
        contradicted_by=["team_denies", "ticket_activity"],
        conflicts=[],
        evidence={"clarification_open": 26},
        effect={"extend": 1440},
        followups=[
            {"kind": "verify", "fact": "team_denies", "after": [20, 35], "ok_line": "I chased them. They confirm they owe you an answer. Sit tight."},
            {"kind": "event", "event": "unblock_meeting", "after": [40, 70], "chance": 40},
        ],
        strength="Pushes a ticket back a full day. A clarification request on the ticket makes it check out.",
        weakness="Martin may ask that team. Touching the ticket while 'blocked' exposes you. He might book a meeting to unblock you.",
        accepted="Classic {subject}. I'll chase them. (I won't.)",
        rejected="I spoke to them this morning. They're waiting on YOU.",
        exposed={
            "default": "I just asked the {subject} team. They have never heard of you, or the ticket.",
            "ticket_activity": "You said you were blocked. You just posted progress. Which is it?",
        },
        recoveries=[
            {"t": "\"I must have pinged the wrong channel. Following up now.\"", "a": "bluff", "p": 52, "ok": {"claim_status": "patched", "say": "Do that. And cc me."}, "ko": {"susp": 8, "claim_status": "exposed", "say": "There's no message in any channel."}},
            {"t": "\"They unblocked me five minutes ago, actually!\"", "a": "bluff", "p": 46, "ok": {"susp": -1, "claim_status": "patched", "say": "Great timing. So it's moving again."}, "ko": {"susp": 7, "claim_status": "exposed", "say": "They said they've never talked to you."}},
        ],
    ),
    "process_blocker": dict(
        title="Corporate process blocker", ticket_scoped=True, line="It's stuck with the Change Advisory Board. I can't touch it until they approve.",
        contexts=["chat", "ticket"], base=55, duration=240, cover=0, reuse_penalty=15, risk=35,
        contradicted_by=["no_form", "ticket_activity"],
        conflicts=[],
        evidence={"form_filed": 30},
        effect={"extend": 1440},
        followups=[
            {"kind": "verify", "fact": "no_form", "after": [25, 45], "ok_line": "I found your Form 27-B in the queue. You're 14th. Nothing we can do."},
            {"kind": "event", "event": "expedited_approval", "after": [60, 110], "chance": 45},
        ],
        strength="Nobody at SynerCorp questions process. With a Form 27-B on file it is airtight, and the ticket slips a day.",
        weakness="Without the paperwork there is nothing to find. Martin may 'expedite' the approval and expect results the same day.",
        accepted="The CAB. Say no more. Nothing gets past the CAB.",
        rejected="The CAB hasn't met since 2021.",
        exposed={
            "default": "I called the Change Advisory Board. There is no request under your name.",
            "ticket_activity": "You're updating a ticket you said you weren't allowed to touch.",
        },
        recoveries=[
            {"t": "\"The form must be lost in the system. I'll resubmit.\"", "a": "blame", "p": 54, "ok": {"claim_status": "patched", "say": "The system does eat forms. Resubmit and cc me."}, "ko": {"susp": 7, "claim_status": "exposed", "say": "The system has never lost a form. It's the one thing that works."}},
        ],
    ),
    "hardware_malfunction": dict(
        title="Hardware malfunction", line="My {subject} just died. I can hear you but that's about it.",
        subjects=["webcam", "microphone", "headset", "docking station"],
        contexts=["chat", "meeting", "call"], base=57, duration=300, cover=30, reuse_penalty=18, risk=30,
        contradicted_by=["video_meeting"],
        conflicts=[],
        evidence={"printer_jam": 12},
        followups=[{"kind": "event", "event": "it_hardware_check", "after": [40, 90], "chance": 50}],
        strength="Gets you out of being on camera, and it lasts five hours.",
        weakness="For those five hours, joining ANY call on camera exposes it: use the phone. IT may run a hardware diagnostic, which is a device scan.",
        accepted="Tech, eh. Join by phone next time. I'll ask IT to send a replacement.",
        rejected="It worked fine in standup.",
        exposed={"default": "Your {subject} seems to have made a full recovery. I can see and hear you perfectly."},
        recoveries=[
            {"t": "\"I borrowed my neighbour's.\"", "a": "bluff", "p": 50, "ok": {"claim_status": "patched", "say": "Resourceful. OK."}, "ko": {"susp": 7, "claim_status": "exposed", "say": "It's the same one. It has your sticker on it."}},
            {"t": "\"It comes and goes. Loose cable. Very technical.\"", "a": "jargon", "p": 48, "tags": ["jargon"], "ok": {"claim_status": "patched", "say": "Get IT to look at it."}, "ko": {"susp": 6, "claim_status": "exposed", "say": "It's wireless."}},
        ],
    ),
}

# ---------------------------------------------------------------------------
# Gadgets and combinations
# ---------------------------------------------------------------------------
GADGETS = {
    "mousemover": dict(
        display_name="MouseMover.exe", kind="always", needs_net=False, unlock_day=1,
        blurb="Simulates mouse activity so your status stays Available while you are anywhere but your desk.",
        fail_event="mousemover_detected",
        fail_text="MouseMover.exe has drawn the same perfect circle 4,000 times. SynerWatch noticed.",
        levels=[
            {"price": 60, "reliability": 96.5, "heat": 8, "can": ["presence"], "text": "Status stays Available while it runs."},
            {"price": 70, "reliability": 98.0, "heat": 5, "can": ["presence"], "text": "'Human jitter' patch: wobbly, believable movement. More reliable, less Heat."},
            {"price": 110, "reliability": 99.0, "heat": 3, "can": ["presence", "pass_scan"], "text": "Replays your own recorded mouse movements. Passes SynerWatch activity scans."},
        ],
    ),
    "duck": dict(
        display_name="Keyboard Duck", kind="always", needs_net=False, unlock_day=1,
        blurb="A drinking duck that pecks the keyboard. Meaningless typing that slowly raises Productivity Illusion.",
        fail_event="duck_gibberish",
        fail_text="The Keyboard Duck fell onto Enter and posted its work to the whole company.",
        levels=[
            {"price": 95, "reliability": 95.5, "heat": 12, "ill": 0.08, "can": ["illusion"], "text": "Slowly raises Productivity Illusion."},
            {"price": 90, "reliability": 97.0, "heat": 9, "ill": 0.11, "can": ["illusion", "screen_fake"], "text": "Types into a scrolling fake code window: passes screen-share checks."},
            {"price": 130, "reliability": 98.5, "heat": 6, "ill": 0.14, "can": ["illusion", "screen_fake", "free_jargon"], "text": "Autocompletes buzzwords: fake updates, reports and jargon cost no Energy."},
        ],
    ),
    "chatbot": dict(
        display_name="Chatbot Team", kind="use", needs_net=True, unlock_day=2,
        blurb="A committee of chatbots that answers routine messages for you and invents plausible progress.",
        fail_event="chatbot_hallucination",
        fail_text="Chatbot Team just told the whole channel about a project that does not exist.",
        levels=[
            {"price": 140, "reliability": 87.0, "heat": 14, "can": ["auto_reply"], "text": "Answers routine pings with confident filler."},
            {"price": 120, "reliability": 90.0, "heat": 12, "update_every": 90, "can": ["auto_reply", "auto_updates"], "text": "Also posts fictional progress updates on your tickets every 90 minutes."},
            {"price": 150, "reliability": 93.0, "heat": 10, "update_every": 75, "can": ["auto_reply", "auto_updates", "auto_report"], "text": "Also sends the daily status report at the time you choose."},
        ],
    ),
    "assistant": dict(
        display_name="Meeting Assistant", kind="use", needs_net=True, unlock_day=3,
        blurb="Listens to meetings and generates corporate-sounding answers on your behalf.",
        fail_event="assistant_absurd",
        fail_text="Meeting Assistant answered a question about the budget with a recipe for banana bread.",
        levels=[
            {"price": 160, "reliability": 86.0, "heat": 10, "can": ["meeting_answers"], "text": "Adds 'Let the Meeting Assistant answer' to every meeting question."},
            {"price": 130, "reliability": 90.0, "heat": 8, "can": ["meeting_answers", "auto_answer"], "text": "Steps in by itself when you freeze, instead of awkward silence."},
            {"price": 170, "reliability": 94.0, "heat": 6, "can": ["meeting_answers", "auto_answer"], "text": "Reads the room. Markedly more reliable."},
        ],
    ),
    "doppelganger": dict(
        display_name="AI Doppelganger", kind="use", needs_net=True, unlock_day=3,
        requires={"chatbot": 1, "assistant": 1},
        blurb="An AI clone built from your chatbots and meeting assistant. It attends meetings as you. It has opinions.",
        fail_event="doppel_meltdown",
        fail_text="Your AI Doppelganger froze mid-nod, then announced it was 'pivoting to consulting'.",
        levels=[
            {"price": 260, "reliability": 85.0, "heat": 18, "chaos": 10, "can": ["attend_meetings", "autonomous"], "text": "Attends optional meetings for you, automatically, while switched on."},
            {"price": 200, "reliability": 89.0, "heat": 16, "chaos": 14, "can": ["attend_meetings", "autonomous", "do_tickets"], "text": "Also works one assigned ticket in the background. Has started 'having ideas'."},
            {"price": 240, "reliability": 92.0, "heat": 14, "chaos": 18, "can": ["attend_meetings", "autonomous", "do_tickets"], "text": "More convincing than you are. More reliable. Noticeably more independent."},
        ],
    ),
}

COMBOS = {
    "ghost_shift": dict(
        display_name="Ghost Shift", needs=["mousemover", "chatbot"],
        text="MouseMover keeps you green while Chatbot Team answers at once instead of waiting. Routine pings never reach you.",
        effects={"reply_early": 1, "heat": 4},
    ),
    "desk_theatre": dict(
        display_name="Desk Theatre", needs=["mousemover", "duck"],
        text="Mouse and keyboard moving together look human: Heat drops, but one jam takes the whole act down.",
        effects={"heat": -6, "fail": 15},
    ),
    "empty_chair": dict(
        display_name="Empty Chair", needs=["assistant", "doppelganger"],
        text="The Meeting Assistant feeds your clone its lines: it can now attend MANDATORY meetings too. If it goes wrong, it goes very wrong.",
        effects={"attend_mandatory": 1, "chaos": 60, "heat": 8},
    ),
}

# ---------------------------------------------------------------------------
# Balancing
# ---------------------------------------------------------------------------
DIFFS = {
    "intern": dict(
        display_name="Intern", tag="RELAXED", color=Color("5ad17a"), susp=0.6, work_hp=2.0, lethal=False, recover=1.4, window=1.6,
        gadget_fail=0.6, event_rate=0.8, boss_check=0.7, cost=0.85, cred=10, stress=0.5, score=1.0,
        desc="Nobody expects anything from you. Low suspicion, generous recovery, a forgiving boss and long reaction windows. Work stings a little: 2 HP per action."),
    "survivor": dict(
        display_name="Corporate Survivor", tag="STANDARD", color=Color("4fb3ff"), susp=1.0, work_hp=8.0, lethal=False, recover=1.0, window=1.0,
        gadget_fail=1.0, event_rate=1.0, boss_check=1.0, cost=1.0, cred=0, stress=1.0, score=1.6,
        desc="The intended experience. Normal suspicion, regular interruptions, moderate automation costs. Work hurts: 8 HP per action."),
    "senior": dict(
        display_name="Senior Bullshitter", tag="HARD", color=Color("ffb347"), susp=1.7, work_hp=20.0, lethal=False, recover=0.85, window=0.8,
        gadget_fail=1.5, event_rate=1.2, boss_check=1.35, cost=1.15, cred=-5, stress=1.4, score=2.6,
        desc="Suspicion x1.7. Frequent manager checks. Gadgets break when you need them most. Work is agony: 20 HP per action."),
    "unemployed": dict(
        display_name="Professional Unemployed", tag="EXTREME", color=Color("ff5d73"), susp=1.5, work_hp=999.0, lethal=True, recover=0.85, window=0.8,
        gadget_fail=1.3, event_rate=1.2, boss_check=1.4, cost=1.1, cred=-5, stress=1.3, score=4.0,
        desc="ANY legitimate work action ends the run instantly. Survive the whole week on avoidance, delegation, deception and automation alone."),
}


def main():
    for folder in ["npcs", "deception", "gadgets", "gadgets/combos", "balancing"]:
        clean(folder)
    for rid, f in NPCS.items():
        write("npcs", "npc_def", "NpcDef", rid, f)
    for rid, f in CLAIMS.items():
        write("deception", "claim_def", "ClaimDef", rid, f)
    for rid, f in GADGETS.items():
        write("gadgets", "gadget_def", "GadgetDef", rid, f)
    for rid, f in COMBOS.items():
        write("gadgets/combos", "combo_def", "ComboDef", rid, f)
    for rid, f in DIFFS.items():
        write("balancing", "difficulty_def", "DifficultyDef", rid, f)
    src = open(os.path.join(ROOT, "tools/seed/old_content.gd.txt")).read()
    for rid, t in extract(src, "TASKS").items():
        write("tasks", "task_def", "TaskDef", rid, t)
    print("systems: %d npcs, %d claims, %d gadgets, %d combos, %d difficulties" % (len(NPCS), len(CLAIMS), len(GADGETS), len(COMBOS), len(DIFFS)))


if __name__ == "__main__":
    main()
