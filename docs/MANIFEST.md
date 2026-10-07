# Manifest format — bodies/<id>/manifest

Shell-sourcable KEY=VALUE (the tick reads it with `.`, no parser on a 2GB A53).

| field | meaning |
|---|---|
| `BODY_ID` | unique id (`q1`, `dock-cam-2`); commits carry it |
| `LOCATION` | **physical place** — the primary key the agent reasons over. "Commands places, not boards": two bodies at one location are one place with two hands. |
| `HOST` | hostname for ssh ops |
| `SUBSTRATE` | unoq / laptop / oracle / prospector |
| `SENSORS` | comma list the body can read (temperature, uptime, wifi-rssi, gpio, adc0...) |
| `ACTUATORS` | comma list it can drive (led, gpio-header, serial, relay0...) |
| `CAPABILITIES` | what task `needs:` can match on (arduino-deploy, gpio, shell, lowpower, camera...) |
| `TICK_SECONDS` | heartbeat period (default 120) |
| `WITNESS` | 1 = append daily witness file |

Notes field carries mounting, power, network path. Changes to manifest are
commits — the census is versioned like everything else.
