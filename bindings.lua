-- Exposé Switch chord. Load this once from ~/.config/hypr/bindings.lua:
--   dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/expose.switch/bindings.lua")
--
-- The first Alt+Tab or Alt+Shift+Tab only opens the overview. Further Tab
-- presses while Alt is held move through the grid; Shift+Tab moves back.
-- Releasing Alt activates the selected window only after one of those moves.
-- A tap leaves the overview open.
--
-- ALT+TAB was: focus next window.
-- ALT+SHIFT+TAB was: focus previous window.

local expose_switch_chord = false

local function expose_switch_event(name)
  hl.dispatch(hl.dsp.event(name))
end

local function expose_switch_begin_or_step(direction)
  if not expose_switch_chord then
    expose_switch_chord = true
    expose_switch_event("expose.switch:open")
    return
  end

  if direction < 0 then
    expose_switch_event("expose.switch:prev")
  else
    expose_switch_event("expose.switch:next")
  end
end

local function expose_switch_release()
  if not expose_switch_chord then
    return
  end

  expose_switch_chord = false
  expose_switch_event("expose.switch:release")
end

hl.unbind("ALT + TAB")
hl.unbind("ALT + SHIFT + TAB")

o.bind("ALT + TAB", "Exposé Switch", function()
  expose_switch_begin_or_step(1)
end, { repeating = true })

o.bind("ALT + SHIFT + TAB", "Exposé Switch (previous)", function()
  expose_switch_begin_or_step(-1)
end, { repeating = true })

-- Release binds match the mods from key-down, so Alt-up can miss. The keyboard
-- listener below sees the raw key. Both paths are idempotent in the plugin.
hl.bind("ALT + Alt_L", expose_switch_release, {
  release = true,
  non_consuming = true,
  description = "Exposé Switch confirm on Alt release",
})

hl.bind("ALT + Alt_R", expose_switch_release, {
  release = true,
  non_consuming = true,
  description = "Exposé Switch confirm on Alt release",
})

hl.on("input.keyboard.key", function(keycode, _time, state)
  if state ~= 0 then
    return
  end
  -- xkb codes: KEY_LEFTALT and KEY_RIGHTALT plus 8.
  if keycode ~= 64 and keycode ~= 108 then
    return
  end
  expose_switch_release()
end)
