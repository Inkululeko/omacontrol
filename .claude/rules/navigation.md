---
paths:
  - "ui/*.qml"
  - "SettingsWindow.qml"
---

# Keyboard navigation

> **Read this when:** you add a row type, change how a row is activated or stepped, touch the cursor in `SettingsWindow.qml`, or edit `ui/NavRow.qml`, `ui/NavCursor.qml`, `ui/SettingRow.qml` or the legend bar.

## Keyboard navigation

`PanelKeyCatcher` in `qs.Ui` defines the vocabulary Omarchy panels answer to,
and this window follows it rather than inventing one: Up/Down and j/k move,
Left/Right and h/l change a value, Enter and Space act, Tab changes section,
Escape closes. Alt+Up/Down for the next and previous page, Home/End, and Backspace **or Delete**
for the (reset) beside a changed setting are the additions a window with pages
needs.

The cursor lives in `SettingsWindow`, but a row says what it means: **`NavRow`**
carries `current`, `navActivate()`, `navStep(delta)`, `navKeys`, `navBlocking`
and `searchHidden` — `SettingRow` and the table rows inherit them — and each row type
answers those in its own terms — a switch flips, a slider steps, a picker
opens. A row type that answers neither is still navigable and simply does
nothing when activated.

Rows register themselves on load, by walking up to the page and taking the
`app` handle it was loaded with — a window is not the visual parent of what it
shows, so walking to the top does not find it. The order is recomputed from
where rows actually sit, not from the order they registered, since groups come
and go with the settings they depend on.

Two things worth knowing before changing this:

- **A field commits by losing focus, and stops its own Enter.** `accepted`
  fires without accepting the event, so an Enter left to bubble reaches the
  window, which reads it as "activate this row" and drops straight back into
  the field it just left. Editing is a flag the row owns rather than a reading
  of `activeFocus`, which the field can take back on its own.
- **A row holding the keyboard sets `navBlocking`** — an open dropdown, a field
  being typed into. The window then forwards every key, Escape included, or
  Escape would close the window out from under an open list.
- **Stepping keeps its own `pending` value.** A write takes a state refresh to
  come back, and two presses inside that window would both compute from the
  same stale number, so the second would be swallowed. `effective` is what the
  slider and the next press read.


## The legend bar

Fourteen keys listed at once would be a wall nobody reads, so the bar says
what the keys do *here*: the four that always apply, plus whatever the cursor
is on. A row type declares its own keys in `navKeys` — the same place it
answers `navActivate` and `navStep` — so a new row type that forgets adds
nothing to the bar rather than lying about what it does.

`\u232b Reset` appears only on a row this window has changed, which makes the
bar the discovery path for the reset as well.


## Rows that are not settings

A device, a network and a binding are lists of things rather than one setting
each, and their rows are built to look like it — `PickableRow`, `DeviceRow`,
`WifiRow`, `BindingRow` are not `SettingRow`s. `NavCursor` carries the cursor
contract into them instead of forcing them into that shape: drop one in,
anchored over the row, and the row joins the cursor. It registers itself, not
its parent, and mirrors the geometry the window sorts by, so from the window's
side it is another row.

Its key is whatever clicking the row does, which is not fixed: connect or
disconnect depending on the device, remove or turn off depending on whose
binding it is. The legend says which, because the row does.

