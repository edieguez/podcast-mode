-- podcast-mode: toggle audio-only playback ("podcast mode") - disables
-- the video track while keeping audio playing, and remembers whatever
-- track was actually selected so re-enabling video restores the real
-- track instead of assuming a fixed one.
--
-- Mechanism: setting mpv's `vid` property to "no" disables the video
-- track; since --force-window isn't set anywhere in this config, mpv
-- doesn't keep a window open for audio-only playback, so this alone
-- hides the video display while audio keeps playing uninterrupted.

local podcast_mode_enabled = false
local saved_vid = nil -- vid as it was right before podcast mode was enabled

local function enable_podcast_mode()
    if podcast_mode_enabled then
        return -- guard: a stray repeat "on" must not stomp saved_vid below
    end
    saved_vid = mp.get_property("vid")
    podcast_mode_enabled = true
    mp.set_property("vid", "no")
    mp.osd_message("Podcast mode: on (audio only)", 2)
end

local function disable_podcast_mode()
    if not podcast_mode_enabled then
        return
    end
    podcast_mode_enabled = false
    mp.set_property("vid", saved_vid or "auto")
    mp.osd_message("Podcast mode: off", 2)
end

local function toggle_podcast_mode()
    if podcast_mode_enabled then
        disable_podcast_mode()
    else
        enable_podcast_mode()
    end
end

-- Defensive re-assert on every file transition while podcast mode is on.
-- mpv's documented behavior is that a runtime property change like this
-- (which amounts to changing the underlying --vid option) persists across
-- playlist files rather than resetting per file - so this is very likely
-- a no-op in practice - but it's cheap and idempotent, and removes any
-- dependency on that assumption being right for every mpv build/config.
--
-- Calls set_property directly, NOT enable_podcast_mode(): the latter
-- would re-capture saved_vid (as "no", the second time - corrupting the
-- eventual restore) and re-fire the OSD message on every single ordinary
-- file transition, not just the actual on/off toggle.
mp.register_event("file-loaded", function()
    if podcast_mode_enabled then
        mp.set_property("vid", "no")
    end
end)

mp.add_key_binding(nil, "podcast-mode-toggle", toggle_podcast_mode)
mp.register_script_message("podcast-mode-on", enable_podcast_mode)
mp.register_script_message("podcast-mode-off", disable_podcast_mode)
mp.register_script_message("podcast-mode-toggle", toggle_podcast_mode)
