# Part of OmaControl. Sourced by bin/omacontrol; not run on its own.

# ------------------------------------------------------------------ displays
#
# `hyprctl keyword monitor` does nothing on a Lua config: it answers "keyword
# can't work with non-legacy parsers. Use eval." on stderr while still exiting
# 0, so a resolution looked applied and never was. Everything here goes
# through `hyprctl eval 'hl.monitor({...})'`, which takes a partial table.
#
# A display is also the one setting on this page worth writing down: it is
# unplugged and plugged back in, and Hyprland matches its monitor rules again
# each time. So what is set here lands in the managed Lua like the rest, and a
# display that is not connected can be configured for the next time it is.
#
# ------------------------------------------------------ which display is which
#
# A connector is not an identity. DP-2 is whichever screen is in that socket:
# the work monitor at the desk and the one at home are both DP-2, and settings
# written against the connector followed the cable rather than the screen — a
# 4K desktop panel handed the laptop dock's scale the moment it was plugged in.
#
# So a display is keyed by what it says about itself. Hyprland matches monitor
# rules on `desc:<description>` as well as on connector name, which is what the
# hand-written `monitor = desc:Dell Inc. DELL U2724D 1A2B3C4, ...` lines in a
# .conf setup have always used. A key here is therefore:
#
#   desc:Dell Inc. DELL U2724D 1A2B3C4   — a display with an EDID description
#   DP-2                                  — the fallback, for a display that
#                                           reports no description at all
#
# The key is what the store is keyed by, what `output` says in the managed Lua,
# and what a setting key (`monitor:<key>:scale`) names. The connector name is
# kept alongside it for the page to show, and for the one place that still has
# to speak connectors: see monitor_lua_scale.
MONITOR_NAME_RE='^[A-Za-z][A-Za-z0-9]*(-[A-Za-z0-9]+)+$'

MONITOR_SCHEMA=3

# What an earlier version of this page wrote down.
#
# Schema 2: it recorded a scale and the mode it read off the display, then
# applied both with `hyprctl keyword monitor` — which does nothing on a Lua
# config. So every entry it left is a setting that never took effect: this
# machine's store asked for scale 1.80 while both displays ran at 1.6. Now that
# these entries are rendered into the managed file, keeping them would apply
# years-old fiction to someone's screens on the next reload. They are dropped
# once instead, and the page starts from what the displays are actually doing.
#
# Schema 3: entries were keyed by connector name. Those are re-keyed to the
# description of whatever is in that connector now — the best guess there is,
# and the same one the user was making when they set it.
monitor_migrate() {
  local schema
  schema=$(jq -r '(.monitorsSchema // 0)' <<<"$(read_store)")
  [[ $schema =~ ^[0-9]+$ ]] || schema=0
  ((schema >= MONITOR_SCHEMA)) && return 0

  # On a .conf setup the keyword worked, so those entries are real settings and
  # not fiction — they are kept, and only the flag is written.
  if ((schema < 2)) && [[ -f $HYPR_DIR/hyprland.lua ]]; then
    edit_store '.monitors = {}
      | if .written then .written |= with_entries(select(.key | startswith("monitor:") | not)) else . end'
  fi

  ((schema < 3)) && monitor_rekey_to_description

  edit_store '.monitorsSchema = $v' --argjson v "$MONITOR_SCHEMA"
}

# Connector name → description key, for everything already written down. Only
# the displays plugged in right now can be re-keyed: nothing else says what was
# ever in that socket. An entry for a display that is not here keeps its
# connector key and goes on working as one.
monitor_rekey_to_description() {
  local map
  map=$(jq -c '
    map(select(.key != .name)) | map({ (.name): .key }) | add // {}' <<<"$(monitor_live)")
  [[ -z $map || $map == "{}" ]] && return 0

  edit_store '
    def rekey($k): $map[$k] // $k;
    .monitors = ((.monitors // {}) | with_entries(.key |= rekey(.)))
    | if .written then
        .written |= with_entries(
          if (.key | startswith("monitor:")) then
            ((.key | ltrimstr("monitor:")) | split(":")) as $parts
            | if ($parts | length) >= 2
              then .key = "monitor:" + rekey($parts[:-1] | join(":")) + ":" + $parts[-1]
              else .key = "monitor:" + rekey($parts | join(":"))
              end
          else . end)
      else . end' --argjson map "$map"
}

# What Hyprland reports, including the displays it knows about but has turned
# off. Modes arrive as "3840x2160@60.00Hz" and go back as "3840x2160@60.00",
# so the "Hz" comes off here rather than in the page.
#
# `mode` is the entry from that same list the display is running, not a string
# built from its width and height: the picker compares what it is set to
# against the options it offers, and 59.99700 matches none of them.
monitor_live() {
  capture hyprctl -j monitors all | jq -c '
    [ .[] | . as $m
      | ([$m.availableModes[]? | sub("Hz$"; "")]
         | reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) as $modes
      | ($m.description // "") as $desc
      | { name: $m.name,
          key: (if $desc == "" then $m.name else "desc:" + $desc end),
          description: $desc,
          disabled: ($m.disabled // false),
          focused: ($m.focused // false),
          scale: $m.scale,
          width: $m.width,
          height: $m.height,
          refreshRate: ($m.refreshRate | floor),
          transform: ($m.transform // 0),
          # Hyprland reports vrr as a boolean when it is off and as the mode
          # number when it is on, so both shapes have to come back as a number.
          vrr: (($m.vrr // 0) | if . == true then 1 elif . == false then 0 else . end),
          hdr: ((($m.colorManagementPreset // "") | ascii_downcase) == "hdr"),
          # "none" is Hyprland saying a display mirrors nothing, which is not
          # the name of a display.
          mirror: (if ($m.mirrorOf // "none") == "none" then "" else $m.mirrorOf end),
          # Where the display sits in the layout, in logical pixels. A disabled
          # display reports -1x-1, which is not a position.
          x: (if ($m.disabled // false) then 0 else ($m.x // 0) end),
          y: (if ($m.disabled // false) then 0 else ($m.y // 0) end),
          modes: $modes,
          # A display that is off reports no mode at all — 0x0 at 60 Hz, which
          # is not a resolution and must never be written into a rule. What it
          # will do when it comes back on is whatever it asks for.
          mode: (if ($m.width // 0) > 0 and ($m.height // 0) > 0
                 then (($modes
                        | map(select(startswith("\($m.width)x\($m.height)@")))
                        | sort_by((split("@")[1] | tonumber) - $m.refreshRate | fabs)
                        | first)
                       // "\($m.width)x\($m.height)@\($m.refreshRate | floor)")
                 else "preferred" end),
          connected: true } ]' 2>/dev/null || echo '[]'
}

# What a display says about itself that Hyprland does not pass on: whether it
# can do HDR at all, and the refresh range it will accept as variable. Both are
# in the EDID the kernel keeps, and neither is worth offering a switch for when
# the answer is no — an HDR switch on a monitor without HDR is a switch that
# does nothing and says nothing about why.
#
# Keyed by connector, which is what /sys names, and folded onto displays by the
# caller. Missing di-edid-decode is not an error: every row it feeds is
# optional.
monitor_edid() {
  command -v di-edid-decode >/dev/null 2>&1 || { echo '{}'; return 0; }
  local out
  out=$(for dir in /sys/class/drm/card*-*/; do
          [[ -r $dir/edid ]] || continue
          local decoded connector
          # di-edid-decode exits non-zero over a warning in an EDID most
          # displays ship with, having printed everything asked of it. The
          # output decides whether it worked, not the status.
          decoded=$(timeout 2 di-edid-decode "$dir/edid" 2>/dev/null)
          [[ -n $decoded ]] || continue
          connector=${dir%/}; connector=${connector##*/}; connector=${connector#*-}
          local hdr=false range
          grep -q 'HDR Static Metadata' <<<"$decoded" && hdr=true
          range=$(grep -o -m1 '[0-9]*-[0-9]* Hz V' <<<"$decoded" | sed 's/ Hz V//')
          printf '%s\t%s\t%s\n' "$connector" "$hdr" "$range"
        done)
  emit_json "$(jq -Rc -s '[ split("\n")[] | select(length > 0) | split("\t")
                           | { key: .[0],
                               value: { hdrCapable: (.[1] == "true"),
                                        vrrRange: (.[2] // "") } } ] | from_entries' <<<"$out")" '{}'
}

# The live display a key names, or `null`. A key matches its own display, and a
# connector name still matches the display in that socket, so a setting written
# before this file knew about descriptions goes on finding its screen.
#
# `desc:` is a prefix match, the way Hyprland matches it: a hand-written
# `desc:Dell Inc. DELL U2724D` names the display whose full description
# carries a serial the user did not type.
#
# $2 is the live list when the caller already has it — one page load asks about
# every display, and `hyprctl monitors all` is not free.
monitor_find() {
  local key=$1 live=${2:-}
  [[ -n $live ]] || live=$(monitor_live)
  jq -c --arg n "$key" '
    def matches($e):
      $e.key == $n
      or $e.name == $n
      or (($n | startswith("desc:")) and $e.description != ""
          and ($e.description | startswith($n[5:])));
    (map(select(matches(.))) | first) // null' <<<"$live"
}

# The key this window should file a display under, given whatever it was handed:
# a connector name, a partial description, or a key already. A display that is
# not connected cannot be resolved, so what was typed stands as the key.
monitor_key() {
  local found
  found=$(monitor_find "$1" "${2:-}")
  [[ $found == null ]] && { printf '%s\n' "$1"; return 0; }
  jq -r '.key' <<<"$found"
}

# The connector a key is plugged into, or nothing. Only for talking to things
# that deal in connectors — Hyprland itself takes the key.
monitor_output_name() {
  local found
  found=$(monitor_find "$1" "${2:-}")
  [[ $found == null ]] && return 0
  jq -r '.name' <<<"$found"
}

# Their own hl.monitor lines. Read, never written: a display already set up in
# monitors.lua would otherwise read as unconfigured here, and a resolution
# picked from this page would silently fight the line they wrote.
#
# One call per line is what Omarchy's own template writes, and all that is
# read: a table split over several lines is left to say nothing rather than be
# half understood. The global rule (`output = ""`) is not a display.
#
# Their output string is put through monitor_key, so a rule they wrote against
# DP-2 and one this window wrote against the description of the screen in DP-2
# are recognised as being about the same display.
monitor_config_settings() {
  local file line name mode scale live out='{}'
  live=$(monitor_live)
  while IFS= read -r line; do
    name=$(sed -nE 's/.*output *= *"([^"]+)".*/\1/p' <<<"$line")
    [[ -n $name ]] || continue
    name=$(monitor_key "$name" "$live")
    mode=$(sed -nE 's/.*mode *= *"([^"]+)".*/\1/p' <<<"$line")
    scale=$(sed -nE 's/.*scale *= *([0-9]+(\.[0-9]+)?).*/\1/p' <<<"$line")
    out=$(jq -c --arg n "$name" --arg m "$mode" --arg s "$scale" \
      '.[$n] = ((.[$n] // {})
        | (if $m == "" then . else .mode = $m end)
        | (if $s == "" then . else .scale = ($s | tonumber) end))' <<<"$out")
  done < <(for file in "$HYPR_DIR"/*.lua; do
             [[ -f $file ]] || continue
             [[ $file == "$MANAGED_LUA" ]] && continue
             read_file "$file" | grep -E '^[^-]*hl\.monitor'
           done)
  printf '%s\n' "$out"
}

# Every display worth a group on the page: the ones plugged in, the ones this
# window has settings for, and the ones their own config names. A display you
# own is not always plugged in, so the ones that are not are listed too rather
# than losing their settings the moment they are unplugged.
#
# `name` is the key — it is what a setting key is built from, so the page keeps
# calling it the display's name. `label` is what to put on the group, since
# "desc:Dell Inc. DELL U2724D 1A2B3C4" is an identity and not a title.
monitor_state() {
  monitor_migrate
  jq -c -n \
    --argjson live "$(monitor_live)" \
    --argjson stored "$(jq -c '.monitors // {}' <<<"$(read_store)")" \
    --argjson configured "$(monitor_config_settings)" \
    --argjson edid "$(monitor_edid)" '
    def entry($name; $live):
      ($stored[$name] // {}) as $ours
      | ($configured[$name] // {}) as $theirs
      | ($live.description // (if ($name | startswith("desc:")) then $name[5:] else "" end)) as $desc
      | { name: $name,
          output: ($live.name // ""),
          description: $desc,
          # The description alone: the connector has a row of its own, and a
          # description out of Hyprland is long enough without it. No
          # apostrophe in this comment: the whole filter is one shell string.
          label: (if $desc != "" then $desc
                  elif $live != null then $live.name
                  else $name end),
          connected: ($live != null),
          disabled: ($live.disabled // false),
          modes: ($live.modes // []),
          width: $live.width,
          height: $live.height,
          refreshRate: $live.refreshRate,
          # What is in force: what was set here, else what their config gives
          # it, else what it is actually running.
          mode: ($ours.mode // $live.mode // $theirs.mode // "preferred"),
          scale: ($ours.scale // $live.scale // $theirs.scale // 1),
          # The rest of a monitor rule, each read the same way: what was set
          # here, else what the display is actually doing. A display that is
          # not here answers only from what we wrote down.
          transform: (($ours.transform // $live.transform // 0) | tonumber? // 0),
          vrr: (($ours.vrr // $live.vrr // 0) | tonumber? // 0),
          hdr: (($ours.hdr // $live.hdr // false) == true),
          mirror: (($ours.mirror // $live.mirror // "") | tostring),
          # A disabled display is the one setting here that is a fact about
          # the rule rather than about the screen: Hyprland reports a display
          # it was told to turn off as disabled, which is the same answer.
          off: (($ours.disabled // $live.disabled // false) == true),
          position: ($ours.position // (if $live == null then "" else "\($live.x)x\($live.y)" end)),
          # What the display can do, rather than what it is doing. Both come
          # off its EDID, and neither is worth a control when the answer is no.
          hdrCapable: ((($edid[$live.name // ""] // {}).hdrCapable // false) == true),
          vrrRange: ((($edid[$live.name // ""] // {}).vrrRange // "") | tostring),
          settings: $ours,
          configured: $theirs };
    ($live | map(.key)) as $connected
    | ($connected + (($stored | keys) + ($configured | keys) | sort | unique)
       | reduce .[] as $n ([]; if index($n) then . else . + [$n] end)) as $names
    | [ $names[] as $n
        | entry($n; ($live | map(select(.key == $n)) | first)) ]'
}

# The fields a display's settings make, in the order and the spelling Hyprland
# takes them — one definition, because the live apply and the generated file
# have to say exactly the same thing and once did not: the file rendered its
# own `hdr = true`, which is not a Hyprland key at all.
#
# Two fields are not written the way they are stored. `disabled` is the whole
# rule — a display that is off has no mode, position or scale to be given —
# and HDR is two Hyprland keys rather than one, so it is kept as the switch
# the page shows and rendered as what Hyprland takes.
MONITOR_FIELDS_JQ='
  def monitor_fields($s):
    if ($s.disabled // false) == true then [["disabled", true]]
    else
      [ $s | to_entries[]
        | select(.key != "disabled" and .key != "hdr")
        # An empty mirror is a display mirroring nothing, which is what
        # leaving the key out already says.
        | select((.value | type) != "string" or .value != "")
        | [.key, .value] ]
      + (if ($s.hdr // false) == true then [["cm", "hdr"], ["bitdepth", 10]] else [] end)
    end;
  def monitor_field_text($pair):
    $pair[0] + " = "
    + (if ($pair[1] | type) == "string" then ($pair[1] | @json) else ($pair[1] | tostring) end);
'

# One `hl.monitor({...})` table on a single line, for `hyprctl eval`.
monitor_lua_table() {
  local name=$1 settings=$2
  jq -rn --arg n "$name" --argjson s "$settings" "$MONITOR_FIELDS_JQ"'
    "{ output = " + ($n | @json)
    + ([monitor_fields($s)[] | ", " + monitor_field_text(.)] | join(""))
    + " }"'
}

# The same rule as the block the managed file carries.
monitor_lua_block() {
  local name=$1 settings=$2
  jq -rn --arg n "$name" --argjson s "$settings" "$MONITOR_FIELDS_JQ"'
    "hl.monitor({\n  output = " + ($n | @json) + ","
    + ([monitor_fields($s)[] | "\n  " + monitor_field_text(.) + ","] | join(""))
    + "\n})\n"'
}

monitor_settings() {
  jq -c --arg n "$1" '(.monitors // {}) | .[$n] // {}' <<<"$(read_store)"
}

# A display that is not plugged in has nothing to apply to; the managed file
# already holds the rule, and Hyprland matches it again on the next connect.
monitor_apply_live() {
  local name=$1 settings
  settings=$(monitor_settings "$name")
  [[ $settings == "{}" ]] && return 0
  # A rule that says nothing about `disabled` still turns a display that is off
  # back on the moment it is evalled — and the display may be off because
  # Omarchy's toggle says so, which nothing but a reload puts back. Changing a
  # scale is not a reason to light a screen up. So the rule is left to the
  # generated file and the reload that follows it, unless turning the display
  # on is what was asked for.
  if ! jq -e 'has("disabled")' <<<"$settings" >/dev/null \
     && [[ $(monitor_value_now "$name" disabled) == true ]]; then
    return 0
  fi
  hyprctl eval "hl.monitor($(monitor_lua_table "$name" "$settings"))" >/dev/null 2>&1
}

# Hyprland takes a mode the display cannot do without complaining and quietly
# keeps something else, so the window would show a resolution the screen is
# not running. The list the display itself reports is the check.
monitor_mode_supported() {
  local name=$1 mode=$2 found
  [[ $mode == preferred ]] && return 0
  found=$(monitor_find "$name")
  [[ $found == null ]] && return 0
  jq -e --arg m "$mode" '.modes | index($m) != null' <<<"$found" >/dev/null
}

monitor_set() {
  local name=$1 field=$2 value=$3 json
  [[ -n $name ]] || die "no display given"
  monitor_migrate
  # Whatever the caller named the display, the store speaks keys: a rule filed
  # under DP-2 would be handed to the next screen in that socket.
  name=$(monitor_key "$name")

  case $field in
    mode)
      [[ $value == preferred || $value =~ ^[0-9]+x[0-9]+@[0-9]+(\.[0-9]+)?$ ]] \
        || die "'$value' is not a resolution"
      monitor_mode_supported "$name" "$value" || die "$name cannot run $value"
      json=$(jq -Rn --arg v "$value" '$v') ;;
    scale)
      [[ $value =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "'$value' is not a scale"
      json=$value ;;
    transform)
      [[ $value =~ ^[0-7]$ ]] || die "'$value' is not a rotation"
      json=$value ;;
    # 0 off, 1 on, 2 only while something is fullscreen — Hyprland's own
    # numbering, kept rather than renamed so the generated Lua reads like the
    # documentation for it.
    vrr)
      [[ $value =~ ^[0-2]$ ]] || die "'$value' is not a variable refresh mode"
      json=$value ;;
    hdr|disabled)
      [[ $value == true || $value == false ]] || die "'$value' is not true or false"
      # A display cannot be the only one and be turned off: the desktop would
      # have nowhere to be, and nothing on screen could turn it back on.
      [[ $field == disabled && $value == true ]] && monitor_last_one_on "$name" \
        && die "this is the only display that is on"
      # Turning the laptop panel off is Omarchy's, not ours.
      [[ $field == disabled ]] && monitor_is_internal "$name" && monitor_toggles_loaded \
        && { monitor_internal_power "$name" "$value"; return; }
      json=$value ;;
    mirror)
      if [[ -n $value ]]; then
        # Hyprland mirrors by the name of another output, and a display cannot
        # mirror itself.
        local target
        target=$(monitor_output_name "$(monitor_key "$value")")
        [[ -n $target ]] || die "'$value' is not a display that is plugged in"
        [[ $target == "$(monitor_output_name "$name")" ]] && die "a display cannot mirror itself"
        value=$target
      fi
      json=$(jq -Rn --arg v "$value" '$v') ;;
    position)
      [[ $value == auto || $value =~ ^-?[0-9]+x-?[0-9]+$ ]] \
        || die "'$value' is not a position"
      json=$(jq -Rn --arg v "$value" '$v') ;;
    *) die "unknown display setting '$field'" ;;
  esac

  # A monitor rule is not merged with the ones before it: ours is more specific
  # than Omarchy's `output = ""` and loads last, so it replaces that rule whole.
  # Sending a mode on its own therefore took the scale with it — DP-2 dropped to
  # 1.0 the moment a resolution was picked. Whatever the user did not set is
  # filled in with what the display is doing now, so the rule says all of it.
  edit_store '.monitors = ((.monitors // {})
    | .[$n] = ($now + (.[$n] // {}) + { ($f): $v }))' \
    --arg n "$name" --arg f "$field" --argjson v "$json" \
    --argjson now "$(monitor_in_force "$name")"
  monitor_apply_live "$name"

  # Hyprland takes a scale it cannot do exactly, snaps to the nearest one that
  # gives whole pixels, and says so only in its own log. Recording what it
  # asked for would leave the page showing a number the screen is not using.
  #
  # A display that is off has taken nothing, and answers with the scale it had
  # when it was last on — so a scale chosen for a screen to come back to is
  # kept as it was chosen rather than read back from a screen that is dark.
  if [[ $field == scale ]]; then
    local applied
    applied=$(monitor_find "$name" \
      | jq -r 'if (. == null or .disabled) then empty else (.scale | tostring) end')
    [[ -n $applied && $applied != "$value" ]] \
      && edit_store '.monitors = ((.monitors // {}) | .[$n] = (.[$n] + { scale: $s }))' \
           --arg n "$name" --argjson s "$applied"
  fi

  [[ $field == scale ]] && monitor_is_internal "$name" \
    && monitor_lua_scale "$name" "$(monitor_settings "$name" | jq -r '.scale')"
  return 0
}

# What a display is running, in the shape a rule takes — because our rule
# replaces Omarchy's whole, rather than merging with it. Sending a mode on its
# own therefore used to take the scale with it.
#
# Position is deliberately absent unless the arrangement is already ours:
# Omarchy places every display with `position = "auto"`, and pinning
# coordinates nobody asked for would freeze a layout that currently follows
# whatever is plugged in. Once a display has been dragged, its position is in
# the store and stays in the rule like anything else.
monitor_in_force() {
  local found
  found=$(monitor_find "$1")
  [[ $found == null ]] && { echo '{}'; return 0; }
  # A display that is off has no mode and no position to record, and a rule
  # carrying the 0x0 it reports would hand it that when it came back on.
  jq -c '(if .mode == "preferred" then {} else { mode: .mode } end)
         + { scale: .scale, transform: .transform, vrr: .vrr }
         + (if .hdr then { hdr: true } else {} end)
         + (if .mirror == "" then {} else { mirror: .mirror } end)' <<<"$found"
}

# Whether turning this display off would leave nothing on. Counted from what
# is plugged in and not already off, since a display in a drawer is not a
# screen the desktop can move to — and asked only of a display that is on
# right now, or setting up a monitor that is still in its box would be refused
# for taking away a screen it is not providing.
monitor_last_one_on() {
  local key=$1 live found on
  live=$(monitor_live)
  found=$(monitor_find "$key" "$live")
  [[ $found == null ]] && return 1
  jq -e '.disabled == true' <<<"$found" >/dev/null && return 1
  on=$(jq -r '[ .[] | select(.disabled != true) ] | length' <<<"$live")
  (( ${on:-0} <= 1 ))
}

# Putting one back writes the value the display had and then drops the rule:
# a monitor rule is an override like a Hyprland key, and one left behind saying
# what the display already does would go on overriding a mode their config —
# or the display's own EDID — changes later.
monitor_unset() {
  local name=$1 field=$2 now
  name=$(monitor_key "$name")
  # What is left has to be a whole rule, and in one write: Hyprland reloads a
  # config file the moment it changes, so a partial rule on disk is applied
  # before anything can fill it back in — which put the display at scale 1.0
  # between the two writes. So the value in force is read first, and the field
  # the user is dropping is replaced by it rather than deleted.
  now=$(monitor_in_force "$name")
  edit_store '.monitors = ((.monitors // {})
    | .[$n] = ($now + ((.[$n] // {}) | del(.[$f])))
    | with_entries(select(.value != {})))' \
    --arg n "$name" --arg f "$field" --argjson now "$now"
  monitor_apply_live "$name"
  [[ $field == scale ]] && monitor_is_internal "$name" && monitor_lua_scale "$name" --
  return 0
}

# ------------------------------------------------- the laptop panel is theirs
#
# Omarchy watches the internal panel and puts its scale back. While a laptop is
# docked, `omarchy-hyprland-monitor-clamshell` runs every couple of seconds,
# reads the scale out of ~/.config/hypr/monitors.lua, and re-applies it if the
# panel is running anything else — so a scale set from here survived about a
# second. It won every time, and no error said so.
#
# The way to set the internal panel's scale is therefore to make that file say
# it too: the rule for the panel, in the file Omarchy reads, edited in place the
# way every other hand-written config here is. Then the watcher enforces the
# number this page chose instead of fighting it.
#
# Only the scale, and only the internal panel: an external display is nobody
# else's business, and stays in the managed file alone.
#
# This is also the one place that has to write a connector name rather than a
# description key. The watcher looks the panel's rule up by the output name
# `omarchy-hyprland-monitor-laptop` prints, so a `desc:` rule in that file is a
# rule it cannot see — it would read no scale, fall back, and fight us again.
monitor_internal() {
  command -v omarchy-hyprland-monitor-laptop >/dev/null 2>&1 || return 0
  omarchy-hyprland-monitor-laptop 2>/dev/null
}

monitor_is_internal() {
  local internal output
  internal=$(monitor_internal)
  [[ -n $internal ]] || return 1
  output=$(monitor_output_name "$1")
  # A key that resolves to nothing may still be the panel's own connector,
  # written down before it knew about descriptions.
  [[ -z $output ]] && output=$1
  [[ $output == "$internal" ]]
}

# Turning it off is theirs as well, and for a better reason than the scale.
#
# Omarchy writes the rule that disables the panel into its own toggles
# directory, and it is the writing-down that matters: the clamshell watcher
# and `omarchy-hw-recover-internal-monitor` clear that file again the moment
# the external display goes away, so a lid closed on a dock is never left with
# no screen at all. A `disabled = true` of ours has no such way back — the
# panel would stay dark through the undock and the next boot, with nothing on
# screen to turn it on with.
#
# So their toggle does it, and whatever we wrote about the panel being off goes
# with it: ours is read before the toggles and would put the panel straight
# back on.
monitor_internal_power() {
  local key=$1 off=$2 action=on
  [[ $off == true ]] && action=off

  if jq -e --arg n "$key" '(((.monitors // {})[$n]) // {}) | has("disabled")' \
       <<<"$(read_store)" >/dev/null; then
    edit_store '.monitors = ((.monitors // {})
      | .[$n] |= del(.disabled)
      | with_entries(select(.value != {})))' --arg n "$key"
  fi

  omarchy-hyprland-monitor-internal "$action" >/dev/null 2>&1 \
    || die "the laptop display could not be turned $action"
}

# Their toggles are Lua files loaded by a require in `hyprland.lua`. Where that
# require is not there — a setup still on `.conf`, or a config that dropped it
# — the toggle would write a file nothing reads, which is a switch that does
# nothing and says nothing about why. Our own rule goes in instead.
monitor_toggles_loaded() {
  command -v omarchy-hyprland-monitor-internal >/dev/null 2>&1 || return 1
  [[ -f $HYPR_DIR/hyprland.lua ]] || return 1
  read_file "$HYPR_DIR/hyprland.lua" | grep -qE "$HYPR_TOGGLES_RE"
}

MONITOR_LUA_MARKER="-- omacontrol"

# `--` removes what this window added; a number writes it. A rule the user wrote
# themselves only ever has its scale replaced — the rest of their line, comment
# included, is copied through.
#
# Every line this adds carries the marker, the comments as well as the rule, so
# removing it takes the whole block rather than leaving three lines of
# explanation for a rule that is no longer there.
monitor_lua_scale() {
  local name=$1 value=$2 file="$HYPR_DIR/monitors.lua" previous next
  [[ -f $file ]] || return 0

  # The watcher reads this file by connector name, so that is what goes in it —
  # see the block above. A key that names no connected display cannot be
  # written here at all.
  local output
  output=$(monitor_output_name "$name")
  [[ -n $output ]] || output=$name
  [[ $output =~ $MONITOR_NAME_RE ]] || return 0
  name=$output

  previous=$(read_file "$file")
  # The pattern is built here rather than inside awk: a quoted output name in
  # an awk string literal inside a shell single-quoted program is three levels
  # of quoting, and it collapsed silently — every rule read as no rule.
  local pattern="output[ \t]*=[ \t]*\"$name\""
  next=$(awk -v value="$value" -v name="$name" -v marker="$MONITOR_LUA_MARKER" -v pattern="$pattern" '
    function flush() {
      for (i = 1; i <= held; i++) print holding[i]
      held = 0
    }
    # Lines this window wrote are held back until it is clear whether the rule
    # they explain is staying.
    index($0, marker ":") == 1 { holding[++held] = $0; next }
    /^[ \t]*--/ { flush(); print; next }
    $0 ~ /hl\.monitor/ && $0 ~ pattern {
      if (value == "--") {
        # Ours goes, comments and all; theirs stays, since the scale in it is
        # the one this reset has just written back.
        if (index($0, marker)) { held = 0; next }
        flush()
        print
        found = 1
        next
      }
      flush()
      if ($0 ~ /scale[ \t]*=/) sub(/scale[ \t]*=[ \t]*[^,;} \t]+/, "scale = " value)
      else sub(/\}[ \t]*\)/, ", scale = " value " })")
      print
      found = 1
      next
    }
    { flush(); print }
    END {
      flush()
      if (!found && value != "--") {
        print marker ": the internal panel'"'"'s scale is kept here as well, because"
        print marker ": omarchy-hyprland-monitor-clamshell reads this file and puts"
        print marker ": the panel back to it every couple of seconds while docked."
        printf "hl.monitor({ output = \"%s\", mode = \"preferred\", position = \"auto\", scale = %s })  %s\n", name, value, marker
      }
    }' <<<"$previous")

  [[ -n $next ]] || return 0
  [[ $next == "$previous" ]] && return 0

  backup_once "$file" || return 1
  write_file "$file" <<<"$next" || return 1

  # Their config, so the edit is checked in their terms and put back if it
  # broke: an unparseable monitors.lua is a session that does not come up.
  if ! luac -p "$file" >/dev/null 2>&1; then
    write_file "$file" <<<"$previous"
    die "the edit to monitors.lua would not compile; nothing was changed"
  fi
}

# Handing a display back: our rule goes, and the reload is what makes their
# config — or the display's own preferred mode — take effect again.
monitor_forget() {
  local name=$1
  [[ -n $name ]] || die "no display given"
  # Only a key that is actually in the store is resolved: forgetting must be
  # able to reach an entry whose display is long gone.
  jq -e --arg n "$name" '(.monitors // {}) | has($n)' <<<"$(read_store)" >/dev/null \
    || name=$(monitor_key "$name")
  edit_store '.monitors = ((.monitors // {}) | del(.[$n]))
    | if .written then .written |= with_entries(select(.key | startswith("monitor:" + $n + ":") | not)) else . end' \
    --arg n "$name"
  monitor_is_internal "$name" && monitor_lua_scale "$name" --
  hyprctl reload >/dev/null 2>&1 || true
}

# What a display is set to now, for the change marks and the way back. A
# display that is not connected can only answer from what we wrote down.
#
# Position and disabled are asked for in the words a rule uses; the live
# reading spells them as coordinates and as a flag, so they are translated
# here rather than leaving two fields that silently never match.
monitor_value_now() {
  local name=$1 field=$2 found
  found=$(monitor_find "$name")
  [[ $found == null ]] && return 0
  case $field in
    position) jq -r 'if .disabled then empty else "\(.x)x\(.y)" end' <<<"$found" ;;
    disabled) jq -r '.disabled | tostring' <<<"$found" ;;
    *) jq -r --arg f "$field" 'if has($f) then .[$f] | tostring else empty end' <<<"$found" ;;
  esac
}

# ------------------------------------------------------------------ brightness
#
# Not a monitor rule and not in the state document: brightness is a live
# reading like volume, moved by the media keys and by Omarchy's own OSD, and
# on a desktop monitor it is a DDC/CI round trip over the video cable — two
# thirds of a second the first time, which is not a price every write on every
# other page should pay. The Displays page asks for it while it is open.
#
# omarchy-brightness-display already knows that a laptop panel is the kernel
# backlight and everything else is DDC, and that an Apple display is neither.
monitor_brightness() {
  command -v omarchy-brightness-display >/dev/null 2>&1 || { echo '{}'; return 0; }
  local outputs
  outputs=$(monitor_live | jq -r '.[] | select(.disabled != true) | .name')
  [[ -n $outputs ]] || { echo '{}'; return 0; }

  par_begin || { echo '{}'; return 0; }
  local output
  while read -r output; do
    [[ -n $output ]] || continue
    par_run "$output" monitor_brightness_of "$output"
  done <<<"$outputs"
  par_wait

  local out='{}' value
  while read -r output; do
    [[ -n $output ]] || continue
    value=$(par_get "$output" '')
    [[ $value =~ ^[0-9]+$ ]] || continue
    out=$(jq -c --arg n "$output" --argjson v "$value" '.[$n] = $v' <<<"$out")
  done <<<"$outputs"
  par_end
  printf '%s\n' "$out"
}

monitor_brightness_of() {
  timeout 5 omarchy-brightness-display --no-osd --monitor "$1" 2>/dev/null \
    | grep -oE '^[0-9]+' | head -n1
}

# The percentage goes to the display in front of the reader, so it is applied
# and never written down: nothing here is undoing it later, and the next read
# asks the screen rather than the store.
monitor_brightness_set() {
  local key=$1 value=$2 output
  [[ $value =~ ^[0-9]+$ ]] || die "'$value' is not a brightness"
  (( value >= 0 && value <= 100 )) || die "brightness is a percentage"
  output=$(monitor_output_name "$(monitor_key "$key")")
  [[ -n $output ]] || die "that display is not plugged in"
  omarchy-brightness-display --no-osd --monitor "$output" "$value%" >/dev/null 2>&1
}

monitor_cmd() {
  case ${1:-state} in
    state) monitor_state ;;
    brightness) shift
      if (( $# >= 2 )); then monitor_brightness_set "$1" "$2"; else monitor_brightness; fi ;;
    *) die "usage: omacontrol display state|brightness [<display> <percent>]" ;;
  esac
}
