# Example: deploy blink to q1

The smoke-test task dropped into agent-inbox:

```markdown
# Blink q1
to: q1
from: muse
created: 2026-10-07T05:00Z

deploy: bodies/q1/sketches/blink

Light the LED. One blink per second. This is the first program
the agent ever copies into a place.

## Done when
- done/blink-q1/result.md contains a deploy receipt with commit hashes.
```

What happens on the next tick (q1, at "lab-bench"):

1. `tick.sh` pulls agent-inbox, sees `to: q1`, claims by push.
2. `run-task.sh` finds the `deploy:` line, calls `deploy.sh`.
3. `deploy.sh` compiles `bodies/q1/sketches/blink` for the STM32, uploads
   over `/dev/ttyACM0`, writes the receipt (sketch commit, previous deploy
   commit, timestamps) into `done/blink-q1/result.md`, pushes.
4. The LED at lab-bench blinks. `bodies/q1/uplink/<date>.log` keeps
   accumulating the witness chain.

Rollback: `cd unoq-node && git revert <deploy commit>`, then drop another
deploy task pointing at the prior sketch commit.
