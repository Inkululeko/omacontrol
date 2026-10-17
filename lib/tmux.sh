# Part of OmaControl. Sourced by bin/omacontrol; not run on its own.

# ---------------------------------------------------------------------- tmux

# tmux.conf is a script, not a settings file: the same option can be set more
# than once and the last one wins. So a value is replaced where it already
# stands, and appended only when the option is absent.
TMUX_CONFIG="${OMACONTROL_TMUX_CONFIG:-$HOME_DIR/.config/tmux/tmux.conf}"

# key, type, default, scope (server/window). tmux spells booleans on/off.
tmux_schema() {
  cat <<'SCHEMA'
prefix	string	C-b	server
mouse	bool	off	server
status-position	string	bottom	server
mode-keys	string	emacs	window
base-index	int	0	server
pane-base-index	int	0	window
history-limit	int	2000	server
escape-time	int	500	server
renumber-windows	bool	off	server
set-clipboard	string	external	server
SCHEMA
}

# The live server is the truth when one is running; the file is all there is
# otherwise. A value set by hand in a running session is what the user sees,
# so that is what this page should show.
tmux_read() {
  if tmux has-session 2>/dev/null; then
    {
      # Server options (-s) hold escape-time and set-clipboard; the global and
      # window tables hold the rest.
      tmux show-options -s 2>/dev/null
      tmux show-options -g 2>/dev/null
      tmux show-options -gw 2>/dev/null
    } | awk '{ key = $1; $1 = ""; sub(/^ /, ""); gsub(/^"|"$/, "", $0); printf "%s\t%s\n", key, $0 }'
  else
    [[ -f $TMUX_CONFIG ]] || return 0
    awk '
      function trim(v) { gsub(/^[ \t]+|[ \t]+$/, "", v); return v }
      # Quoted the way tmux_quote writes it, or by hand: single quotes keep
      # everything, double quotes let a backslash keep the next character.
      function unquote(v,   out, i, c) {
        if (length(v) >= 2 && v ~ /^\047.*\047$/) return substr(v, 2, length(v) - 2)
        if (length(v) < 2 || v !~ /^".*"$/) return v
        v = substr(v, 2, length(v) - 2)
        out = ""
        for (i = 1; i <= length(v); i++) {
          c = substr(v, i, 1)
          if (c == "\\" && i < length(v)) c = substr(v, ++i, 1)
          out = out c
        }
        return out
      }
      /^[ \t]*#/ { next }
      /^[ \t]*(set|setw|set-option|set-window-option)[ \t]/ {
        # Skip the flags (-g, -sg, -as, ...) to reach the option name.
        i = 2
        while (i <= NF && $i ~ /^-/) i++
        if (i > NF) next
        key = $i
        value = ""
        for (j = i + 1; j <= NF; j++) value = value (value == "" ? "" : " ") $j
        printf "%s\t%s\n", key, unquote(trim(value))
      }
    ' <(read_file "$TMUX_CONFIG")
  fi
}

tmux_state() {
  local present running installed
  # Asked, not assumed: Neovim and Herdr both report whether they are there,
  # and a page that claims tmux is installed when it is not offers settings
  # whose writes have nowhere to go.
  installed=$(command -v tmux >/dev/null 2>&1 && echo true || echo false)
  present=$(tmux_read | jq -R -s -c 'split("\n")
    | map(select(length > 0) | split("\t") | { key: .[0], value: (.[1] // "") })
    | from_entries')
  running=$(capture tmux has-session >/dev/null 2>&1 && echo true || echo false)

  tmux_schema | jq -R -s -c --argjson present "${present:-{\}}" --argjson running "$running" \
    --argjson installed "$installed" \
    --arg path "$TMUX_CONFIG" '
    def cast(v; t):
      if t == "bool" then (v == "on")
      elif t == "int" then (v | tonumber? // 0)
      else v end;
    { installed: $installed,
      running: $running,
      path: $path,
      values: (split("\n")
        | map(select(length > 0) | split("\t"))
        | map({ key: .[0], value: cast(($present[.[0]] // .[2]); .[1]) })
        | from_entries) }'
}

# A value as tmux.conf has to spell it. Bare when it can be, so a plain value
# is written as it always was; quoted otherwise, because the config is parsed
# like a shell line: a prefix of C-\ written bare ends in a line continuation
# and swallows the line below it, and the running server, set through argv,
# never shows the difference until tmux next starts.
tmux_quote() {
  local v=$1
  if [[ $v =~ ^[A-Za-z0-9_.,:+@%/=-][A-Za-z0-9_.,:+@%/=#-]*$ ]]; then
    printf '%s' "$v"
  elif [[ $v != *"'"* ]]; then
    printf "'%s'" "$v"
  else
    v=${v//\\/\\\\}
    v=${v//\"/\\\"}
    v=${v//\$/\\\$}
    printf '"%s"' "$v"
  fi
}

tmux_write() {
  local key=$1 raw=$2 type=$3 scope=$4 formatted

  case $type in
    bool)
      [[ $raw == true || $raw == false ]] || die "'$raw' is not true or false"
      [[ $raw == true ]] && formatted=on || formatted=off ;;
    int)
      [[ $raw =~ ^[0-9]+$ ]] || die "'$raw' is not a whole number"
      formatted=$raw ;;
    *)
      [[ -n $raw ]] || die "'$key' needs a value"
      formatted=$raw ;;
  esac

  ensure_regular_file "$TMUX_CONFIG" || die "$TMUX_CONFIG is not a file this can write"
  backup_once "$TMUX_CONFIG"

  local setter="set -g"
  [[ $scope == window ]] && setter="setw -g"

  # The line arrives through the environment: `awk -v` runs escape sequences,
  # and a value is not the place for them.
  OMACONTROL_LINE="$setter $key $(tmux_quote "$formatted")" awk -v key="$key" '
    BEGIN { replaced = 0; line = ENVIRON["OMACONTROL_LINE"] }
    {
      lines[NR] = $0
      if ($0 ~ /^[ \t]*(set|setw|set-option|set-window-option)[ \t]/ && $0 !~ /^[ \t]*#/) {
        i = 2
        while (i <= NF && $i ~ /^-/) i++
        if (i <= NF && $i == key) last = NR
      }
    }
    END {
      if (last) {
        # The last assignment is the one tmux honours, so that is the one to
        # rewrite; earlier ones stay as the record of what was tried.
        for (i = 1; i <= NR; i++) print (i == last ? line : lines[i])
      } else {
        for (i = 1; i <= NR; i++) print lines[i]
        print line
      }
    }
  ' <(read_file "$TMUX_CONFIG") | write_file "$TMUX_CONFIG" managed

  # A running server takes the change immediately; without one the file is
  # enough, since tmux reads it at start.
  if tmux has-session 2>/dev/null; then
    local flag="-g"
    [[ $scope == window ]] && flag="-gw"
    tmux set-option $flag "$key" "$formatted" >/dev/null 2>&1 \
      || die "tmux rejected $key = $formatted"
  fi
}
