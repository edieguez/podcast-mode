# podcast-mode

Toggle audio-only playback in mpv - hides the video while audio keeps
playing, and remembers whatever track was actually selected so turning
it back off restores the real track, not a guess.

## What it does

Setting mpv's `vid` (video track) property to `"no"` disables the video
track; since `--force-window` isn't set, mpv doesn't keep a window open
for audio-only playback, so this alone hides the video display while
audio keeps playing uninterrupted. The previous `vid` value is captured
before hiding and restored on the way back, rather than assuming any
fixed track number.

Also re-asserts `vid=no` on every file transition while podcast mode is
on, as a defensive safety net - a runtime `vid` change is very likely to
persist across playlist items on its own, but this makes it certain,
cheaply and idempotently, regardless of mpv build/config quirks.

Whether podcast mode is currently on is derived by observing `vid`
itself, not tracked in a separate flag - so the toggle can never get out
of sync with what's actually playing, no matter what else changes `vid`.

## Session-only by design

Podcast mode is never remembered per file - toggling it only ever
affects the current session. This depends on excluding `vid` from
mpv's `--watch-later-options`; without that, mpv's own resume-on-reopen
behavior would silently reapply "audio only" to a file the next time
it's opened, even though the user never asked for that on that file.
Add to `mpv.conf` (or any config mpv reads at startup):

```
watch-later-options-del=vid
```

## Self-healing video restore

When turning podcast mode off, the plugin checks about a second later
whether the video window actually came back (`vo-configured`). If it
didn't - which can happen after a macOS sleep/wake cycle drops the GPU
context, or when a streamed URL's cached fragment has expired in the
meantime - it reloads the current playlist entry and seeks back to
where playback left off, rather than leaving the user stuck audio-only
with no way to tell why. This reload is attempted at most once per
toggle, and is skipped entirely for files that have no video track.

## Installation

1. Copy or symlink `scripts/podcast_mode.lua` into mpv's `scripts/`
   directory.
2. Bind a key to toggle it, e.g. in `input.conf`:
   ```
   M script-binding podcast_mode/podcast-mode-toggle
   ```

## External control

Also exposes three `script-message`s for triggering from outside a key
binding - another script, or the sibling
[mpv-remote](https://github.com/edieguez/mpv-remote) CLI's `podcast
[on|off]` subcommand:

- `podcast-mode-on`
- `podcast-mode-off`
- `podcast-mode-toggle`

## License

MPL-2.0, see [LICENSE](LICENSE).
