# Part of OmaControl. Sourced by bin/omacontrol; not run on its own.
#
# /etc/hosts: read for the Network page, and handed to the reader's own editor
# to change. It is root's, it is hand-written, and an ad-blocking list makes
# it a hundred thousand lines, so nothing here ever writes it.

OMACONTROL_HOSTS=${OMACONTROL_HOSTS:-/etc/hosts}

# A list that size is not a table anyone reads, and the window holds whatever
# this prints for as long as the bar runs.
HOSTS_SHOWN_MAX=200

# The names every machine has. Shown on every machine, they would be the whole
# table on most of them and say nothing; what is worth seeing is what someone
# added.
hosts_list() {
  if [[ ! -r $OMACONTROL_HOSTS ]]; then
    jq -cn '{ readable: false, entries: [], total: 0 }'
    return
  fi
  local host
  host=$(cat /proc/sys/kernel/hostname 2>/dev/null)
  # The hostname through the environment, as the kernel holds it: `awk -v`
  # would run escape sequences in it.
  OMACONTROL_HOST=$host awk -v max="$HOSTS_SHOWN_MAX" '
    BEGIN {
      host = ENVIRON["OMACONTROL_HOST"]
      split("localhost localhost.localdomain ip6-localhost ip6-loopback ip6-localnet ip6-mcastprefix ip6-allnodes ip6-allrouters ip6-allhosts", d, " ")
      for (i in d) usual[d[i]] = 1
      if (host != "") { usual[host] = 1; usual[host ".localdomain"] = 1 }
    }
    {
      sub(/#.*/, "")
      if (NF < 2) next
      # A name per entry, not a line: a line can carry a dozen, and the name is
      # what anyone looking at this list is looking for.
      for (i = 2; i <= NF; i++) {
        if (tolower($i) in usual) continue
        total++
        if (total <= max) printf "%s\t%s\n", $1, $i
      }
    }
    END { printf "#total\t%d\n", total + 0 }' "$OMACONTROL_HOSTS" \
  | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t"))
      | { readable: true,
          total: (map(select(.[0] == "#total"))[0][1] | tonumber? // 0),
          entries: [ .[] | select(.[0] != "#total") | { address: .[0], name: .[1] } ] }'
}

# sudoedit rather than an editor run as root: the editor runs as the reader,
# on a copy, with their own config and plugins, and only the save goes back as
# root. It waits for the editor to exit and then copies the file back, so a
# GUI editor that hands off to a running window and returns at once would be
# saved before anything was typed — and the edit would be lost without a word.
# Each of Omarchy's GUI choices is told to wait; anything this does not know
# goes to Neovim, as omarchy-launch-editor does with an editor it cannot find.
hosts_edit() {
  local editor
  editor=$(capture omarchy-default-editor | head -n1)
  [[ -n $editor ]] && command -v "$editor" >/dev/null 2>&1 || editor=nvim
  case ${editor##*/} in
    code | cursor | zeditor | zed | sublime_text | subl) editor="$editor --wait" ;;
    nvim | vim | helix | hx | emacs | nano | micro) ;;
    *) editor=nvim ;;
  esac
  # A terminal, whatever the editor: sudo has to ask for the password
  # somewhere the reader can answer it.
  setsid omarchy-launch-floating-terminal-with-presentation \
    "SUDO_EDITOR=$(printf '%q' "$editor") sudoedit $(printf '%q' "$OMACONTROL_HOSTS")" \
    >/dev/null 2>&1 &
  disown 2>/dev/null || true
}

hosts_cmd() {
  local action=${1:-}
  case $action in
    list) hosts_list ;;
    edit) hosts_edit ;;
    *) die "unknown hosts action '$action'" ;;
  esac
}
