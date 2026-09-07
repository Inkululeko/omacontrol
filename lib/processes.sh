# Part of OmaControl. Sourced by bin/omacontrol; not run on its own.
#
# What the machine is busy with. Read-only apart from the two things anyone
# opens a process list to do: end something, or push it out of the way.
#
# Like the Disk page, none of this joins the state document — it is true for
# about a second, and the page polls it while it is on screen.

# Overall CPU, from two samples of /proc/stat rather than one.
#
# One sample cannot answer "how busy is it now": the counters in /proc/stat
# are totals since boot, so a single read gives the average since the machine
# came up, which on a six-day uptime is a number that never moves. The delta
# between two reads a fifth of a second apart is what the reader means.
processes_cpu() {
  local idle1 total1 idle2 total2
  read -r idle1 total1 < <(processes_cpu_sample)
  sleep 0.2
  read -r idle2 total2 < <(processes_cpu_sample)

  awk -v i1="$idle1" -v t1="$total1" -v i2="$idle2" -v t2="$total2" '
    BEGIN {
      dt = t2 - t1
      di = i2 - i1
      if (dt <= 0) { print "null"; exit }
      pct = (1 - di / dt) * 100
      if (pct < 0) pct = 0
      if (pct > 100) pct = 100
      printf "%.0f\n", pct
    }'
}

processes_cpu_sample() {
  awk 'NR == 1 { idle = $5 + $6; total = 0; for (i = 2; i <= NF; i++) total += $i
                 print idle, total; exit }' /proc/stat
}

# Per-core, for the row of bars the page draws beside the figure. Same two
# samples, one line per core.
processes_cores() {
  local first second
  first=$(awk '/^cpu[0-9]/ { idle = $5 + $6; total = 0
                             for (i = 2; i <= NF; i++) total += $i
                             print $1, idle, total }' /proc/stat)
  sleep 0.2
  second=$(awk '/^cpu[0-9]/ { idle = $5 + $6; total = 0
                              for (i = 2; i <= NF; i++) total += $i
                              print $1, idle, total }' /proc/stat)

  emit_json "$(awk '
    NR == FNR { idle[$1] = $2; total[$1] = $3; next }
    {
      dt = $3 - total[$1]
      di = $2 - idle[$1]
      pct = (dt > 0) ? (1 - di / dt) * 100 : 0
      if (pct < 0) pct = 0
      if (pct > 100) pct = 100
      printf "%.0f\n", pct
    }' <(printf '%s\n' "$first") <(printf '%s\n' "$second") \
    | jq -Rc -s '[ split("\n")[] | select(length > 0) | tonumber ]')" '[]'
}

processes_memory() {
  awk '
    /^MemTotal:/ { total = $2 }
    /^MemAvailable:/ { avail = $2 }
    /^SwapTotal:/ { swaptotal = $2 }
    /^SwapFree:/ { swapfree = $2 }
    END {
      if (total <= 0) { print "{}"; exit }
      # /proc/meminfo is in kibibytes; everything the window formats is bytes.
      printf "{\"total\":%d,\"used\":%d,\"swap\":%d,\"swapTotal\":%d,\"percent\":%.0f}\n",
        total * 1024, (total - avail) * 1024, (swaptotal - swapfree) * 1024,
        swaptotal * 1024, ((total - avail) / total) * 100
    }' /proc/meminfo
}

processes_load() {
  local cores
  cores=$(nproc 2>/dev/null || echo 1)
  awk -v cores="$cores" -v uptime="$(cut -d. -f1 /proc/uptime)" '
    { printf "{\"one\":%s,\"five\":%s,\"fifteen\":%s,\"processes\":%s,\"cores\":%s,\"uptime\":%s}\n",
        $1, $2, $3, substr($4, index($4, "/") + 1), cores, uptime }' /proc/loadavg
}

# The processes worth naming, by whichever column the reader is sorting on.
#
# `top` and not `ps` for the CPU figure. ps reports the average over a
# process's whole life, so a browser that pinned a core an hour ago outranks
# the one doing it right now, which is the opposite of what the page is for.
# top's second frame is measured against its first, so it is the CPU of the
# moment; the first frame is ps's number and is thrown away.
processes_top() {
  local sort=${1:-cpu} rows
  rows=$(capture top -b -n 2 -d 0.2 -w 512 \
    | awk 'BEGIN { frame = 0 }
           /^ *PID/ { frame++; next }
           frame == 2 && NF >= 12 {
             cmd = $12
             for (i = 13; i <= NF; i++) cmd = cmd " " $i
             printf "%s\t%s\t%s\t%s\t%s\n", $1, cmd, $9, $6, $11
           }')
  [[ -n $rows ]] || { echo '[]'; return; }

  # RES is in kibibytes unless top has suffixed it, which it does past a
  # gibibyte. Whatever it says is turned back into bytes here so the window
  # has one unit to format.
  emit_json "$(jq -Rc -s --arg sort "$sort" '''
    def bytes:
      capture("^(?<n>[0-9.,]+)(?<unit>[a-zA-Z]?)$")
      | ((.n | gsub(","; ".") | tonumber)
         * ({ "": 1024, "k": 1024, "m": 1048576, "g": 1073741824,
              "t": 1099511627776, "p": 1125899906842624 }[.unit | ascii_downcase] // 1024))
      | round;

    [ split("\n")[] | select(length > 0) | split("\t")
      | { pid: .[0],
          command: .[1],
          cpu: (.[2] | gsub(","; ".") | tonumber? // 0),
          memory: (.[3] | bytes? // 0),
          time: .[4] } ]
    | if $sort == "memory" then sort_by(-.memory)
      elif $sort == "name" then sort_by(.command | ascii_downcase)
      else sort_by(-.cpu) end
    | .[0:40]''' <<<"$rows" 2>/dev/null)" '[]'
}

processes_state() {
  local sort=${1:-cpu}
  par_begin || { echo '{}'; return; }
  # The CPU and core samples each want a fifth of a second of wall clock, and
  # top wants its two frames; run together, the whole page costs the longest
  # of them rather than the sum.
  par_run cpu processes_cpu
  par_run cores processes_cores
  par_run memory processes_memory
  par_run load processes_load
  par_run top processes_top "$sort"
  par_run temp processes_temperature
  par_wait

  local cpu cores memory load top temp
  cpu=$(par_get cpu null)
  cores=$(par_get cores '[]')
  memory=$(par_get memory '{}')
  load=$(par_get load '{}')
  top=$(par_get top '[]')
  temp=$(par_get temp null)
  par_end

  jq -cn \
    --argjson cpu "${cpu:-null}" \
    --argjson cores "${cores:-[]}" \
    --argjson memory "${memory:-{\}}" \
    --argjson load "${load:-{\}}" \
    --argjson processes "${top:-[]}" \
    --argjson temperature "${temp:-null}" \
    --arg sort "$sort" \
    '{ cpu: $cpu, cores: $cores, memory: $memory, load: $load,
       processes: $processes, temperature: $temperature, sort: $sort }'
}

# Whatever the machine is willing to call the CPU's temperature. Nothing at all
# on a machine with no such sensor, which the page renders as nothing rather
# than as zero degrees.
processes_temperature() {
  local degrees
  degrees=$(capture sensors -j 2>/dev/null \
    | jq -r '[ to_entries[] | select(.key | test("coretemp|k10temp|zenpower"))
               | .value | to_entries[] | select(.key | test("Package|Tctl|Tdie"))
               | .value | to_entries[] | select(.key | endswith("_input")) | .value ]
             | first // empty' 2>/dev/null)
  [[ -n ${degrees:-} ]] && printf '%.0f' "$degrees" || printf 'null'
}

processes_cmd() {
  case ${1:-state} in
    state|poll) shift; processes_state "${1:-cpu}" ;;
    # TERM and not KILL: a process asked to stop can save what it was doing,
    # and a settings window is not the place that decides it may not.
    end) shift; [[ -n ${1:-} ]] || die "usage: omacontrol processes end <pid>"
      kill -TERM "$1" 2>/dev/null || die "could not end $1" ;;
    kill) shift; [[ -n ${1:-} ]] || die "usage: omacontrol processes kill <pid>"
      kill -KILL "$1" 2>/dev/null || die "could not kill $1" ;;
    renice) shift; [[ -n ${1:-} && -n ${2:-} ]] || die "usage: omacontrol processes renice <pid> <nice>"
      renice -n "$2" -p "$1" >/dev/null 2>&1 || die "could not renice $1" ;;
    btop) setsid -f omarchy-launch-tui btop >/dev/null 2>&1 ;;
    *) die "usage: omacontrol processes state|poll [cpu|memory|name]|end <pid>|kill <pid>|renice <pid> <nice>|btop" ;;
  esac
}
