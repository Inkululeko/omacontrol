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

overview_dictation() {
  command -v voxtype >/dev/null 2>&1 || { echo '{"available":false}'; return; }
  echo '{"on":false,"note":"Hold to dictate"}'
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
  local boot
  boot=$(overview_boot_space)
  jq -cn --argjson boot "${boot:-null}" '[ $boot ] | map(select(. != null))'
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
      urgent: true,
      title: ("/boot is " + ($pct | tostring) + " % full"),
      note: "A kernel update may not fit.",
      action: "disk", actionLabel: "Open Disk" }'''
}

overview_state() {
  par_begin || { echo '{}'; return; }
  par_run toggles overview_toggles
  par_run attention overview_attention
  par_wait
  local toggles attention
  toggles=$(par_get toggles '[]')
  attention=$(par_get attention '[]')
  par_end

  jq -cn \
    --argjson toggles "${toggles:-[]}" \
    --argjson attention "${attention:-[]}" \
    '{ toggles: $toggles, attention: $attention }'
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
        dictation) setsid -f voxtype toggle >/dev/null 2>&1 ;;
        *) die "usage: omacontrol overview toggle nightlight|dnd|awake|dictation" ;;
      esac ;;
    reminder) setsid -f omarchy-reminder >/dev/null 2>&1 ;;
    record) setsid -f omarchy-capture-screenrecording >/dev/null 2>&1 ;;
    screenshot) setsid -f omarchy-capture-screenshot >/dev/null 2>&1 ;;
    *) die "usage: omacontrol overview state|poll|toggle <switch>|reminder|record|screenshot" ;;
  esac
}
