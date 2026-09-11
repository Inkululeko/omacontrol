# Part of OmaControl. Sourced by bin/omacontrol; not run on its own.
#
# Bluetooth, driven through Omarchy's own wrappers rather than bluetoothctl:
# powering an adapter means clearing an rfkill soft block (bluetoothctl alone
# forgets across reboots), and connecting a device means trusting it first.
# omarchy-bluetooth-power and omarchy-bluetooth-device already know that.

# `bluetoothctl devices [Paired|Connected]` prints "Device <mac> <name>".
#
# It colours some of those lines and not others — a device it holds but has
# not bonded comes back wrapped in grey — and the escape sequence lands in
# the first field, so a match on "Device" silently dropped exactly those
# devices from every list, connected ones included. Strip the colour before
# reading the line; a `[CHG]` event line arriving mid-listing still fails the
# match, which is what should happen to it.
bt_addresses() {
  capture bluetoothctl devices ${1:+"$1"} \
    | awk '{ gsub(/\033\[[0-9;]*m/, "") }
           $1 == "Device" { address = $2; $1 = ""; $2 = ""; sub(/^  /, ""); print address "\t" $0 }'
}

# Kind and battery come from a per-device lookup, which is only worth doing
# for devices you own: a scan can leave dozens of addresses behind, and none
# of them has either.
bt_details() {
  local address=$1
  capture bluetoothctl info "$address" | awk -F': ' '
    /^\tIcon:/ { icon = $2 }
    /Battery Percentage:/ { match($0, /\(([0-9]+)\)/, m); battery = m[1] }
    END { printf "%s\t%s\n", icon, battery }
  '
}

# RSSI is only reported for a device the adapter is currently hearing, and it
# is the only thing that tells one unnamed address in the Nearby list from
# another. `bluetoothctl info` would give it, but only one device per call —
# dozens of them after a scan in a busy room. BlueZ's object manager answers
# for every device at once, so this stays one process however many there are.
bt_rssi() {
  command -v busctl >/dev/null 2>&1 || { echo '{}'; return; }
  local objects
  objects=$(capture busctl --json=short call org.bluez / \
    org.freedesktop.DBus.ObjectManager GetManagedObjects)
  emit_json "$(jq -c '[.data[0] | to_entries[] | .value["org.bluez.Device1"] // empty
                       | select(.RSSI != null and .Address != null)
                       | { key: .Address.data, value: .RSSI.data }] | from_entries' <<<"$objects")" '{}'
}

bluetooth_state() {
  local powered devices paired connected discoverable adapter rssi

  command -v bluetoothctl >/dev/null 2>&1 || { echo '{"available": false, "powered": false, "devices": []}'; return; }
  powered=$(capture omarchy-bluetooth-power is-on >/dev/null 2>&1 && echo true || echo false)

  # The name and the switch that decide whether pairing can start from the
  # other device, which is the half of pairing this window cannot drive.
  local show
  show=$(capture bluetoothctl show)
  discoverable=$(grep -q "Discoverable: yes" <<<"$show" && echo true || echo false)
  adapter=$(awk -F': ' '/^\tAlias:/ { print $2; exit }' <<<"$show")
  rssi=$(bt_rssi)

  # Three list calls rather than one info call per device: a scan can leave
  # dozens of addresses behind, and the flags are all that most rows need.
  devices=$(bt_addresses | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t") | { address: .[0], name: (.[1] // "") })')
  paired=$(bt_addresses Paired | cut -f1 | jq -R -s -c 'split("\n") | map(select(length > 0))')
  connected=$(bt_addresses Connected | cut -f1 | jq -R -s -c 'split("\n") | map(select(length > 0))')

  local enriched='[]' address icon battery
  while read -r address; do
    [[ -n $address ]] || continue
    IFS=$'\t' read -r icon battery < <(bt_details "$address")
    enriched=$(jq -c --arg address "$address" --arg icon "${icon:-}" --arg battery "${battery:-}" \
      '. + [{ address: $address, icon: $icon, battery: (($battery | tonumber?) // null) }]' <<<"$enriched")
  done < <(jq -r -s 'add | unique | .[]' <<<"${paired:-[]} ${connected:-[]}")

  jq -cn --argjson powered "$powered" \
    --argjson discoverable "$discoverable" \
    --arg adapter "${adapter:-}" \
    --argjson rssi "${rssi:-{\}}" \
    --argjson devices "${devices:-[]}" \
    --argjson paired "${paired:-[]}" \
    --argjson connected "${connected:-[]}" \
    --argjson enriched "${enriched:-[]}" \
    '($enriched | map({ key: .address, value: . }) | from_entries) as $extra
     | { available: true,
         powered: $powered,
         discoverable: $discoverable,
         adapter: $adapter,
         devices: ([$devices[] | . as $device
           | { address: $device.address,
               # An unnamed device shows its address; a name that is just the
               # address with dashes is the same non-answer, so it is dropped.
               name: (if $device.name == "" or ($device.name | gsub("-"; ":") | ascii_upcase) == ($device.address | ascii_upcase)
                      then "" else $device.name end),
               paired: (($paired | index($device.address)) != null),
               connected: (($connected | index($device.address)) != null),
               icon: (($extra[$device.address].icon) // ""),
               battery: (($extra[$device.address].battery) // null),
               rssi: (($rssi[$device.address]) // null) }]
           # Connected first, then paired, then whatever the scan turned up,
           # each group alphabetical: the device you want is nearly always one
           # you already own.
           # Nearby is sorted by how close the thing is rather than by name:
           # half of what a scan turns up has no name, and the one you are
           # holding is the loudest.
           | sort_by([(if .connected then 0 elif .paired then 1 else 2 end),
                      (if .paired or .connected then 0 else -(.rssi // -200) end),
                      (.name | ascii_downcase)])) }'
}

bluetooth_cmd() {
  local action=${1:-} address=${2:-}
  command -v bluetoothctl >/dev/null 2>&1 || die "bluetoothctl is not available"

  case $action in
    state) bluetooth_state ;;
    power)
      case $address in
        on|off|toggle) omarchy-bluetooth-power "$address" >/dev/null 2>&1 || die "could not turn Bluetooth $address" ;;
        *) die "expected on, off or toggle" ;;
      esac ;;
    discoverable)
      case $address in
        on|off)
          # BlueZ turns it off again by itself after its own timeout, which is
          # what makes this safe to leave switched on by mistake.
          capture bluetoothctl discoverable "$address" >/dev/null 2>&1 \
            || die "could not make this computer $([[ $address == on ]] && echo discoverable || echo hidden)" ;;
        *) die "expected on or off" ;;
      esac ;;
    scan)
      # A scan has to run for a while to find anything; bluetoothctl's own
      # timeout ends it, and the state that follows includes what it found.
      timeout 20 bluetoothctl --timeout 12 scan on >/dev/null 2>&1 || true
      bluetooth_state ;;
    poll)
      # For the page's own refresh loop. Discovery is a mode the adapter has
      # to be left in, not a one-shot, so this keeps one running and returns
      # what is known right now. The timeout means that when the page stops
      # polling, discovery stops by itself shortly after.
      if [[ $(capture omarchy-bluetooth-power is-on >/dev/null 2>&1 && echo on) == on ]] \
        && ! capture bluetoothctl show | grep -q "Discovering: yes"; then
        setsid bluetoothctl --timeout 30 scan on >/dev/null 2>&1 &
        disown 2>/dev/null || true
      fi
      bluetooth_state ;;
    pair|connect|disconnect|forget)
      [[ $address =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] || die "'$address' is not a device address"
      local output
      output=$(timeout 45 omarchy-bluetooth-device "$action" "$address" 2>&1) \
        || die "could not $action that device${output:+: $output}" ;;
    *) die "unknown bluetooth action '$action'" ;;
  esac
}
