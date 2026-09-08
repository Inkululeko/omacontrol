# Part of OmaControl. Sourced by bin/omacontrol; not run on its own.
#
# The Overview page: the handful of switches people reach for several times a
# day, the two things worth starting from here, and whatever needs attention.
#
# Every switch on this page is Omarchy's own — night light, do-not-disturb,
# staying awake, dictation each already have a command that owns the state and
# the side effects. This module asks them and relays the answer; it does not
# keep a copy of what it thinks is on. That is the difference between a page
# that agrees with the bar and one that drifts from it.

overview_toggles() {
  par_begin || { echo '[]'; return; }
  par_run nightlight overview_nightlight
  par_run dnd overview_dnd
  par_run awake overview_stay_awake
  par_run dictation overview_dictation
  par_wait

  local nightlight dnd awake dictation
  nightlight=$(par_get nightlight '{}')
  dnd=$(par_get dnd '{}')
  awake=$(par_get awake '{}')
  dictation=$(par_get dictation '{}')
  par_end

  jq -cn \
    --argjson nightlight "${nightlight:-{\}}" \
    --argjson dnd "${dnd:-{\}}" \
    --argjson awake "${awake:-{\}}" \
    --argjson dictation "${dictation:-{\}}" '''
    [ { id: "nightlight", label: "Night light" } + $nightlight,
      { id: "dnd", label: "Do not disturb" } + $dnd,
      { id: "awake", label: "Stay awake" } + $awake,
      { id: "dictation", label: "Dictation" } + $dictation ]
    # A switch for something that is not installed is a switch that cannot do
    # anything, so it is not offered.
    | map(select(.available != false))'''
}

overview_nightlight() {
  local status
  status=$(capture omarchy-toggle-nightlight --status)
  [[ -n $status ]] || { echo '{"available":false}'; return; }
  emit_json "$(jq -c '{ on: (.enabled == true),
           note: (if .enabled == true
                  then ((.temperature | tostring) + " K")
                  else "Off" end) }' <<<"$status" 2>/dev/null)" '{"available":false}'
}

overview_dnd() {
  local state
  # The shell owns do-not-disturb, so the shell is asked. There is no file to
  # read: notifications are held in the running process.
  state=$(capture omarchy-shell notifications dndState)
  case ${state:-} in
    on)  echo '{"on":true,"note":"Notifications held"}' ;;
    off) echo '{"on":false,"note":"Notifications shown"}' ;;
    *)   echo '{"available":false}' ;;
  esac
}

overview_stay_awake() {
  local status
  status=$(capture omarchy-toggle-idle --status)
  [[ -n $status ]] || { echo '{"available":false}'; return; }
  emit_json "$(jq -c '{ on: (.enabled == true),
           note: (if .enabled == true then "Idle inhibited"
                  else "Idles and locks normally" end) }' <<<"$status" 2>/dev/null)" \
    '{"available":false}'
}

# voxtype answers about itself in the same JSON the bar's indicator reads, so
# the switch shows what is actually happening rather than a guess: `class` is
# idle or recording, and `model` is the one thing that says whether it is set
# up at all.
#
# Installed is not the same as usable. A voxtype with no model will not
# transcribe anything, and a switch for it is a switch that cannot work — so
# that counts as unavailable and the row is not offered.
overview_dictation() {
  omarchy-cmd-present voxtype || { echo '{"available":false}'; return; }
  local status
  status=$(capture voxtype status --extended --format json)
  [[ -n $status ]] || { echo '{"available":false}'; return; }

  emit_json "$(jq -c '''
    if ((.model // "") == "") then { available: false }
    else { on: ((.class // "idle") == "recording"),
           note: (if (.class // "") == "recording" then "Recording"
                  else ("Ready · " + .model) end) }
    end''' <<<"$status" 2>/dev/null)" '{"available":false}'
}

# What the window would tell you if you had not asked. Only what the shell has
# to be asked for: the window already holds its own version and the monitor
# list, so the page derives those notices from state it has rather than paying
# to read them twice.
#
# Package updates are deliberately not here. Answering that is a network round
# trip — `checkupdates` syncs a database — and nothing in this window may wait
# on the network. Omarchy's own update indicator in the bar already says it.
overview_attention() {
  par_begin || { echo '[]'; return; }
  par_run boot overview_boot_space
  par_run peripherals overview_low_peripherals
  par_wait
  local boot peripherals
  boot=$(par_get boot 'null')
  peripherals=$(par_get peripherals '[]')
  par_end

  jq -cn --argjson boot "${boot:-null}" --argjson peripherals "${peripherals:-[]}" \
    '[ $boot ] + $peripherals | map(select(. != null))'
}

# A keyboard or mouse about to die is the one thing on this list the reader
# cannot find out any other way — a Bluetooth peripheral does not warn you, it
# just stops. upower knows, because BlueZ tells it.
#
# 20 % is the threshold: low enough not to nag, high enough that there is time
# to do something before the device drops off mid-sentence.
overview_low_peripherals() {
  local devices
  devices=$(capture upower -e | grep -E '/(mouse|keyboard|headset|headphones|pen|touchpad)_')
  [[ -n ${devices:-} ]] || { echo '[]'; return; }

  local out=() device info model percent
  while read -r device; do
    [[ -n $device ]] || continue
    info=$(capture upower -i "$device")
    percent=$(awk '/percentage:/ { gsub(/%/, "", $2); print $2; exit }' <<<"$info")
    [[ -n ${percent:-} ]] || continue
    [[ ${percent%%.*} -lt 20 ]] 2>/dev/null || continue
    model=$(awk -F': +' '/model:/ { print $2; exit }' <<<"$info")
    [[ -n ${model:-} ]] || model="A Bluetooth device"
    out+=("$(jq -cn --arg model "$model" --argjson percent "${percent%%.*}" \
      '{ kind: "peripheral",
         id: ("peripheral:" + $model),
         title: ($model + " is at " + ($percent | tostring) + " %"),
         note: "Charge it before it drops off Bluetooth.",
         action: "bluetooth", actionLabel: "Open Bluetooth" }')")
  done <<<"$devices"

  ((${#out[@]})) && printf '%s\n' "${out[@]}" | jq -cs '.' || echo '[]'
}

# ---------------------------------------------------------------- what is due
#
# Three sources, each already cached by whoever owns it: the package list this
# window keeps, the plugin-update cache the Plugins page reads, and Omarchy's
# own version. Nothing here syncs anything — the page shows what is known and
# says when it was last asked.
overview_updates() {
  local pending plugins version channel
  pending=$(packages_pending_cached)
  plugins=$(plugin_updates_cache)
  version=$(omarchy_version)
  channel=$(omarchy_channel)

  jq -cn \
    --argjson pending "${pending:-{\}}" \
    --argjson plugins "${plugins:-{\}}" \
    --arg version "$version" \
    --arg channel "$channel" '''
    ( [ $pending.items[]? ] ) as $items
    # Omarchy ships as a package like everything else, so its own row is that
    # package pulled out of the list and named properly.
    | ( $items | map(select(.name == "omarchy" or .name == "omarchy-dev")) | first ) as $omarchy
    | ( [ $plugins.results // {} | to_entries[] | select(.value > 0) | .key ] ) as $behind
    | { checkedAt: ($pending.checkedAt // 0),
        version: $version,
        channel: $channel,
        omarchy: (if $omarchy then { available: $omarchy.available } else null end),
        packages: ($items | length),
        plugins: $behind }'''
}

# /boot is small, and it is the one partition where running out stops the
# machine from booting the next kernel rather than merely inconveniencing
# someone. Below the threshold it is not mentioned at all.
overview_boot_space() {
  local line size used pct
  line=$(capture df -B1 --output=size,used,pcent /boot | tail -n1)
  read -r size used pct <<<"$line"
  [[ -n ${size:-} && ${size:-0} -gt 0 ]] || { echo 'null'; return; }
  pct=${pct%\%}
  (( ${pct:-0} >= 75 )) || { echo 'null'; return; }

  jq -cn --argjson pct "${pct:-0}" --argjson size "$size" --argjson used "$used" '''
    { kind: "boot",
      id: "boot",
      urgent: true,
      title: ("/boot is " + ($pct | tostring) + " % full"),
      note: "A kernel update may not fit.",
      action: "disk", actionLabel: "Open Disk" }'''
}

overview_state() {
  par_begin || { echo '{}'; return; }
  par_run toggles overview_toggles
  par_run attention overview_attention
  par_run updates overview_updates
  par_run news news_cached
  par_run dismissed overview_dismissed
  par_wait
  local toggles attention uptime updates news
  toggles=$(par_get toggles '[]')
  attention=$(par_get attention '[]')
  updates=$(par_get updates '{}')
  news=$(par_get news '{}')
  local dismissed
  dismissed=$(par_get dismissed '[]')
  par_end

  # Read here rather than taken off the Processes page: one line of /proc, and
  # the alternative was this page running two frames of `top` every half minute
  # to put a single figure in its header.
  uptime=$(cut -d. -f1 /proc/uptime 2>/dev/null)

  jq -cn \
    --argjson toggles "${toggles:-[]}" \
    --argjson attention "${attention:-[]}" \
    --argjson uptime "${uptime:-0}" \
    --argjson updates "${updates:-{\}}" \
    --argjson news "${news:-{\}}" \
    --argjson dismissed "${dismissed:-[]}" \
    '{ toggles: $toggles,
       attention: [ $attention[] | select((.id // "") as $id | $dismissed | index($id) == null) ],
       uptime: $uptime, updates: $updates, news: $news }'
}

overview_cmd() {
  case ${1:-state} in
    state|poll) overview_state ;;
    # The command that owns a switch is the one that flips it, side effects
    # and all: starting hyprsunset, telling the bar to redraw its indicator.
    toggle) shift
      case ${1:-} in
        nightlight) capture_err omarchy-toggle-nightlight ;;
        dnd) capture_err omarchy-toggle-notification-silencing ;;
        awake) capture_err omarchy-toggle-idle ;;
        dictation) setsid -f voxtype record toggle >/dev/null 2>&1 ;;
        *) die "usage: omacontrol overview toggle nightlight|dnd|awake|dictation" ;;
      esac ;;
    # Waving a notice away is remembered for a day, not for ever: the
    # condition that raised it is still true, and a reader who dismisses it
    # wants it gone now rather than never mentioned again.
    dismiss) shift; [[ -n ${1:-} ]] || die "usage: omacontrol overview dismiss <id>"
      overview_dismiss "$1" ;;
    *) die "usage: omacontrol overview state|poll|toggle <switch>|dismiss <id>" ;;
  esac
}

# ---------------------------------------------------------------- dismissals
#
# Kept in OmaControl's own store, beside everything else this window
# remembers. Stamped rather than flagged: a dismissal that never expires turns
# the page into one that quietly stops mentioning a full disk.
OVERVIEW_DISMISS_FOR=${OMACONTROL_DISMISS_FOR:-86400}

overview_dismiss() {
  note_store '.dismissed = ((.dismissed // {}) | .[$id] = $at)' \
    --arg id "$1" --argjson at "$(date +%s)"
}

overview_dismissed() {
  local now
  now=$(date +%s)
  read_store | jq -c --argjson now "$now" --argjson for "$OVERVIEW_DISMISS_FOR" \
    '[ (.dismissed // {}) | to_entries[] | select(($now - .value) < $for) | .key ]'
}
