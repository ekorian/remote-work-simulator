extends Node
## Bus — global signal hub. Systems publish here; UI and world subscribe.
## Keeps the simulation core free of any reference to scenes or controls.

@warning_ignore_start("unused_signal")

# Feedback
signal toast(text: String, kind: String)            # kind: info | good | bad | warn | money | tip
signal sfx(name: String)

# Corporate comms
signal prompt_added(prompt: Dictionary)
signal prompt_resolved(prompt: Dictionary, outcome: Dictionary)
signal thread_message(thread_id: String, msg: Dictionary)
signal mail_added(mail: Dictionary)
signal task_changed(task: Dictionary)
signal meeting_changed(meeting: Dictionary)
signal comms_changed()                               # generic "something in the apps changed"

# Actions and activities
signal action_performed(id: String, cls: int, ctx: Dictionary)
signal activity_started(act: Dictionary)
signal activity_ended(act: Dictionary, completed: bool)
signal thing_changed(thing_id: String)               # router toggled, phone docked, ...
signal gadget_changed(gadget_id: String)

# UI requests (emitted by systems or the world, handled by Main)
signal request_desktop(app: String)
signal request_shop()
signal desktop_opened()
signal desktop_closed()

# Tutorial and lifecycle
signal tutorial_changed()
signal state_loaded()
