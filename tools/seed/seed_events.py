#!/usr/bin/env python3
"""Seed resources for events, dialogue, and flavour text."""
import os
from lib import clean, write, extract, rename, ROOT

T, F = True, False
src = open(os.path.join(ROOT, "tools/seed/old_content.gd.txt")).read()
NAMES = [("todd", "martin"), ("Todd", "Martin")]
PINGS = rename(extract(src, "PINGS"), NAMES)
MAILS = rename(extract(src, "MAILS"), NAMES)
CALLS = rename(extract(src, "CALLS"), NAMES)
BEATS = rename(extract(src, "BEAT_POOL"), NAMES)
WEEK_EVENTS = rename(extract(src, "WEEK_EVENTS"), NAMES)
CHATTER = rename(extract(src, "CHATTER"), NAMES)

EVENTS = {}


def ev(eid, **f):
    f.setdefault("schedule", [])
    EVENTS[eid] = f
    return f


def at(eid, day, minute, **extra):
    slot = {"day": day, "at": minute}
    slot.update(extra)
    EVENTS[eid]["schedule"].append(slot)


# ---------------------------------------------------------------------------
# Carried over: chat pings
# ---------------------------------------------------------------------------
BOSS_POOL = ["quick_q", "thoughts", "numbers", "task_status", "you_there", "article", "blockers", "weekend", "emoji"]
PEER_POOL = ["kevin_brag", "it_survey", "priya_branch", "linda_form", "dave_cover"]
SKIP = {"screen_check", "demo_demand", "block_audit", "why_away"}     # rewritten below
for pid, p in PINGS.items():
    if pid in SKIP:
        continue
    cond = {}
    if "{task}" in p["text"]:
        cond["open_task"] = T
    ev(pid, title=pid.replace("_", " ").capitalize(), kind="chat", **{"from": p["from"]}, thread=p.get("thread", ""),
       text=p["text"], choices=p["choices"], expire=p.get("expire", {}), window=p.get("window", 25),
       routine=p.get("routine", F), no_excuse=p.get("no_excuse", F), conditions=cond,
       pool="boss" if pid in BOSS_POOL else ("peer" if pid in PEER_POOL else ""))
EVENTS["numbers"]["conditions"]["day_min"] = 1
EVENTS["weekend"]["conditions"]["day_min"] = 2

# --- Required event: surprise boss message (one more, about lies) ------------
ev("status_line", title="Hourly status", kind="chat", **{"from": "martin"}, routine=T, window=20, trigger="state", cooldown=75,
   conditions={"escalation_min": 2},
   text="Hourly status line, please. One sentence. What did the last hour produce?",
   choices=[
       {"t": "\"Solid momentum on the critical path.\"", "a": "jargon", "p": 76, "tags": ["jargon"], "ok": {"ill": 2, "susp": -2, "say": "Noted."}, "ko": {"susp": 3, "say": "That's what you said last hour. Word for word."}},
       {"t": "Describe an hour of work that never happened.", "a": "bluff", "p": 62, "ok": {"ill": 3, "susp": -3, "say": "Good. Keep that up."}, "ko": {"susp": 4, "say": "I can see the board. None of that happened."}},
       {"t": "Give an honest, detailed account", "a": "real_answer", "ok": {"ill": 5, "susp": -4, "say": "This is what I'm talking about."}},
   ],
   expire={"susp": 5, "say": "No status line. Writing that down."})

# --- Required event: urgent unfinished task ----------------------------------
ev("urgent_task", title="Urgent unfinished task", kind="chat", **{"from": "martin"}, window=16, trigger="state", cooldown=45,
   conditions={"urgent_task": T}, args={"mark_task": "nagged"},
   text="{task} is due in under two hours and the board says it's barely started. What's going on?",
   choices=[
       {"t": "\"It's much further along than the board shows.\"", "a": "bluff", "p": 58, "ok": {"susp": -1, "ill": 2, "say": "Then update the board. I'm watching it."}, "ko": {"susp": 6, "say": "Show me.", "later": {"in": 12, "ev": "demo_demand"}}},
       {"t": "Post a burst of fake updates right now.", "a": "fake_update", "p": 66, "tags": ["jargon"], "ok": {"ill": 4, "say": "There we go. Was that so hard?"}, "ko": {"susp": 5, "say": "Three updates in one minute. Sure."}},
       {"t": "Call in a favour: get it done quietly.", "a": "delegate_colleague", "req": {"favor": 1}, "ok": {"give": "priya", "susp": -2, "say": "Priya says she's 'helping'. Fine by me."}},
       {"t": "Drop everything and actually do it", "a": "work_task", "ok": {"progress": 1, "susp": -4, "say": "That's the spirit."}},
   ],
   expire={"susp": 9, "say": "Silence. With two hours to go."})

# --- Required event: accidental screen share (injected into video calls) -----
ev("screen_share", title="Accidental screen share", kind="system", action="inject", trigger="call_join", cooldown=1440,
   conditions={"day_min": 1}, args={"dialogue": "screen_share", "chance": 26},
   difficulty={"intern": {"chance": 0.5}, "senior": {"chance": 1.4}, "unemployed": {"chance": 1.3}})

# --- Required event: internet outage excuse ----------------------------------
ev("vpn_trouble", title="Internet outage excuse", kind="chat", **{"from": "martin"}, window=18, once=T,
   text="Half the team is reporting connection trouble this morning. Are you affected too?",
   choices=[
       {"t": "\"Yes! Totally down. I'm typing this from my phone.\"", "a": "bluff", "ok": {"claim": "internet_outage", "say": "Ugh. OK, sit tight. I'll have IT confirm it on your side."}},
       {"t": "\"It's flaky. Comes and goes.\"", "a": "bluff", "p": 62, "ok": {"cover": 20, "say": "Same as everyone. Do what you can."}, "ko": {"susp": 5, "say": "IT says your line is the only stable one."}},
       {"t": "\"Nope, rock solid here.\"", "a": "honest", "ok": {"susp": -2, "task": "oncall", "say": "Perfect. Then you can cover Kevin's on-call handover while the others are down."}},
   ],
   expire={"susp": 5, "say": "No answer. I'll assume you're fine."})
at("vpn_trouble", 2, 625)
ev("isp_outage", title="Real outage", kind="system", action="isp_outage", args={"minutes": 25})
at("isp_outage", 1, [690, 900], chance=35)
at("isp_outage", 3, [660, 760], chance=35)

# --- Required event: mouse jiggler malfunction -------------------------------
ev("mousemover_detected", title="Mouse jiggler malfunction", kind="chat", **{"from": "it"}, window=15, no_excuse=T,
   facts=["online_status"],
   text="Automated alert: your cursor has traced the same 40-pixel circle for 43 minutes. Please explain.",
   choices=[
       {"t": "\"My cat sleeps on the mouse.\"", "a": "bluff", "p": 50, "ok": {"susp": -1, "say": "...We've had three of those this week. Closing the alert."}, "ko": {"susp": 8, "say": "Your HR file says you're allergic to cats."}},
       {"t": "\"It's an accessibility tool. For my wrists.\"", "a": "bluff", "p": 44, "ok": {"fix_gadget": T, "say": "Understood. We've whitelisted the device. Sorry to have asked."}, "ko": {"susp": 9, "say": "Accessibility tools don't draw perfect circles."}},
       {"t": "\"The mouse is faulty. It's been doing that all day.\"", "a": "bluff", "p": 56, "ok": {"claim": "hardware_malfunction", "say": "A hardware fault. We'll run a diagnostic and send a replacement."}, "ko": {"susp": 7, "say": "The mouse reports it's in perfect health."}},
       {"t": "Admit it's a mouse jiggler.", "a": "honest", "ok": {"susp": 10, "rel": 3, "say": "Thank you for your honesty. Your manager has been informed."}},
   ],
   expire={"susp": 11, "say": "No explanation received. Escalated to your manager."})

# --- Required event: surprise video call -------------------------------------
ev("surprise_call", title="Martin is calling", kind="call", **{"from": "martin"}, pool="call",
   meeting={"dur": 12, "script": "sync", "mandatory": F})

# --- Required event: corporate productivity audit ----------------------------
ev("audit_notice", title="Scan notice", kind="mail", **{"from": "it"}, subject=MAILS["audit_warn"]["subject"], body=MAILS["audit_warn"]["body"])
ev("audit_scan", title="Device scan", kind="system", action="audit", args={"warned": T})
ev("audit_surprise", title="Unannounced device scan", kind="system", action="audit", args={"warned": F}, cooldown=120)
for day, notice, scan in [(2, 546, 572), (4, 550, 577)]:
    at("audit_notice", day, notice)
    at("audit_scan", day, scan)
at("audit_surprise", 3, [800, 950])
at("audit_surprise", 1, [800, 950], diffs=["senior", "unemployed"])
ev("audit_flagged", title="Scan: device disabled", kind="chat", **{"from": "it"}, window=15, no_excuse=T,
   text="SynerWatch disabled an unauthorised device on your machine ({gadget}). Explain within 15 minutes.",
   choices=[
       {"t": "\"It's a USB desk fan.\"", "a": "bluff", "p": 46, "ok": {"susp": -2, "say": "A fan. Logged as: fan."}, "ko": {"susp": 8, "say": "It identifies itself to the OS as 'TotallyNotAJiggler'."}},
       {"t": "\"That's assistive tech. Re-enable it, please.\"", "a": "bluff", "p": 40, "ok": {"fix_gadget": T, "say": "Apologies. Re-enabled and whitelisted."}, "ko": {"susp": 9, "say": "We checked with Occupational Health. No record."}},
       {"t": "\"I have no idea what that is. Is my machine compromised?!\"", "a": "deflect", "p": 54, "ok": {"susp": -1, "say": "Possibly. We'll reimage it tonight. Don't worry."}, "ko": {"susp": 7, "say": "It's plugged into your USB port."}},
       {"t": "Admit to the gadget.", "a": "honest", "ok": {"susp": 9, "rel": 2, "say": "Noted. A confiscation form is in your inbox."}},
   ],
   expire={"susp": 12, "say": "No explanation. Escalated."})
ev("productivity_audit", title="Corporate productivity audit", kind="chat", **{"from": "linda"}, thread="general", window=20, no_excuse=T,
   text="CORPORATE PRODUCTIVITY AUDIT. {name}: you logged 8.0 hours yesterday. SynerWatch recorded 14 minutes of 'intentional input'. Please reconcile.",
   choices=[
       {"t": "\"I think on paper. Real work isn't typing.\"", "a": "jargon", "p": 54, "tags": ["jargon"], "ok": {"susp": -3, "ill": 3, "say": "...Leadership actually agrees with that. Audit closed."}, "ko": {"susp": 9, "say": "Please submit the paper."}},
       {"t": "\"SynerWatch can't see my second machine.\"", "a": "bluff", "p": 48, "ok": {"susp": -2, "say": "We'll add it to the asset register. Audit closed."}, "ko": {"susp": 9, "say": "You were issued one machine."}},
       {"t": "Show the Keyboard Duck's activity log as your own.", "a": "use_gadget", "ability": "illusion", "req": {"ability": "illusion"}, "ok": {"susp": -5, "ill": 5, "say": "11,000 keystrokes an hour. Remarkable. Audit closed."}, "ko": {"susp": 10, "say": "The log is the letter J, eleven thousand times."}},
       {"t": "Reconstruct yesterday honestly, line by line", "a": "real_timesheet", "ok": {"susp": -7, "ill": 5, "say": "Thorough. Audit closed with commendation."}},
   ],
   expire={"susp": 12, "ill": -4, "say": "No response to a compliance audit. Your manager has been cc'd."})
at("productivity_audit", 3, 895)

# --- Required event: meeting with senior management --------------------------
ev("skip_level", title="Skip-Level with Helena Voss (SVP)", kind="meeting", **{"from": "helena"},
   meeting={"dur": 30, "script": "senior", "mandatory": T, "who": "helena"})
at("skip_level", 3, 780)
ev("skip_level_notice", title="Skip-level invite", kind="mail", **{"from": "martin"}, subject="Thursday 13:00 - Skip-Level with Helena Voss",
   body="{name},\n\nHelena (SVP, Vertical Synergy) is doing skip-levels and picked YOU. I don't know why. Please don't say anything that makes me look bad.\n\nShe asks real questions. She remembers the answers.\n\nMartin")
at("skip_level_notice", 2, 905)

# ---------------------------------------------------------------------------
# Meetings (from the old week plan) and the review
# ---------------------------------------------------------------------------
ev("standup", title="Daily Standup", kind="meeting", **{"from": "martin"}, meeting={"dur": 15, "script": "standup", "mandatory": T})
for d in range(5):
    at("standup", d, 570)
ev("planning", title="Sprint Planning", kind="meeting", **{"from": "martin"}, meeting={"dur": 50, "script": "planning", "mandatory": F})
at("planning", 0, 840)
ev("alignment", title="Cross-Functional Alignment Sync", kind="meeting", **{"from": "kevin"}, meeting={"dur": 45, "script": "alignment", "mandatory": F, "who": "kevin"})
at("alignment", 1, 660)
ev("fun", title="Mandatory Fun: Virtual Team Building", kind="meeting", **{"from": "linda"}, meeting={"dur": 45, "script": "fun", "mandatory": T, "who": "linda"})
at("fun", 2, 900)
ev("allhands", title="All-Hands: Exciting Changes", kind="meeting", **{"from": "martin"}, meeting={"dur": 40, "script": "allhands", "mandatory": F})
at("allhands", 3, 630)
ev("one_on_one", title="1:1 with Martin", kind="meeting", **{"from": "martin"}, meeting={"dur": 30, "script": "one_on_one", "mandatory": T})
at("one_on_one", 3, 855)
ev("review", title="Weekly Performance Review", kind="meeting", **{"from": "martin"}, meeting={"dur": 40, "script": "review", "mandatory": T, "no_dodge": T})
at("review", 4, 930)
ev("unblock_call", title="Unblocking call", kind="call", **{"from": "martin"}, meeting={"dur": 15, "script": "unblock", "mandatory": T})

# ---------------------------------------------------------------------------
# Mail
# ---------------------------------------------------------------------------
for mid, m in MAILS.items():
    if mid == "audit_warn":
        continue
    ev(mid, title=m["subject"], kind="mail", **{"from": m["from"]}, subject=m["subject"], body=m["body"],
       choices=m.get("choices", []), expire=m.get("expire", {}), window=m.get("window", 90))
EVENTS["shady"]["body"] = ("TIRED of MOVING your MOUSE like a PEASANT??\n\nNEW TODAY: MouseMover.exe and the Keyboard Duck. Your status stays green while you nap.\n\n"
                           "Visit ShadyDeals.biz from your PERSONAL computer (not the company one, we are not animals).\n\nNew stock every day this week. Upgrades available.")
ev("combo_deals", title="Combo deals", kind="mail", **{"from": "it"}, subject="[SPAM?] ShadyDeals.biz - COMBO WEEK",
   body=("Some of our products are BETTER TOGETHER:\n\n- MouseMover + Chatbot Team = GHOST SHIFT (routine pings never reach you)\n"
         "- MouseMover + Keyboard Duck = DESK THEATRE (less Heat, but they jam together)\n"
         "- Meeting Assistant + AI Doppelganger = EMPTY CHAIR (your clone attends MANDATORY meetings)\n\n"
         "Combinations switch on by themselves when both gadgets are running. ShadowIT shows which are active.\n\n"
         "WARNING: worn gadgets FAIL. Failures have CONSEQUENCES. Service them."))
ev("formal_warning", title="Formal warning", kind="mail", **{"from": "linda"}, window=60, once=T,
   subject="FORMAL WARNING: Engagement Metrics",
   body="{name},\n\nYour manager has raised concerns about your 'visibility' and 'responsiveness'. This letter goes in your file.\n\nYou may acknowledge it or contest it under Policy 9.\n\nLinda",
   choices=[
       {"t": "Sign the acknowledgment.", "a": "ack", "ok": {"susp": -2, "say": "Linda: Acknowledged. Let's see improvement."}},
       {"t": "Contest it: request the underlying data under Policy 9.", "a": "escalate", "p": 52, "tags": ["jargon"], "ok": {"susp": -9, "say": "Linda: The data request will take 6 to 8 weeks. The warning is suspended until then."}, "ko": {"susp": 5, "say": "Linda: Policy 9 was repealed. By Policy 10."}},
   ],
   expire={"susp": 6, "say": "Linda: Unacknowledged. Noted in your file."})

# ---------------------------------------------------------------------------
# Reactive chat events
# ---------------------------------------------------------------------------
P = PINGS
ev("why_away", title="Where are you?", kind="chat", **{"from": "martin"}, window=16, trigger="state", cooldown=120,
   conditions={"absent_min": 45}, text=P["why_away"]["text"], choices=P["why_away"]["choices"], expire=P["why_away"]["expire"])
ev("low_illusion", title="Invisible", kind="say", **{"from": "martin"}, trigger="state",
   conditions={"ill_max": 18, "from": 600}, text="I haven't seen a single thing from you today. Not a commit, not an emoji. Nothing.")
ev("micromanage", title="Micromanaged", kind="say", **{"from": "martin"}, once=T,
   text="From now on I want an hourly status line from you. I'll ping for it. This is not a punishment. It's 'enablement'.")
ev("block_audit", title="Calendar question", kind="chat", **{"from": "martin"}, window=20,
   text=P["block_audit"]["text"], choices=P["block_audit"]["choices"], expire=P["block_audit"]["expire"])
sc = P["screen_check"]["choices"]
sc[0] = {"t": "Share the Keyboard Duck's fake code window.", "a": "use_gadget", "ability": "screen_fake", "req": {"ability": "screen_fake"},
         "ok": {"susp": -5, "ill": 5, "say": "Whoa, that's a lot of code. OK, false alarm."}, "ko": {"susp": 12, "say": "Why does your screen say DEMO MODE?"}}
ev("screen_check", title="Screen check", kind="chat", **{"from": "martin"}, window=14, conditions={"flag": "synerwatch"},
   text=P["screen_check"]["text"], choices=sc, expire=P["screen_check"]["expire"])
at("screen_check", 3, 925)
at("screen_check", 4, 815)
dd = P["demo_demand"]["choices"]
dd[1] = {"t": "Share the Keyboard Duck's fake code window.", "a": "use_gadget", "ability": "screen_fake", "req": {"ability": "screen_fake"},
         "ok": {"susp": -4, "ill": 6, "say": "Looks complicated. Good."}, "ko": {"susp": 12, "say": "Why does your screen say DEMO MODE?"}}
ev("demo_demand", title="Demo demand", kind="chat", **{"from": "martin"}, window=18, conditions={"faked_task": T}, args={"mark_task": "demo_asked"},
   text=P["demo_demand"]["text"], choices=dd, expire=P["demo_demand"]["expire"])
at("demo_demand", 4, 640)

# --- Follow-ups to lies -------------------------------------------------------
ev("it_remote_session", title="Remote session", kind="chat", **{"from": "it"}, window=14, no_excuse=T,
   text="We see you reported a crash. Opening a remote session on your laptop to take a look. OK?",
   choices=[
       {"t": "\"Sure, go ahead.\"", "a": "ack", "evidence": "laptop_updating", "ok": {"susp": -3, "say": "Yep, it's stuck on update 61 of 114. Nothing we can do. Sorry!"}, "ko": {"susp": 9, "claim_status": "exposed", "say": "We're in. It's running perfectly. There's a game of solitaire open."}},
       {"t": "\"It fixed itself! No need.\"", "a": "bluff", "p": 56, "ok": {"claim_status": "patched", "say": "Great. Closing the ticket."}, "ko": {"susp": 6, "say": "We'd like to look anyway."}},
       {"t": "\"Now's not a good time. I'm presenting.\"", "a": "deflect", "p": 48, "ok": {"say": "No problem. We'll try tomorrow."}, "ko": {"susp": 6, "say": "Presenting. On the crashed laptop."}},
   ],
   expire={"susp": 7, "say": "No reply. We remoted in anyway. Your manager has the screenshot."})
ev("hr_note_request", title="Doctor's note", kind="chat", **{"from": "linda"}, thread="general", window=30, no_excuse=T,
   text="{name}, please upload the note from today's {subject} appointment for your absence record.",
   choices=[
       {"t": "Upload the doctor's note.", "a": "forge_note", "req": {"evidence": "doctor_note"}, "ok": {"susp": -4, "say": "Received. That is a very elaborate letterhead."}},
       {"t": "\"It's in the post.\"", "a": "bluff", "p": 46, "ok": {"say": "We'll wait."}, "ko": {"susp": 6, "say": "They email them now."}},
       {"t": "\"They don't do notes for check-ups.\"", "a": "bluff", "p": 52, "ok": {"say": "Fine. Marked as 'unverified'."}, "ko": {"susp": 6, "say": "I called. They do."}},
   ],
   expire={"susp": 6, "say": "No note received. Absence marked as unexplained."})
ev("family_checkin", title="How's the family?", kind="chat", **{"from": "martin"}, window=24, no_excuse=T,
   text="Meant to ask: how are things with your family emergency? Who was it again?",
   choices=[
       {"t": "\"My grandmother. She's much better.\"", "a": "bluff", "match": "grandmother", "ok": {"susp": -2, "rel": 2, "say": "Glad to hear it. Give her my best."}, "ko": {"susp": 9, "claim_status": "exposed", "say": "Yesterday it was someone else. I wrote it down."}},
       {"t": "\"My brother. Long story.\"", "a": "bluff", "match": "brother", "ok": {"susp": -2, "rel": 2, "say": "Brothers, eh. Glad it's sorted."}, "ko": {"susp": 9, "claim_status": "exposed", "say": "Yesterday it was someone else. I wrote it down."}},
       {"t": "\"My aunt. She's stable.\"", "a": "bluff", "match": "aunt", "ok": {"susp": -2, "rel": 2, "say": "Good. Take the time you need."}, "ko": {"susp": 9, "claim_status": "exposed", "say": "Yesterday it was someone else. I wrote it down."}},
       {"t": "\"My landlord. He's like family.\"", "a": "bluff", "match": "landlord (he's like family)", "ok": {"susp": -1, "say": "...Right. Glad he's OK."}, "ko": {"susp": 9, "claim_status": "exposed", "say": "Yesterday it was someone else. I wrote it down."}},
   ],
   expire={"susp": 5, "say": "No answer. Hope everything's alright. I'll ask again."})
ev("other_meeting_notes", title="Meeting notes", kind="chat", **{"from": "martin"}, window=24,
   text="How did the {subject} go? Send me the notes when you get a sec.",
   choices=[
       {"t": "Send three bullet points of pure jargon.", "a": "jargon", "p": 66, "tags": ["jargon"], "ok": {"ill": 3, "say": "Great notes. Very aligned."}, "ko": {"susp": 6, "say": "These are the same three bullets as last time."}},
       {"t": "\"It was mostly confidential.\"", "a": "bluff", "p": 50, "ok": {"say": "Ooh. Understood."}, "ko": {"susp": 6, "say": "I'm your manager."}},
       {"t": "Write up real notes for a meeting that never happened", "a": "write_report", "ok": {"ill": 6, "susp": -3, "say": "Detailed! Forwarding these on."}},
   ],
   expire={"susp": 5})
ev("postmortem_request", title="Postmortem", kind="chat", **{"from": "martin"}, window=24,
   text="Great work on the incident. Since you were in the middle of it: can you write the postmortem?",
   choices=[
       {"t": "\"On it.\"", "a": "accept_duty", "ok": {"susp": -5, "ill": 5, "task": "postmortem", "say": "Knew I could count on you."}},
       {"t": "\"Kevin should. It's a growth opportunity.\"", "a": "deflect", "p": 60, "tags": ["jargon"], "ok": {"say": "Good call. Kevin, you're up."}, "ko": {"susp": 5, "task": "postmortem", "say": "You were the one firefighting. It's yours."}},
       {"t": "Send a generated postmortem.", "a": "fake_report", "p": 58, "tags": ["jargon"], "ok": {"ill": 5, "say": "'Root cause: synergy drift.' Works for me."}, "ko": {"susp": 7, "say": "This postmortem is about a different company."}},
   ],
   expire={"susp": 5, "task": "postmortem", "say": "Silence means yes. It's yours."})
ev("validation_results", title="Validation results", kind="chat", **{"from": "martin"}, window=22,
   text="You said you were validating the data for {task}. Send me the results?",
   choices=[
       {"t": "Send a spreadsheet of plausible numbers.", "a": "fake_report", "p": 58, "ok": {"ill": 4, "say": "Green cells. Lots of green cells. Good."}, "ko": {"susp": 8, "say": "Every value in this sheet is 42."}},
       {"t": "\"The validation is still running.\"", "a": "stall", "p": 52, "ok": {"say": "OK. Tomorrow, then."}, "ko": {"susp": 6, "say": "It's a spreadsheet, not a rocket launch."}},
       {"t": "\"It passed. Verbally.\"", "a": "jargon", "p": 44, "tags": ["jargon"], "ok": {"say": "...I'll take it."}, "ko": {"susp": 7, "say": "That is not a thing."}},
       {"t": "Actually validate the data", "a": "work_task", "ok": {"progress": 1, "ill": 5, "susp": -4, "say": "Real numbers! Thank you."}},
   ],
   expire={"susp": 8, "say": "No results. So no validation. Got it."})
ev("unblock_meeting", title="Unblocking you", kind="chat", **{"from": "martin"}, window=16, no_excuse=T,
   text="I hate seeing you blocked. I've pulled the {subject} team into a call in ten minutes to sort it out.",
   choices=[
       {"t": "\"Amazing, thanks.\" (Dread.)", "a": "ack", "ok": {"event": "unblock_call", "say": "Dialling them now."}},
       {"t": "\"They literally just replied! We're unblocked.\"", "a": "bluff", "p": 54, "ok": {"claim_status": "patched", "say": "Oh! Great. I'll cancel."}, "ko": {"susp": 6, "event": "unblock_call", "say": "Then they can confirm that on the call."}},
   ],
   expire={"susp": 5, "event": "unblock_call", "say": "I'll take that as a yes."})
ev("expedited_approval", title="Expedited approval", kind="chat", **{"from": "martin"}, window=20,
   text="Good news! I leaned on the Change Advisory Board and they fast-tracked your request. Approved. So {task} lands today, right?",
   choices=[
       {"t": "\"Absolutely. Today.\"", "a": "bluff", "ok": {"due_in": 150, "susp": -2, "say": "That's what I like to hear."}},
       {"t": "\"It still needs sign-off from Security.\"", "a": "jargon", "p": 52, "tags": ["jargon"], "ok": {"say": "Of course it does. Fine."}, "ko": {"susp": 7, "due_in": 150, "say": "Security signed off this morning. Today, {name}."}},
       {"t": "Do the work now that it's approved", "a": "work_task", "ok": {"progress": 1, "susp": -4, "say": "Finally."}},
   ],
   expire={"susp": 6, "due_in": 150, "say": "I'll assume that's a yes. Today."})
ev("it_hardware_check", title="Hardware diagnostic", kind="chat", **{"from": "it"}, window=14, no_excuse=T,
   text="Following up on your broken {subject}: we're running a full hardware diagnostic on your machine in 10 minutes. It scans every connected device.",
   choices=[
       {"t": "\"Go ahead.\" (Switch your gadgets off first.)", "a": "ack", "ok": {"later": {"in": 10, "ev": "audit_surprise"}, "say": "Scheduled. Please leave everything plugged in."}},
       {"t": "\"It started working again. Cancel it.\"", "a": "bluff", "p": 52, "ok": {"claim_status": "patched", "say": "Cancelled. Glad it's sorted."}, "ko": {"susp": 5, "later": {"in": 10, "ev": "audit_surprise"}, "say": "We'd rather check. Diagnostic stays."}},
   ],
   expire={"later": {"in": 6, "ev": "audit_surprise"}, "say": "No reply. Running it anyway."})

# --- Gadget failures ---------------------------------------------------------
ev("duck_gibberish", title="Gibberish in chat", kind="chat", **{"from": "martin"}, thread="team", window=16, no_excuse=T,
   facts=["auto_message", "social_post"],
   text="{name}, you just posted 'jjjjjjjjjkkkkkl;;;;' to the whole team. Forty times. What does it mean?",
   choices=[
       {"t": "\"It's a regex. Don't worry about it.\"", "a": "jargon", "p": 54, "tags": ["jargon"], "ok": {"ill": 3, "say": "Oh. Regex. Say no more."}, "ko": {"susp": 7, "say": "Priya says that's not a regex."}},
       {"t": "\"My cat walked across the keyboard.\"", "a": "bluff", "p": 52, "ok": {"say": "Ha! Classic cat."}, "ko": {"susp": 7, "say": "For forty lines?"}},
       {"t": "\"Encrypted status update. Security best practice.\"", "a": "jargon", "p": 42, "tags": ["jargon"], "ok": {"ill": 5, "say": "I love that. Everyone should do that."}, "ko": {"susp": 8, "say": "Security says please never do that again."}},
       {"t": "Admit a machine was typing for you.", "a": "honest", "ok": {"susp": 11, "say": "A... duck. Was doing your job. I need to sit down."}},
   ],
   expire={"susp": 9, "say": "No explanation for the keyboard smash. Noted."})
ev("chatbot_hallucination", title="An invented project", kind="chat", **{"from": "martin"}, window=18, no_excuse=T, facts=["auto_message"],
   text="Your last message mentions 'Project Halibut' for our client 'Zentrix'. We don't have a client called Zentrix. What is Project Halibut?",
   choices=[
       {"t": "\"It's a codename. Need-to-know.\"", "a": "bluff", "p": 46, "ok": {"ill": 5, "task": "halibut", "say": "Ooh. A stealth project. I want weekly updates. Put it on the board."}, "ko": {"susp": 9, "say": "I'm the one who needs to know."}},
       {"t": "\"Autocorrect. I meant 'the pipeline'.\"", "a": "blame", "p": 56, "ok": {"say": "Autocorrect. Sure. OK."}, "ko": {"susp": 7, "say": "Autocorrect invented a customer and a fish?"}},
       {"t": "\"That's Kevin's thing. Ask him.\"", "a": "deflect", "p": 50, "ok": {"say": "KEVIN."}, "ko": {"susp": 8, "say": "Kevin has never heard of it either."}},
       {"t": "Admit a chatbot wrote it.", "a": "honest", "ok": {"susp": 12, "say": "A chatbot is answering me. For how long?"}},
   ],
   expire={"susp": 10, "say": "No answer. I've forwarded 'Project Halibut' to legal."})
ev("assistant_absurd", title="An absurd answer", kind="chat", **{"from": "martin"}, window=18, no_excuse=T,
   text="In that meeting you answered a question about the budget with a banana bread recipe. Are you alright?",
   choices=[
       {"t": "\"It was a metaphor. About rising costs.\"", "a": "jargon", "p": 50, "tags": ["jargon"], "ok": {"ill": 4, "say": "...That's actually quite good."}, "ko": {"susp": 8, "say": "It included oven temperatures."}},
       {"t": "\"Wrong window. I was multitasking for a client.\"", "a": "bluff", "p": 52, "ok": {"say": "Multitasking. OK. Focus next time."}, "ko": {"susp": 7, "say": "Which client wants banana bread?"}},
       {"t": "\"My microphone picks up the TV.\"", "a": "bluff", "p": 50, "ok": {"claim": "hardware_malfunction", "say": "Get IT to look at that mic."}, "ko": {"susp": 7, "say": "It was your voice."}},
       {"t": "Admit an AI was answering for you.", "a": "honest", "ok": {"susp": 12, "say": "So I've been in meetings with a toaster."}},
   ],
   expire={"susp": 9})
ev("doppel_meltdown", title="Clone meltdown", kind="chat", **{"from": "martin"}, window=16, no_excuse=T,
   text="Your camera feed just said, quote, 'I am pivoting to consulting', and then froze with its eyes half closed. What WAS that?",
   choices=[
       {"t": "\"Bad connection. And a podcast in the background.\"", "a": "bluff", "p": 46, "ok": {"say": "That was a very specific podcast."}, "ko": {"susp": 10, "say": "It said it in your voice. With your face."}},
       {"t": "\"My webcam is glitching. It's been dying all week.\"", "a": "bluff", "p": 52, "ok": {"claim": "hardware_malfunction", "say": "OK. Join by phone until IT replaces it."}, "ko": {"susp": 9, "say": "Webcams don't announce career changes."}},
       {"t": "Admit it was an AI clone.", "a": "honest", "ok": {"susp": 14, "say": "You sent a ROBOT to my meeting."}},
   ],
   expire={"susp": 12, "say": "No answer. I'm adding 'consulting' to your file."})
ev("doppel_decision", title="Your clone made a decision", kind="system", action="outcomes", args={"outcomes": [
    {"text": "Your clone volunteered you for the tiger team. Enthusiastically.", "say": "Loved your energy in there, {name}! You're on the tiger team.", "fx": {"task": "okr", "ill": 5}},
    {"text": "Your clone asked Martin for a raise. He was too confused to say no.", "say": "...Fine. A small adjustment. Don't tell the others.", "fx": {"money": 120, "susp": 4}},
    {"text": "Your clone approved Kevin's 4,000-line PR without reading it.", "say": "Staging is gone. Kevin says YOU approved it.", "fx": {"susp": 8, "favor": 1}},
    {"text": "Your clone told Martin this is the best job it has ever had.", "say": "That really meant a lot, {name}. Thank you.", "fx": {"susp": -6, "rel": 6}},
    {"text": "Your clone promised a customer a feature that does not exist.", "say": "Sales says you committed to 'real-time synergy'. By Friday.", "fx": {"task": "halibut", "susp": 5}},
]})

# ---------------------------------------------------------------------------
# Scripted beats of the week
# ---------------------------------------------------------------------------
SAYS = {}


def say(eid, who, text):
    ev(eid, title=eid.replace("_", " ").capitalize(), kind="say", **{"from": who}, text=text)


def assign(task):
    eid = "assign_" + task
    if eid not in EVENTS:
        ev(eid, title="Assign " + task, kind="task", task=task)
    return eid


for day, entries in enumerate(WEEK_EVENTS):
    for minute, kind, args in entries:
        if kind == "ping":
            if args["id"] in EVENTS and args["id"] not in ("screen_check",):
                at(args["id"], day, minute)
        elif kind == "task":
            at(assign(args["id"]), day, minute)
        elif kind == "mail":
            if args["id"] in EVENTS and args["id"] != "shady":
                at(args["id"], day, minute)
ev("synerwatch_on", title="SynerWatch goes live", kind="system", action="flag", args={"id": "synerwatch"})
at("synerwatch_on", 3, 546)
ev("incident_start", title="Production incident", kind="system", action="incident", args={"minutes": 70})
at("incident_start", 2, 671)
# Monday: onboarding and the basics of lying.
say("priya_hello", "priya", "psst. you're the new remote hire, right? rule one at SynerCorp: nobody checks the work. they check whether you LOOK busy.")
say("priya_rules", "priya", "keep your Productivity Illusion up and your Suspicion down. and whatever you do, don't actually do the tickets. it'll wreck your health.")
say("priya_lies", "priya", "every message has 'Make an excuse...'. careful: {boss} remembers what you told him. say your internet is down, then show up on camera, and he WILL ask.")
at("priya_hello", 0, 541)
at("priya_rules", 0, 547)
at("priya_lies", 0, 630)
# Tuesday: automation.
at("shady", 1, 543)
say("dave_mousemover", "dave", "MouseMover.exe is finally back in stock on ShadyDeals. buy it from your gaming PC. i've been 'Available' since 2022.")
say("priya_conflict", "priya", "Tip: the Alignment Sync at 11 is optional-ish. Block your calendar over it in SynerCalendar, then hit 'Decline: conflict'. The system approves it by itself.")
at("dave_mousemover", 1, 552)
at("priya_conflict", 1, 625)
# Wednesday: the boss starts checking.
ev("trust_but_verify", title="Trust but verify", kind="say", **{"from": "martin"}, thread="team",
   text="Team, new policy from today: trust, but verify. If you tell me something, I will check it. Nothing personal. It's a framework.")
at("trust_but_verify", 2, 543)
ev("verify_mode", title="Verification on", kind="system", action="flag", args={"id": "verify_mode"})
at("verify_mode", 2, 543)
say("priya_ledger", "priya", "he means it. open ShadowIT on your work computer: the Alibi Ledger shows every story you've told and what would blow it. back them up with evidence first.")
at("priya_ledger", 2, 549)
# Thursday: failures and combinations.
at("combo_deals", 3, 541)
ev("strain_on", title="SynerWatch strain", kind="system", action="flag", args={"id": "strain"})
at("strain_on", 3, 546)
say("dave_wear", "dave", "heads up: SynerWatch is live and it hammers anything plugged in. gadgets wear out way faster from today. service them BEFORE they break. mine got caught mid-circle.")
at("dave_wear", 3, 556)

# ---------------------------------------------------------------------------
# Dialogue
# ---------------------------------------------------------------------------
DIALOGUES = {}
for did, c in CALLS.items():
    DIALOGUES[did] = dict(beats=c["beats"], pool=c.get("pool", []), pick=c.get("pick", 0), after=c.get("after", {}))
for bid, b in BEATS.items():
    DIALOGUES[bid] = dict(beats=[b])
DIALOGUES["screen_share"] = dict(beats=[{
    "who": "martin", "no_excuse": T,
    "text": "Uh, {name}? You're sharing your screen. Is that... a shop called 'ShadyDeals'? And a video game?",
    "choices": [
        {"t": "\"Competitor research. I'm benchmarking their checkout flow.\"", "a": "jargon", "p": 50, "tags": ["jargon"], "ok": {"ill": 3, "say": "Oh. Smart. Share your findings."}, "ko": {"susp": 9, "say": "The cart has a mouse jiggler in it."}},
        {"t": "\"That's a pop-up! I think this machine has malware.\"", "a": "blame", "p": 52, "ok": {"claim": "hardware_malfunction", "say": "Yikes. Close it. I'll get IT to scan your machine."}, "ko": {"susp": 8, "say": "You typed the address in while we watched."}},
        {"t": "Slam the Keyboard Duck's fake code window on top.", "a": "use_gadget", "ability": "screen_fake", "req": {"ability": "screen_fake"}, "ok": {"susp": -2, "ill": 4, "say": "...Must have been a glitch. That's a lot of code."}, "ko": {"susp": 10, "say": "Now it says DEMO MODE."}},
        {"t": "Stop sharing and say nothing.", "a": "deflect", "p": 44, "ok": {"say": "...Moving on."}, "ko": {"susp": 7, "say": "We all saw it, {name}."}},
    ],
    "silence": {"susp": 10, "say": "It's still up there, {name}. We're all just looking at it."},
}])
DIALOGUES["grilling"] = dict(beats=[{
    "who": "martin",
    "text": "Before we wrap: {name}, walk me through your day so far. Hour by hour.",
    "choices": [
        {"t": "Narrate a busy morning that never happened.", "a": "bluff", "p": 56, "tags": ["video"], "ok": {"susp": -3, "say": "OK. That tracks. Mostly."}, "ko": {"susp": 8, "say": "At 10:15 your status was Away. For an hour."}},
        {"t": "\"I don't think in hours. I think in outcomes.\"", "a": "jargon", "p": 54, "tags": ["jargon", "video"], "ok": {"ill": 3, "say": "...Annoyingly good answer."}, "ko": {"susp": 7, "say": "Name one outcome."}},
        {"t": "Give an honest account, with evidence", "a": "real_answer", "ok": {"susp": -8, "ill": 6, "say": "Thank you. That's all I wanted."}},
    ],
    "silence": {"susp": 8, "say": "Nothing? OK. That tells me plenty."},
}])
DIALOGUES["unblock"] = dict(beats=[{
    "who": "priya", "no_excuse": T,
    "text": "Hi. Platform here. Martin says we're blocking you? We've never received anything from you. What do you need?",
    "choices": [
        {"t": "\"I need the, uh, acceptance criteria. Signed.\"", "a": "jargon", "p": 54, "tags": ["jargon"], "ok": {"say": "Priya: ...I'll send you a doc. Give me a day."}, "ko": {"susp": 9, "say": "Martin: So you weren't blocked."}},
        {"t": "\"It resolved itself while we were dialling in.\"", "a": "bluff", "p": 48, "ok": {"say": "Martin: Great! Love a quick win."}, "ko": {"susp": 8, "say": "Priya: Nothing was ever open."}},
        {"t": "Ask a real, specific technical question", "a": "real_answer", "ok": {"susp": -6, "ill": 5, "say": "Priya: Oh. That's a good question, actually. Here's the answer."}},
    ],
    "silence": {"susp": 9, "say": "Martin: ...{name}? We're all here for YOU."},
}], after={"susp": -1})
DIALOGUES["senior"] = dict(beats=[
    {
        "who": "helena", "no_excuse": T,
        "text": "Helena Voss. I have nine minutes. In one sentence: what do you do here, and why should I keep paying for it?",
        "choices": [
            {"t": "\"I turn ambiguity into alignment at scale.\"", "a": "jargon", "p": 50, "tags": ["jargon", "video"], "ok": {"ill": 6, "susp": -3, "say": "Helena: I have no idea what that means. I'm putting it in the board deck."}, "ko": {"susp": 10, "say": "Helena: I wrote that sentence. In 2014. Try again next quarter."}},
            {"t": "\"I keep Martin's numbers green.\"", "a": "flatter", "p": 58, "tags": ["video"], "ok": {"susp": -4, "rel": 4, "say": "Helena: Martin's numbers ARE green. Hm. Fine."}, "ko": {"susp": 8, "say": "Helena: Martin's numbers are the reason I'm here."}},
            {"t": "Give a precise account of real responsibilities", "a": "real_answer", "ok": {"susp": -10, "ill": 8, "say": "Helena: Clear. Concrete. Rare. Thank you."}},
        ],
        "silence": {"susp": 12, "say": "Helena: Nothing. Remarkable. Martin, who is this?"},
    },
    {
        "who": "helena", "no_excuse": T,
        "text": "We are 'right-sizing'. Give me one name from your team I could lose tomorrow without noticing.",
        "choices": [
            {"t": "\"Kevin.\"", "a": "blame", "p": 60, "tags": ["video"], "ok": {"susp": -3, "say": "Helena: The ninja. Yes. Interesting."}, "ko": {"susp": 7, "say": "Helena: Kevin said you."}},
            {"t": "\"Honestly? Half the meetings.\"", "a": "bluff", "p": 46, "tags": ["video"], "ok": {"ill": 5, "susp": -4, "say": "Helena: Ha. Finally someone says it."}, "ko": {"susp": 8, "say": "Helena: I asked for a name."}},
            {"t": "Volunteer to run the efficiency review yourself.", "a": "volunteer", "ok": {"susp": -8, "ill": 6, "task": "okr", "say": "Helena: Ambitious. You have until Friday."}},
        ],
        "silence": {"susp": 9, "say": "Helena: Loyalty, or you weren't listening. Either way."},
    },
    {
        "who": "martin", "no_excuse": T,
        "text": "(Martin, sweating.) Helena, {name} is one of my best. Aren't you, {name}? Tell her about... the thing. The initiative.",
        "choices": [
            {"t": "Invent an initiative on the spot.", "a": "bluff", "p": 48, "tags": ["video", "jargon"], "ok": {"ill": 6, "rel": 6, "task": "halibut", "say": "Helena: 'Project Halibut'. I want it on my desk Monday."}, "ko": {"susp": 9, "rel": -6, "say": "Helena: That is the plot of a film."}},
            {"t": "\"Martin's being modest. It was all his idea.\"", "a": "flatter", "p": 66, "tags": ["video"], "ok": {"susp": -5, "rel": 10, "say": "Martin: ...I'll remember that, {name}."}, "ko": {"susp": 5, "say": "Helena: Then Martin can explain it."}},
        ],
        "silence": {"susp": 10, "rel": -8, "say": "Martin: ...{name}. Please."},
    },
], after={"susp": -2})

# ---------------------------------------------------------------------------
# Flavour text
# ---------------------------------------------------------------------------
TEXTS = {
    "office": dict(lines={
        "chatter": CHATTER,
        "auto_replies": rename(extract(src, "AUTO_REPLIES"), NAMES),
        "missed": rename(extract(src, "MISSED_LINES"), NAMES),
        "block_titles": extract(src, "BLOCK_TITLES"),
        "fake_updates": extract(src, "FAKE_UPDATES"),
        "report_verbs": extract(src, "REPORT_BITS")["verb"],
        "report_nouns": extract(src, "REPORT_BITS")["noun"],
        "report_tails": extract(src, "REPORT_BITS")["tail"],
        "report_ok": ["Great report. Didn't read it, but great length.", "Love the bullet points. Very bullet-y.", "Forwarding this to leadership. Nice."],
        "assistant_ok": ["Great answer. Very structured.", "Yes. Exactly that. Everyone write that down.", "Couldn't have put it better myself."],
        "assistant_absurd": ["...Did you just say 'preheat the oven to 180'?", "Why did you answer that with 'As an AI language model'?", "{name}, the question was about the budget. You said 'Tuesday'."],
    }),
}

TASKS_EXTRA = {
    "halibut": dict(key="SYN-142", title="Project Halibut: deliver the Q3 milestone for Zentrix", desc="Neither the project nor the customer exists. Somehow there is now a deadline.", prio=1, effort=3, due_day=1, due_t=960),
}


def main():
    for folder in ["events", "dialogue", "text"]:
        clean(folder)
    for eid, f in EVENTS.items():
        write("events", "event_def", "EventDef", eid, f)
    for did, f in DIALOGUES.items():
        write("dialogue", "dialogue_def", "DialogueDef", did, f)
    for tid, f in TEXTS.items():
        write("text", "text_bank_def", "TextBankDef", tid, f)
    for tid, f in TASKS_EXTRA.items():
        write("tasks", "task_def", "TaskDef", tid, f)
    kinds = {}
    for f in EVENTS.values():
        kinds[f["kind"]] = kinds.get(f["kind"], 0) + 1
    print("events: %d %s, dialogues: %d" % (len(EVENTS), kinds, len(DIALOGUES)))


if __name__ == "__main__":
    main()
