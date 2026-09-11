pragma Singleton

import QtQuick
import qs.Commons

// One place for the colours and type the window is drawn in.
//
// OmaControl tracks the foundational palette rather than a themable surface of
// its own, so it renders consistently under every theme. The design it follows
// is drawn in a warm palette of its own; what is taken from that drawing is the
// *hierarchy* — which surface sits on which, how far apart two greys are — and
// those are expressed here as alphas over the theme's own foreground, so a
// Catppuccin desktop and a Gruvbox one each get the design in their own colours.
QtObject {
  id: palette

  readonly property color foreground: Color.popups.text
  // Popup surfaces are allowed to be translucent; a window full of text is
  // not, so the same colour is taken at full opacity.
  readonly property color background: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 1)
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent

  // A charge level is red, amber or green in every window that has ever shown
  // one, and a theme supplies only the red. The other two are struck from that
  // red — its saturation and lightness kept, the hue moved — so a muted theme
  // gets a muted green and a loud one gets a loud one, and none of it is a
  // colour typed into a page.
  function statusHue(hue) {
    return Qt.hsla(hue, urgent.hslSaturation, urgent.hslLightness, 1)
  }
  readonly property color bad: urgent
  readonly property color caution: statusHue(0.11)
  readonly property color good: statusHue(0.33)
  readonly property color muted: shade(0.6)
  readonly property color hairline: shade(0.16)
  readonly property color hover: shade(0.08)
  readonly property color selected: tint(0.18)
  readonly property string fontFamily: Style.font.family

  function shade(alpha) { return Qt.rgba(foreground.r, foreground.g, foreground.b, alpha) }
  function tint(alpha) { return Qt.rgba(accent.r, accent.g, accent.b, alpha) }

  // ---------------- surfaces ------------------------------------------------
  // Three steps, no more: the window, the rail beside it, and the cards on it.
  // The design draws the sidebar a shade off the window and the cards a shade
  // off again; anything finer than that stops being visible once a theme
  // supplies the colours.
  readonly property color surface: shade(0.04)
  readonly property color card: shade(0.03)
  // Between rows inside a card, where a full hairline would stripe the card.
  readonly property color divider: shade(0.10)

  // The strip of chrome above the window and the keyhint bar below it are the
  // same surface: they frame the window rather than belonging to either column.
  readonly property color chrome: shade(0.07)

  // ---------------- text on accent ------------------------------------------
  // A selected row fills with the accent, so its label can no longer be the
  // window's foreground. Which of the two reads on a given accent depends on
  // the theme, so it is measured rather than assumed.
  readonly property color onAccent: accent.hslLightness > 0.55 ? background : Qt.rgba(1, 1, 1, 0.96)

  // A wash *on top of* an accent fill — the badge behind an icon, the track of
  // a switch. It has to be struck from whatever reads on that accent rather
  // than from white: on a light accent a white wash is invisible, which is how
  // a themed window loses half a control without erroring.
  function onAccentWash(alpha) {
    return Qt.rgba(onAccent.r, onAccent.g, onAccent.b, alpha)
  }

  // ---------------- shape ---------------------------------------------------
  // Hyprland's rounding drives the window; inside it, cards and pills need a
  // radius even when the user runs square corners, or the design's cards
  // collapse into ruled lines. A floor, not a fixed value: a rounded theme
  // still rounds these more.
  readonly property int cardRadius: Math.max(Style.space(8), Style.cornerRadius)
  readonly property int chipRadius: Math.max(Style.space(6), Style.cornerRadius)
  readonly property int iconRadius: Math.max(Style.space(6), Style.cornerRadius)
  // A pill is round whatever the theme says: it is the shape that means
  // "this is a value you can change", and a square one means nothing.
  readonly property int pillRadius: Style.space(999)

  // ---------------- cluster tints -------------------------------------------
  // The sidebar gives every cluster a tinted icon square, which is what lets
  // the eye find "the network one" without reading. The design picks eight
  // colours; a themed window has one accent, so the clusters are spread along
  // the distance between the accent and the foreground instead. That keeps
  // them distinguishable from each other and in the theme at the same time.
  function clusterTint(step, total) {
    var span = Math.max(1, total - 1)
    return Qt.tint(accent, Qt.rgba(foreground.r, foreground.g, foreground.b,
                                   0.55 * (step / span)))
  }
}
