# YT Strategy Agent

A 24/7 system that watches a list of YouTube channels and turns the last 5 videos from each into a living trading-strategy document — automatically updated as new videos drop.

For every channel you watch, you get:
- **strategy.md** — the deduced strategy in plain English
- **rules.json** — structured buy rules, sell rules, risk notes, timing notes
- **changelog.md** — append-only log of when the strategy shifts
- **trades.md** — executed trades the host called out
- **videos/<id>.md** — per-video extracted notes + transcript

Newer videos are weighted more heavily, similar rules are grouped automatically, and strategy changes get flagged the moment they happen.

## How to set it up

This repo is designed to be set up by an AI agent walking you through it.

1. Install [Claude Code](https://claude.com/claude-code) (or any agent CLI of your choice).
2. Make a fresh empty folder, `cd` into it, start Claude Code.
3. Paste the entire contents of [`PROMPT.md`](./PROMPT.md) as your first message.
4. Follow along — the agent opens browser tabs, runs commands, and gets you live in about 20 minutes.

> Currently macOS only. Windows and Linux versions coming.

## What it costs

- **Hostinger KVM 2 VPS:** ~£6/month ([referral link](https://www.hostinger.com/uk?REFERRALCODE=EGBLEWISRZT6))
- **Anthropic API:** ~£0.10–£0.50/month for typical use
- **YouTube Data API:** free

## How it works under the hood

```
every 10 min:
  for each channel in channels.yaml:
    fetch latest 5 video IDs
    for any new video:
      pull transcript
      Claude extracts strategy / rules / risk / timing / executed trades
      detect strategy shifts vs prior state → changelog
      re-merge rolling window with recency weighting
      group similar rules via embedding similarity
```

### Recency weighting

| Position in window | Weight |
|---|---|
| Most recent | 1.00 |
| -1 | 0.70 |
| -2 | 0.50 |
| -3 | 0.35 |
| -4 | 0.25 |

Effective confidence = `mean(confidence × weight)` across appearances. Rules below 0.30 are dropped.

### Strategy change detection

A shift is logged if:
- a new rule contradicts an existing high-confidence rule
- the strategy summary moves >0.35 in semantic distance
- Claude flags `strategy_shift.changed = true`

## Repo layout

```
auth.py              OAuth flow
watcher.py           Main 10-min poll loop
ingest.py            Pull transcript + extract + merge
extract.py           Claude prompt + JSON schema
weighting.py         Recency weighting + similarity grouping
change_detect.py     Strategy-shift detection
store.py             SQLite + markdown IO
channels.yaml        Channels to watch (you edit this)
scripts/
  bootstrap_vps.sh   One-shot SSH + install onto Hostinger
  watcher.service    systemd unit
tools/
  resolve_channel.py Handle/URL → channel ID
channels/<handle>/   Generated docs live here
```

## License

MIT.
