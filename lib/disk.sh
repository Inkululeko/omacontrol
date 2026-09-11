# Part of OmaControl. Sourced by bin/omacontrol; not run on its own.
#
# What the disks are holding, and what they are doing about it. Nothing here
# writes: mounting and trimming are Omarchy's or the system's to do, and the
# page offers them as actions rather than as settings.
#
# None of this joins the state document. A state read happens after every
# write in the window, and `df` on a machine with a network mount is the one
# read that can take longer than everything else put together. The page polls
# instead, while it is the page on screen.

# Everything mounted that is a real filesystem on a real device, plus the
# partitions that are *not* mounted — a stick you have plugged in and not
# opened yet is the reason anyone comes to this page, and df cannot see it.
disk_mounts() {
  local mounted
  # lsblk answers both halves in one call and answers them about the same
  # objects, which df and /proc/mounts do not: df keys on the mount point and
  # loses the device, /proc/mounts lists every squashfs the snap layer made.
  # MOUNTPOINTS and not MOUNTPOINT: one btrfs filesystem is mounted at several
  # places at once — that is what a subvolume layout is — and the singular
  # field picks one of them arbitrarily, which is how the root filesystem came
  # to be listed as /var/log.
  mounted=$(capture lsblk --json --bytes \
    -o PATH,NAME,MOUNTPOINTS,FSTYPE,SIZE,FSUSED,FSAVAIL,LABEL,MODEL,TYPE,RM)
  [[ -n $mounted ]] || { echo '[]'; return; }

  # A partition, an LVM volume or a whole disk that is itself a filesystem.
  # Loop devices are the snap and appimage machinery and belong to nobody.
  emit_json "$(jq -c '''
    [ .blockdevices[]? | recurse(.children[]?)
      | select(.type == "part" or .type == "lvm" or .type == "crypt"
               or (.type == "disk" and (.fstype // "") != ""))
      | select((.fstype // "") as $fs
               | $fs != "" and ($fs | startswith("linux_raid")) == false
               and $fs != "swap" and ($fs | startswith("crypto_")) == false)
      # A row per place the filesystem is mounted, and one row with no mount
      # for a filesystem that is not mounted at all — a stick you have
      # plugged in and not opened yet is the reason anyone comes to this page.
      | . as $dev
      | (($dev.mountpoints // []) | map(select(. != null))) as $mounts
      | (if ($mounts | length) > 0 then $mounts[] else "" end) as $mount
      | { device: ($dev.name // ""),
          path: ($dev.path // ""),
          mount: $mount,
          label: ($dev.label // ""),
          model: ($dev.model // ""),
          fstype: ($dev.fstype // ""),
          removable: (($dev.rm // false) == true),
          size: ($dev.size // 0),
          used: ($dev.fsused // null),
          free: ($dev.fsavail // null),
          percent: (if ($dev.fsused // null) != null and ($dev.size // 0) > 0
                    then ((($dev.fsused | tonumber) / ($dev.size | tonumber)) * 100 | round)
                    else null end) } ]
    | sort_by(.mount == "", .mount)
  ''' <<<"$mounted" 2>/dev/null)" '[]'
}

# The drive the system is on, and how full it is. Cheap enough to poll: one
# df, one lsblk, no directory walking.
disk_summary() {
  local root_line size used free pct device model disk
  root_line=$(capture df -B1 --output=source,size,used,avail,pcent / | tail -n1)
  read -r device size used free pct <<<"$root_line"
  [[ -n ${size:-} ]] || { echo '{}'; return; }

  disk=$(disk_backing_device "$device")
  model=$(capture lsblk -dno MODEL "/dev/$disk" | head -n1)

  jq -cn \
    --argjson size "${size:-0}" --argjson used "${used:-0}" --argjson free "${free:-0}" \
    --arg device "$disk" --arg model "${model#"${model%%[![:space:]]*}"}" '''
    { size: $size, used: $used, free: $free,
      percent: (if $size > 0 then (($used / $size) * 100 | round) else 0 end),
      device: $device, model: ($model | sub("\\s+$"; "")) }'''
}

# What the used space divides into: the four questions anyone actually has —
# the system, the packages I have installed, my own files, and what the
# snapshots are holding — rather than a tree of every directory, which is a
# different tool.
#
# Its own subcommand, and not part of the poll, because the only way to answer
# it is to walk directories. The page asks once when it opens and leaves the
# answer on screen; a five-second `du` running every five seconds would be a
# window that spins a disk for as long as the reader looks at it.
#
# A walk that does not finish inside the read timeout reports null rather than
# what it had got to. A partial `du` is not a small number, it is a wrong one,
# and a slice of a chart cannot say "roughly".
disk_breakdown() {
  local used pkg home snapshots
  used=$(capture df -B1 --output=used / | tail -n1 | tr -dc '0-9')
  [[ -n ${used:-} ]] || { echo 'null'; return; }

  par_begin || { echo 'null'; return; }
  # The pacman cache is the one directory on an Omarchy machine that grows
  # without anyone asking it to, so it is worth naming on its own.
  par_run pkg du_bytes /var/cache/pacman/pkg
  # -x so a home with the media drive mounted under it does not count the
  # drive, which is on the next row of the mounts table under its own name.
  par_run home du_bytes "$HOME_DIR"
  par_run snapshots disk_snapshot_bytes
  par_wait
  pkg=$(par_get pkg null)
  home=$(par_get home null)
  snapshots=$(par_get snapshots null)
  par_end

  jq -cn \
    --argjson used "${used:-0}" \
    --argjson pkg "${pkg:-null}" \
    --argjson home "${home:-null}" \
    --argjson snapshots "${snapshots:-null}" '''
    # Only what was actually measured is subtracted, so a walk that timed out
    # makes the System slice larger rather than making it a lie.
    [$pkg, $home, $snapshots] as $named
    | ($named | map(select(. != null)) | add // 0) as $accounted
    | [ { label: "System", bytes: (($used - $accounted) | if . > 0 then . else 0 end) },
        { label: "Packages", bytes: $pkg },
        { label: "Home", bytes: $home },
        { label: "Snapshots", bytes: $snapshots } ]
      | map(select(.bytes != null))'''
}

# Bounded like every other read, and silent about a walk it could not finish.
du_bytes() {
  local out
  out=$(capture du -sbx "$1" | cut -f1 | tr -dc '0-9')
  [[ -n ${out:-} ]] && printf '%s' "$out" || printf 'null'
}

# The physical disk under a mount source, however many layers of dm-crypt,
# LVM and partitioning are in between.
disk_backing_device() {
  local disk
  disk=$(capture lsblk -nsro NAME,TYPE "$1" | awk '$2 == "disk" { print $1; exit }')
  [[ -n ${disk:-} ]] && printf '%s' "$disk" || basename "$1"
}

# Snapper is how Omarchy takes snapshots when the root is btrfs. A machine
# without it has no snapshots rather than an error.
disk_snapshot_bytes() {
  local used
  used=$(capture btrfs filesystem du -s --raw /.snapshots | awk 'NR==2 { print $2 }')
  printf '%s' "${used:-0}"
}

disk_snapshots() {
  command -v snapper >/dev/null 2>&1 || { echo '[]'; return; }
  emit_json "$(capture snapper --machine-readable csv list --columns number,type,date,description 2>/dev/null \
    | awk -F, 'NR > 1 && $1 != "" && $1 != "0" {
        desc = $4
        for (i = 5; i <= NF; i++) desc = desc "," $i
        printf "%s\t%s\t%s\t%s\n", $1, $2, $3, desc
      }' \
    | tail -n 12 \
    | jq -Rc -s '''
      [ split("\n")[] | select(length > 0) | split("\t")
        | { number: .[0], kind: .[1], date: .[2], description: (.[3] // "") } ]
      | reverse''' 2>/dev/null)" '[]'
}

# SMART, when the drive has it and smartctl can be run without a password.
# The page shows nothing rather than a row of dashes when it cannot: a health
# panel that is always empty teaches the reader to stop looking at it.
disk_health() {
  local device json
  device=$(disk_backing_device "$(findmnt -no SOURCE / 2>/dev/null)")
  [[ -n ${device:-} ]] || { echo '{}'; return; }
  command -v smartctl >/dev/null 2>&1 || { echo '{}'; return; }

  json=$(capture smartctl --json --health --attributes --info "/dev/$device")
  [[ -n $json ]] || { echo '{}'; return; }

  # Written bytes and wear are named differently on NVMe and on SATA, so both
  # spellings are tried and whichever answers is the one reported.
  emit_json "$(jq -c '''
    { passed: (.smart_status.passed // null),
      temperature: (.temperature.current // null),
      # NVMe reports the percentage already used; SATA reports what is left.
      wear: (.nvme_smart_health_information_log.percentage_used
             // (.ata_smart_attributes.table[]?
                 | select(.name == "Wear_Leveling_Count" or .name == "SSD_Life_Left")
                 | 100 - .value) // null),
      hours: (.power_on_time.hours // null),
      written: (if .nvme_smart_health_information_log.data_units_written
                then (.nvme_smart_health_information_log.data_units_written * 512000)
                else null end) }
  ''' <<<"$json" 2>/dev/null)" '{}'
}

disk_state() {
  par_begin || { echo '{}'; return; }
  par_run summary disk_summary
  par_run mounts disk_mounts
  par_run snapshots disk_snapshots
  par_run health disk_health
  par_wait

  local summary mounts snapshots health
  summary=$(par_get summary '{}')
  mounts=$(par_get mounts '[]')
  snapshots=$(par_get snapshots '[]')
  health=$(par_get health '{}')
  par_end

  jq -cn \
    --argjson summary "${summary:-{\}}" \
    --argjson mounts "${mounts:-[]}" \
    --argjson snapshots "${snapshots:-[]}" \
    --argjson health "${health:-{\}}" \
    '{ summary: $summary, mounts: $mounts, snapshots: $snapshots, health: $health }'
}

disk_cmd() {
  case ${1:-state} in
    state|poll) disk_state ;;
    breakdown) disk_breakdown ;;
    # Mounting is udisks' job. Doing it this way means the mount lands where
    # the file manager would have put it and is owned by the user who asked,
    # neither of which is true of a bare `mount`.
    mount) shift; [[ -n ${1:-} ]] || die "usage: omacontrol disk mount <device>"
      capture_err udisksctl mount -b "$1" ;;
    unmount) shift; [[ -n ${1:-} ]] || die "usage: omacontrol disk unmount <device>"
      capture_err udisksctl unmount -b "$1" ;;
    # Needs root, and `fstrim --all` without it is the worst kind of failure:
    # it skips every mount it may not touch, prints nothing and exits 0, so
    # the button looked like it worked and trimmed nothing. To a terminal with
    # a password prompt, like every other privileged job this window offers.
    trim) setsid -f omarchy-launch-floating-terminal-with-presentation \
      "sudo fstrim --all --verbose" >/dev/null 2>&1 ;;
    snapshot) capture_err omarchy-snapshot ;;
    open) shift; [[ -n ${1:-} ]] || die "usage: omacontrol disk open <path>"
      setsid -f xdg-open "$1" >/dev/null 2>&1 ;;
    *) die "usage: omacontrol disk state|poll|breakdown|mount <device>|unmount <device>|trim|snapshot|open <path>" ;;
  esac
}
