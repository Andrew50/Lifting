use on device db for locat storage via sqlite

local first for phase 1


ml/ai inference done on server, eventually mabye hybird with local model, weights learned on server



What to build now so you don’t regret it later (even in Phase 1)

If you do local-first, do these now to keep the door open:

Use UUIDs for everything (workout_id, exercise_id, set_id)

Store timestamps + “updated_at” on each row

Keep an append-only event log (optional but powerful): SetCreated, SetEdited, WorkoutFinished, etc.

Normalize units (lbs/kg) and store the unit with each entry

Exercise canonicalization: one canonical exercise + aliases (imported names map to canonical IDs)

That makes Phase 2 sync/auth/backends dramatically easier.


