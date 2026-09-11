# Part of OmaControl. Sourced by bin/omacontrol; not run on its own.
#
# Power: what the battery is doing, and the profile the machine runs at. The
# profile is remembered per power source, the
# way omarchy-powerprofiles-set stores it: a laptop wants performance on the
# wall and power-saver on the train, and should not be asked twice a day.

POWERPROFILES_STATE="${OMARCHY_POWERPROFILES_STATE_DIR:-${XDG_STATE_HOME:-$HOME_DIR/.local/state}/omarchy/powerprofiles}"

power_battery_device() {
  capture upower -e | grep -m1 'BAT'
}

# upower's own report, reduced to the handful of facts worth showing.
power_battery_reading() {
  local device=$1
  [[ -n $device ]] || { echo '{}'; return; }

  # `energy-full-design` also matches /energy-full:/ and `energy-empty` matches
  # /energy:/, so every one of these is anchored on the whole field name.
  capture upower -i "$device" | awk -F': +' '
    function trim(v) { gsub(/^[ \t]+|[ \t]+$/, "", v); return v }
    function number(v) { gsub(/[^0-9.].*$/, "", v); return v }
    /state:/ { state = trim($2) }
    /percentage:/ { percentage = trim($2); sub(/%$/, "", percentage) }
    /time to empty:/ { remaining = trim($2) }
    /time to full:/ { untilFull = trim($2) }
    /^ +capacity:/ { health = trim($2); sub(/%$/, "", health) }
    /energy-rate:/ { rate = trim($2); sub(/ W$/, "", rate) }
    /^ +energy:/ { energy = number(trim($2)) }
    /^ +energy-full:/ { energyFull = number(trim($2)) }
    /^ +energy-full-design:/ { energyDesign = number(trim($2)) }
    # Not every firmware counts them, and the ones that do not say so in
    # several ways — a missing line, N/A, or -1.
    /charge-cycles:/ { cycles = trim($2) }
    /warning-level:/ { warning = trim($2) }
    END {
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
        state, percentage, remaining, untilFull, health, rate,
        energy, energyFull, energyDesign, cycles, warning
    }
  ' | jq -R -s -c 'split("\n") | .[0] | split("\t")
    | { state: .[0],
        percentage: ((.[1] | tonumber?) // null),
        remaining: (if .[0] == "charging" then .[3] else .[2] end),
        health: ((.[4] | tonumber?) // null),
        watts: ((.[5] | tonumber?) // null),
        energy: ((.[6] | tonumber?) // null),
        energyFull: ((.[7] | tonumber?) // null),
        energyDesign: ((.[8] | tonumber?) // null),
        cycles: ((.[9] | tonumber?) | if . == null or . < 0 then null else . end),
        # "none" is the answer on every healthy battery, which is a row that
        # says nothing on every day but the bad ones.
        warning: (if .[10] == "none" then "" else (.[10] // "") end) }'
}

# What the machine is actually drawing, which is a different question from
# what the battery has left — and one nothing answers in full.
#
# Three sources, in descending order of how much of the machine they cover:
#
#   the pack          upower's energy-rate, and the only whole-machine figure
#                     there is — but only while running on it. On the mains
#                     nothing measures what the wall is supplying.
#   hwmon power       a chip reporting its own draw: `power1_input` in
#                     microwatts. On an APU that is processor and graphics
#                     together, which is most of the machine's variable draw.
#   intel-rapl        the same idea, and root-only to read, so it is not
#                     offered rather than shown as a permission error.
#
# Per-application watts is not on the list because Linux does not have it: the
# kernel measures the pack and the chips, never the programs.
power_draw() {
  local chips='[]' dir name label microwatts
  for dir in /sys/class/hwmon/hwmon*; do
    [[ -r $dir/power1_input ]] || continue
    microwatts=$(read_file "$dir/power1_input")
    [[ $microwatts =~ ^[0-9]+$ ]] || continue
    (( microwatts > 0 )) || continue
    name=$(read_file "$dir/name")
    label=$(read_file "$dir/power1_label")
    chips=$(jq -c --arg n "${name:-power}" --arg l "${label:-}" --argjson w "$microwatts" \
      '. + [{ name: $n, label: $l, watts: (($w / 1000000) * 10 | round / 10) }]' <<<"$chips")
  done
  printf '%s\n' "$chips"
}

power_state() {
  local device reading profiles current onbattery saved_ac saved_battery

  command -v powerprofilesctl >/dev/null 2>&1 || { echo '{"available": false}'; return; }

  device=$(power_battery_device)
  reading=$(power_battery_reading "$device")
  profiles=$(capture omarchy-powerprofiles-list | jq -R -s -c 'split("\n") | map(select(length > 0))')
  current=$(capture powerprofilesctl get)
  onbattery=$(busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery 2>/dev/null)
  saved_ac=$(read_file "$POWERPROFILES_STATE/ac")
  saved_battery=$(read_file "$POWERPROFILES_STATE/battery")
  local draw
  draw=$(power_draw)

  # A machine with no battery still has power profiles worth setting; the
  # battery half of the page simply has nothing to say.
  jq -cn --argjson reading "${reading:-{\}}" \
    --argjson profiles "${profiles:-[]}" \
    --arg current "${current:-}" \
    --argjson onBattery "$([[ $onbattery == "b true" ]] && echo true || echo false)" \
    --arg savedAc "${saved_ac:-}" \
    --arg savedBattery "${saved_battery:-}" \
    --argjson hasBattery "$([[ -n $device ]] && echo true || echo false)" \
    --argjson draw "${draw:-[]}" \
    '{ available: true,
       hasBattery: $hasBattery,
       onBattery: $onBattery,
       battery: $reading,
       draw: $draw,
       profiles: $profiles,
       current: $current,
       # What is remembered for each source, falling back to what
       # omarchy-powerprofiles-set would itself choose.
       ac: (if $savedAc != "" then $savedAc
            elif ($profiles | index("performance")) then "performance"
            else "balanced" end),
       forBattery: (if $savedBattery != "" then $savedBattery else "balanced" end) }'
}

# The profile is not this window's alone: the bar's power plugin, the menu and
# powerprofilesctl itself all move it, and the battery drains regardless. Three
# things are worth waking for — the daemon's active profile, UPower's battery
# and AC readings, and the files omarchy-powerprofiles-set writes to remember a
# profile per power source — so all three feed one stream of state lines.
power_watch() {
  command -v powerprofilesctl >/dev/null 2>&1 || { echo '{"available": false}'; return; }

  mkdir -p "$POWERPROFILES_STATE" 2>/dev/null
  power_state

  local reader=$$
  {
    local pids=()
    # The monitors outlive nothing: when this subshell goes, so do they.
    trap 'kill "${pids[@]}" 2>/dev/null' EXIT

    gdbus monitor --system --dest net.hadess.PowerProfiles 2>/dev/null & pids+=($!)
    gdbus monitor --system --dest org.freedesktop.UPower 2>/dev/null & pids+=($!)
    inotifywait -q -m -e close_write,create,moved_to "$POWERPROFILES_STATE" 2>/dev/null & pids+=($!)

    # None of them notices the page closing, and a write to a gone reader is
    # only noticed at the next event — which may be hours away. Watch for the
    # reader instead, so the monitors never outlast the window.
    while kill -0 "$reader" 2>/dev/null; do sleep 2; done
  } | while read -r _; do
        # UPower is chatty and a profile change lands as several signals;
        # draining the burst keeps this to one state read per change.
        while read -r -t 0.2 _; do :; done
        power_state
      done
}

power_cmd() {
  local action=${1:-} source=${2:-} profile=${3:-}
  case $action in
    state) power_state ;;
    watch) power_watch ;;
    profile)
      [[ $source == ac || $source == battery ]] || die "expected ac or battery"
      [[ -n $profile ]] || die "no profile given"
      omarchy-powerprofiles-set "$source" "$profile" >/dev/null 2>&1 \
        || die "could not set the $source profile to $profile" ;;
    *) die "unknown battery action '$action'" ;;
  esac
}
