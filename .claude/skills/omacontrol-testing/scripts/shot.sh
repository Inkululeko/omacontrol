#!/usr/bin/env bash
# `grim -g` takes logical coordinates while a full `grim` capture is physical
# pixels, and the card is 90% of the screen centred — three different frames
# of reference. So: capture the whole screen, and crop from that with the
# scale read out of hyprctl rather than assumed. The window is a layer
# surface, not a client, which is why the geometry comes from `hyprctl
# layers`.
set -uo pipefail
out=${1:-${XDG_RUNTIME_DIR:-/tmp}/omacontrol-page.png}

read -r mon scale < <(hyprctl -j monitors | jq -r '.[]|select(.focused)|"\(.name) \(.scale)"')
[ -n "${mon:-}" ] || { echo "no focused monitor" >&2; exit 1; }

geom=$(hyprctl layers -j | jq -r --argjson s "$scale" '
  [..|objects|select(.namespace?=="omacontrol")][0]
  | if . == null then empty else
      "\((.w*$s)|floor)x\((.h*$s)|floor)+\((.x*$s)|floor)+\((.y*$s)|floor)"
    end')
[ -n "$geom" ] || { echo "the omacontrol window is not open" >&2; exit 1; }

full=$(mktemp --suffix=.png)
grim -o "$mon" "$full" || exit 1
magick "$full" -crop "$geom" +repage "$out" && rm -f "$full"
echo "$out"
