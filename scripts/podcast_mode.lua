-- podcast-mode: toggle audio-only playback ("podcast mode") - disables
-- the video track while keeping audio playing, and remembers whatever
-- track was actually selected so re-enabling video restores the real
-- track instead of assuming a fixed one.
--
-- Mechanism: setting mpv's `vid` property to "no" disables the video
-- track; since --force-window isn't set anywhere in this config, mpv
-- doesn't keep a window open for audio-only playback, so this alone
-- hides the video display while audio keeps playing uninterrupted.
--
-- Deliberately session-only: mpv-custom.conf excludes vid from
-- watch-later-options, so this state is never remembered per file. If
-- it were, a resume would silently re-apply "no" the next time that
-- file is opened, making podcast mode look like it leaked into a video
-- the user never toggled it on for.

local podcast_mode_enabled = false
local saved_vid = nil -- vid as it was right before podcast mode was enabled
local restore_seek_pos = nil -- captured just before a self-heal reload
local restore_was_paused = nil
local reload_attempted = false -- guards against a reload loop on a truly video-less file

local function has_video_track()
    local track_list = mp.get_property_native("track-list")
    if not track_list then
        return false
    end
    for _, track in ipairs(track_list) do
        if track.type == "video" and not track.image then
            return true
        end
    end
    return false
end

-- vid is the single source of truth for whether podcast mode is
-- currently in effect - podcast_mode_enabled just mirrors it for the
-- toggle logic below, rather than being tracked independently. This is
-- what makes the M key always do the intuitive thing even if vid was
-- changed by something other than this script (IPC, another script) -
-- there is no separate flag that could disagree with reality.
mp.observe_property("vid", "string", function(_, value)
    podcast_mode_enabled = (value == "no")
end)

local function enable_podcast_mode()
    if podcast_mode_enabled then
        return -- guard: a stray repeat "on" must not stomp saved_vid below
    end
    saved_vid = mp.get_property("vid")
    mp.set_property("vid", "no")
    mp.osd_message("Podcast mode: on (audio only)", 2)
end

-- Checked ~1s after asking mpv to bring video back: after a macOS
-- sleep/wake cycle, GPU/hwdec context loss can make the VO fail to
-- reinitialize, or (for a stream URL) the cached fragment URL can have
-- expired during sleep - in both cases vid reads back as restored but
-- no window ever appears, silently. vo-configured is documented as
-- corresponding to whether the video window is visible; that caveat
-- only applies when --force-window is set, which it isn't here.
local function video_actually_visible()
    return mp.get_property_bool("vo-configured", false)
end

local function restore_after_reload()
    if restore_seek_pos then
        mp.commandv("seek", tostring(restore_seek_pos), "absolute+exact")
        if restore_was_paused then
            mp.set_property_bool("pause", true)
        end
    end
    restore_seek_pos = nil
    restore_was_paused = nil
end

local function self_heal_reload()
    -- podcast_mode_enabled may have flipped back to true if the user
    -- pressed the toggle again during the 1s grace window - in that
    -- case video being off is now the intended state, not a failure.
    if podcast_mode_enabled or reload_attempted or video_actually_visible() or not has_video_track() then
        return
    end
    reload_attempted = true
    restore_seek_pos = mp.get_property_number("time-pos")
    restore_was_paused = mp.get_property_bool("pause")
    mp.osd_message("Restoring video…", 3)
    mp.commandv("playlist-play-index", "current")
end

local function disable_podcast_mode()
    if not podcast_mode_enabled then
        return
    end
    mp.set_property("vid", saved_vid or "auto")
    mp.osd_message("Podcast mode: off", 2)
    reload_attempted = false
    mp.add_timeout(1, self_heal_reload)
end

local function toggle_podcast_mode()
    if podcast_mode_enabled then
        disable_podcast_mode()
    else
        enable_podcast_mode()
    end
end

-- Defensive re-assert on every file transition while podcast mode is
-- on. mpv's documented behavior is that a runtime property change like
-- this (which amounts to changing the underlying --vid option)
-- persists across playlist files rather than resetting per file - so
-- this is very likely a no-op in practice - but it's cheap and
-- idempotent, and removes any dependency on that assumption being
-- right for every mpv build/config.
mp.register_event("file-loaded", function()
    if podcast_mode_enabled then
        mp.set_property("vid", "no")
    elseif restore_seek_pos then
        restore_after_reload()
    end
end)

mp.add_key_binding(nil, "podcast-mode-toggle", toggle_podcast_mode)
mp.register_script_message("podcast-mode-on", enable_podcast_mode)
mp.register_script_message("podcast-mode-off", disable_podcast_mode)
mp.register_script_message("podcast-mode-toggle", toggle_podcast_mode)
