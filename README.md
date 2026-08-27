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
