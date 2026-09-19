# Part of OmaControl. Sourced by bin/omacontrol; not run on its own.
#
# What the disks are holding, and what they are doing about it. Nothing here
# writes: mounting and snapshotting are Omarchy's or the system's to do, and
# the page offers them as actions rather than as settings.
#
# Trimming used to be one of them. `fstrim --all` needs privileges it does not
# have here and, given `--all`, skips what it may not touch without a word —
# so the button reported success and trimmed nothing. It belongs to
# `fstrim.timer`, which is the system's job and not a settings window's.
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
    -o PATH,NAME,MOUNTPOINTS,FSTYPE,SIZE,FSUSED,FSAVAIL,LABEL,MODEL,TYPE,RM,HOTPLUG)
  [[ -n $mounted ]] || { echo '[]'; return; }

  # A partition, an LVM volume or a whole disk that is itself a filesystem.
  # Loop devices are the snap and appimage machinery and belong to nobody.
  emit_json "$(jq -c '''
    [ .blockdevices[]?
      # Tagged with the drive it sits on while the tree still says so: a row
      # keyed only by its own name cannot be added up per drive afterwards,
      # and `root` says nothing about which disk it is a volume of.
      | . as $top
      | ($top.name // "") as $disk
      | ($top | recurse(.children[]?))
      | select(.type == "part" or .type == "lvm" or .type == "crypt"
               or (.type == "disk" and (.fstype // "") != ""))
      | select((.fstype // "") as $fs
               | $fs != "" and ($fs | startswith("linux_raid")) == false
               and $fs != "swap" and ($fs | startswith("crypto_")) == false)
      # One row per *filesystem*, carrying every place it is mounted.
      #
      # Not a row per mount point, which was the first version: a btrfs
      # subvolume layout mounts one filesystem in four places, and four rows
      # each reporting the whole 1 TB pool read as four drives that were
      # somehow all the same size and all 26 % full. They share one pool, so
      # they are one row and the figure is printed once.
      | . as $dev
      | (($dev.mountpoints // []) | map(select(. != null))
         # Shortest first, so the row is named by the mount anyone would call
         # it: `/` rather than whichever subvolume lsblk listed first.
         | sort_by(length)) as $mounts
      | { device: ($dev.name // ""),
          disk: $disk,
          path: ($dev.path // ""),
          mount: ($mounts[0] // ""),
          mounts: $mounts,
          label: ($dev.label // ""),
          model: ($dev.model // ""),
          fstype: ($dev.fstype // ""),
          # Whether the thing can be taken away, which is what decides
          # whether unmounting it is an offer worth making. `rm` is the old
          # removable bit — a card reader, an optical drive — and `hotplug`
          # is what a USB disk actually reports.
          removable: (($dev.rm // false) == true or ($dev.hotplug // false) == true),
          size: ($dev.size // 0),
          used: ($dev.fsused // null),
          free: ($dev.fsavail // null),
          percent: (if ($dev.fsused // null) != null and ($dev.size // 0) > 0
                    then ((($dev.fsused | tonumber) / ($dev.size | tonumber)) * 100 | round)
                    else null end) } ]
    | sort_by(.mount == "", .mount)
  ''' <<<"$mounted" 2>/dev/null)" '[]'
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

# Bounded like every other read, and silent about a walk it could not finish
# — but against the walk budget rather than the read one. On this machine a
# home directory of three million files takes 13 seconds warm and 47 cold.
du_bytes() {
  local out
  out=$(capture_for "$OMACONTROL_WALK_TIMEOUT" du -sbx "$1" | cut -f1 | tr -dc '0-9')
  [[ -n ${out:-} ]] && printf '%s' "$out" || printf 'null'
}

# The device the root filesystem is on.
#
# `findmnt` prints a btrfs subvolume as `/dev/mapper/root[/@]`, which is not a
# path anything else here can be asked about — every Omarchy install with
# snapshots is in that shape, so the suffix comes off before the answer is
# used.
disk_root_source() {
  local source
  source=$(findmnt -no SOURCE / 2>/dev/null)
  printf '%s' "${source%%[*}"
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
  used=$(capture_for "$OMACONTROL_WALK_TIMEOUT" btrfs filesystem du -s --raw /.snapshots \
    | awk 'NR==2 { print $2 }')
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
  device=$(disk_backing_device "$(disk_root_source)")
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

# Every drive in the machine, what it is and what it is doing.
#
# Per drive and not per machine: a laptop with an SSD for the system and a
# second disk for everything else is two answers to "is the disk busy", and
# summing them hides the one that is grinding behind the one that is idle.
#
# The figures come from `/proc/diskstats` and `lsblk`, so every machine
# answers — unlike the SMART panel, which needs the drive to keep those
# counters and `smartctl` to run without a password.
disk_drives() {
  local listing system first second t1 t2 rates encrypted tree
  listing=$(capture lsblk -dn --json --bytes -o NAME,PATH,MODEL,SIZE,TRAN,ROTA,RM,TYPE)
  [[ -n $listing ]] || { echo '[]'; return; }
  system=$(disk_backing_device "$(disk_root_source)")

  # One pair of samples for the whole machine rather than a pair per drive:
  # /proc/diskstats has every device in it and two reads answer for all of
  # them at once.
  #
  # Two reads and not one, for the same reason the CPU figure takes two: the
  # counters are totals since boot, so a single read gives the average since
  # the machine came up.
  first=$(cat /proc/diskstats 2>/dev/null)
  t1=$(date +%s%N)
  sleep 0.2
  second=$(cat /proc/diskstats 2>/dev/null)
  t2=$(date +%s%N)

  # The elapsed time is measured rather than assumed: `sleep 0.2` is a floor
  # and not a promise, and a busy machine that slept for half a second would
  # report every rate two and a half times too high.
  rates=$(awk -v t1="$t1" -v t2="$t2" '
    FNR == NR { r1[$3] = $6; w1[$3] = $10; b1[$3] = $13; next }
    {
      secs = (t2 - t1) / 1000000000
      if (secs <= 0) next
      if (!($3 in r1)) next
      busy = ($13 - b1[$3]) / (secs * 1000) * 100
      if (busy < 0) busy = 0
      if (busy > 100) busy = 100
      # /proc/diskstats counts in 512-byte units whatever the drive sector
      # size is; the kernel normalises it.
      printf "%s %.0f %.0f %.0f %.0f %.0f\n", $3,
        ($6 - r1[$3]) * 512 / secs, ($10 - w1[$3]) * 512 / secs, busy,
        $6 * 512, $10 * 512
    }' <(printf '%s\n' "$first") <(printf '%s\n' "$second") \
    | jq -Rc -s '
      [ split("\n")[] | select(length > 0) | split(" ")
        | { name: .[0], read: (.[1] | tonumber), write: (.[2] | tonumber),
            busy: (.[3] | tonumber), readTotal: (.[4] | tonumber),
            writeTotal: (.[5] | tonumber) } ]
      | INDEX(.name)' 2>/dev/null)

  # Encryption is a layer under the filesystem rather than a property of it,
  # so the only general way to answer "is this drive encrypted" is to look for
  # a `crypt` among the things sitting on it.
  #
  # One call for the whole tree rather than one per drive: this runs on the
  # page's five-second poll, and a question asked per drive is a question
  # asked again every time someone plugs one in.
  tree=$(capture lsblk --json -o NAME,TYPE)
  encrypted=$(emit_json "$(jq -c '
    [ .blockdevices[]? | select(.type == "disk")
      | { (.name): ([recurse(.children[]?) | .type] | any(. == "crypt")) } ]
    | add // {}' <<<"$tree" 2>/dev/null)" '{}')

  emit_json "$(jq -c \
    --argjson rates "${rates:-{\}}" \
    --argjson encrypted "$encrypted" \
    --arg system "$system" '
    [ .blockdevices[]?
      | select(.type == "disk")
      # zram is compressed memory and a loop device is the snap and appimage
      # machinery; both are listed as disks and neither is one.
      | select((.name | test("^(zram|loop|ram)")) == false)
      | select((.size // 0) > 0)
      | . as $d
      | ($rates[$d.name] // {}) as $r
      | { device: $d.name,
          path: ($d.path // ""),
          model: (($d.model // "") | sub("\\s+$"; "")),
          size: ($d.size // 0),
          transport: ($d.tran // ""),
          rotational: ($d.rota == true),
          removable: ($d.rm == true),
          encrypted: ($encrypted[$d.name] == true),
          system: ($d.name == $system),
          read: ($r.read // null), write: ($r.write // null),
          busy: ($r.busy // null),
          readTotal: ($r.readTotal // null),
          writeTotal: ($r.writeTotal // null) } ]
    # The drive the system is on first: it is the one the page is about, and
    # on most machines it is the only one.
    | sort_by(.system == false, .device)' <<<"$listing" 2>/dev/null)" '[]'
}

# The root filesystem itself, which belongs to no one drive.
disk_root() {
  local options
  # A root filesystem that has dropped to read-only is a drive in the middle
  # of failing, and nothing else in this window would say so.
  options=$(findmnt -no OPTIONS / 2>/dev/null)
  jq -cn \
    --arg fstype "$(findmnt -no FSTYPE / 2>/dev/null)" \
    --argjson readonly "$(grep -qE '(^|,)ro(,|$)' <<<"${options:-}" && echo true || echo false)" \
    '{ fstype: $fstype, readonly: $readonly }'
}

# Swap is disk space on most machines and compressed memory on a machine with
# zram, and the page has to be able to say which: a 32 GB swap file is 32 GB
# of the bar at the top of the page, and zram is not on the drive at all.
disk_swap() {
  emit_json "$(awk 'NR > 1 && NF >= 4 { printf "%s\t%s\t%s\t%s\n", $1, $2, $3, $4 }' /proc/swaps \
    | jq -Rc -s '''
      [ split("\n")[] | select(length > 0) | split("\t")
        | { name: .[0],
            kind: .[1],
            # /proc/swaps counts in kibibytes; everything the window formats
            # is bytes.
            size: ((.[2] | tonumber) * 1024),
            used: ((.[3] | tonumber) * 1024),
            zram: (.[0] | test("zram")) } ]''' 2>/dev/null)" '[]'
}

disk_state() {
  par_begin || { echo '{}'; return; }
  par_run mounts disk_mounts
  par_run snapshots disk_snapshots
  par_run health disk_health
  par_run drives disk_drives
  par_run root disk_root
  par_run swap disk_swap
  par_wait

  local mounts snapshots health drives root swap
  mounts=$(par_get mounts '[]')
  snapshots=$(par_get snapshots '[]')
  health=$(par_get health '{}')
  drives=$(par_get drives '[]')
  root=$(par_get root '{}')
  swap=$(par_get swap '[]')
  par_end

  jq -cn \
    --argjson mounts "${mounts:-[]}" \
    --argjson snapshots "${snapshots:-[]}" \
    --argjson health "${health:-{\}}" \
    --argjson drives "${drives:-[]}" \
    --argjson root "${root:-{\}}" \
    --argjson swap "${swap:-[]}" \
    '{ mounts: $mounts, snapshots: $snapshots, health: $health,
       drives: $drives, root: $root, swap: $swap }'
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
    snapshot) capture_err omarchy-snapshot ;;
    open) shift; [[ -n ${1:-} ]] || die "usage: omacontrol disk open <path>"
      setsid -f xdg-open "$1" >/dev/null 2>&1 ;;
    *) die "usage: omacontrol disk state|poll|breakdown|mount <device>|unmount <device>|snapshot|open <path>" ;;
  esac
}
