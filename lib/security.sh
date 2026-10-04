# Part of OmaControl. Sourced by bin/omacontrol; not run on its own.
#
# What can reach this machine, and how you sign in to it. Every line is a
# reading. The firewall is never written from here: changing it takes root,
# and Omarchy has no command of its own for it to relay. Setting up a way to
# sign in edits PAM, so that is Omarchy's own setup and remove scripts, run
# through the menu exactly as the menu runs them.

SECURITY_UFW_CONF=/etc/ufw/ufw.conf
SECURITY_UFW_DEFAULTS=/etc/default/ufw
SECURITY_UFW_RULES=(/etc/ufw/user.rules /etc/ufw/user6.rules)
SECURITY_PAM_SUDO=/etc/pam.d/sudo
SECURITY_UFW_AFTER=/etc/ufw/after.rules
SECURITY_SSHD_CONFIG=/etc/ssh/sshd_config

# `ufw status` needs root. The rules it reports are kept in these files, which
# are world-readable, one `### tuple ###` comment per rule in a fixed order:
# action, protocol, port, destination, source port, source, then the app
# names when the rule was made from an application profile, the direction
# (with the interface after an underscore), and the comment hex-encoded.
security_rule_lines() {
  local file
  for file in "${SECURITY_UFW_RULES[@]}"; do
    [[ -r $file ]] && grep -h '^### tuple ### ' "$file"
  done | awk '{
    sub(/^### tuple ### /, "")
    n = split($0, f, " ")
    comment = ""
    if (f[n] ~ /^comment=/) { comment = substr(f[n], 9); n-- }
    app = (n > 7) ? f[7] : ""
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", f[1], f[2], f[3], f[4], f[6], f[n], (app == "-" ? "" : app), comment
  }'
}

security_rules() {
  security_rule_lines | jq -R -s -c '
    def unhex: explode
      | map(if . >= 97 then . - 87 elif . >= 65 then . - 55 else . - 48 end)
      | [range(0; length; 2) as $i | .[$i] * 16 + .[$i + 1]] | implode;
    def anywhere: if . == "0.0.0.0/0" or . == "::/0" then "any" else . end;
    split("\n") | map(select(length > 0) | split("\t")
      | { action: .[0], proto: .[1], port: .[2], to: (.[3] | anywhere),
          from: (.[4] | anywhere), direction: .[5],
          # ufw stores a profile name with its spaces as %20.
          app: (.[6] | gsub("%20"; " ")),
          comment: (if .[7] == "" then "" else (.[7] | unhex) end) })
    # A route rule is ufw-docker opening a container: Docker forwards the
    # published port on this machine to it, so it is a door here too.
    | map(.container = (.action | startswith("route:"))
          | .action |= (ltrimstr("route:") | split("_")[0])
          # `in_tailscale0` is a rule for one network, not for everyone.
          | .interface = (.direction | split("!")[0] | if startswith("in_") then .[3:] else "" end))
    # Only the doors: allowed, coming in. `limit` is allow with a brake on it.
    | map(select(.action == "allow" or .action == "limit")
          | select(.container or (.direction | startswith("in"))))
    # ufw writes one rule per address family; the reader opened one port.
    | unique_by([.action, .proto, .port, .to, .from, .app, .interface, .container])'
}

# What is listening, and on which address. A program bound to the loopback
# address answers only this machine, so a rule in front of it opens nothing.
#
# `ss -p` names the process only for this user's own sockets. `-e` adds the
# owner and the cgroup, and the cgroup names a system service's unit without
# root — systemd-resolved, avahi-daemon, docker — so the only socket left
# unnamed is one in no unit at all. On a machine with more than one person on
# it, another user's program is theirs, not a system service.
security_listeners() {
  capture ss -Htulnpe | awk -v me="$(id -u)" '{
    local = $5
    i = match(local, /:[^:]*$/)
    addr = substr(local, 1, i - 1); port = substr(local, i + 1)
    loop = (addr ~ /^127\./ || addr == "[::1]" || addr ~ /%lo$/) ? "true" : "false"
    sub(/%.*$/, "", addr); gsub(/[\[\]]/, "", addr)
    name = ""
    if (match($0, /users:\(\("[^"]+"/)) name = substr($0, RSTART + 9, RLENGTH - 10)
    # ss leaves the uid out for root.
    uid = 0
    if (match($0, /uid:[0-9]+/)) uid = substr($0, RSTART + 4, RLENGTH - 4) + 0
    owner = (uid == me) ? "mine" : (uid < 1000 ? "system" : "other")
    unit = ""
    if (match($0, /cgroup:[^ ]+/)) {
      n = split(substr($0, RSTART + 7, RLENGTH - 7), part, "/")
      if (part[n] ~ /\.service$/) { unit = part[n]; sub(/\.service$/, "", unit) }
    }
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, port, loop, name, addr, owner, unit
  }' | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t")
      | { proto: .[0], port: (.[1] | tonumber? // null), loopback: (.[2] == "true"), name: .[3],
          anyAddress: (.[4] == "0.0.0.0" or .[4] == "*" or .[4] == "::"), address: .[4],
          owner: .[5], service: (if .[5] == "system" then .[6] else "" end) })
    | map(select(.port != null))'
}

security_firewall() {
  local installed=false enabled=false incoming="" readable=false file
  command -v ufw >/dev/null 2>&1 && installed=true
  # Unreadable rules would otherwise read as no rules, which is the one
  # answer a page about open ports must not give by accident.
  for file in "${SECURITY_UFW_RULES[@]}"; do [[ -r $file ]] && readable=true; done
  # Both, because either alone has been wrong: ENABLED=yes with the unit
  # stopped is a firewall that comes back at boot and is not up now.
  if [[ $installed == true ]] && grep -qx 'ENABLED=yes' "$SECURITY_UFW_CONF" 2>/dev/null \
     && [[ $(capture systemctl is-active ufw) == active ]]; then
    enabled=true
  fi
  # Someone running firewalld or plain nftables has a firewall; ufw being off
  # on their machine says nothing about it. Its rules need root to read, so
  # the page can name it and no more.
  local other="" unit
  if [[ $enabled == false ]]; then
    for unit in firewalld nftables iptables; do
      [[ $(capture systemctl is-active "$unit") == active ]] && { other=$unit; break; }
    done
  fi
  # Docker publishes ports with rules of its own, ahead of ufw's. ufw-docker's
  # block in after.rules is what puts them back behind the firewall; without
  # it a published port is open to the network whatever ufw lists.
  local docker_open=false
  if command -v docker >/dev/null 2>&1 && [[ -r $SECURITY_UFW_AFTER ]] \
     && ! grep -q 'BEGIN UFW AND DOCKER' "$SECURITY_UFW_AFTER"; then
    docker_open=true
  fi
  incoming=$(sed -n 's/^DEFAULT_INPUT_POLICY="\{0,1\}\([A-Z]*\)"\{0,1\}$/\1/p' "$SECURITY_UFW_DEFAULTS" 2>/dev/null | head -n1)
  jq -cn --argjson installed "$installed" --argjson enabled "$enabled" --arg incoming "$incoming" \
    --argjson readable "$readable" --arg other "$other" --argjson dockerOpen "$docker_open" \
    '{ installed: $installed, enabled: $enabled, incoming: $incoming, rulesReadable: $readable,
       otherFirewall: $other, dockerOpen: $dockerOpen }'
}

# The menu's own `when` tests say whether a way in can be set up here — a
# fingerprint reader is present — and whether the SSH server is on.
#
# They do not say whether fingerprint or FIDO2 is set up. Their remove entries
# show once the package is installed, and both setup scripts install it before
# they enrol a print or register a key, so a setup that failed halfway would
# read as done. PAM is the last thing either writes, so the line in sudo's
# stack is the answer.
SECURITY_SIGN_IN=(fingerprint fido2 sshd)

# Whether sshd takes a password, read the way sshd reads it: the first value
# of a keyword wins, an Include is read where it stands, and everything from
# the first Match on applies only to some connections. Omarchy's own setup
# turns passwords off in a drop-in, but someone who did it by hand in
# sshd_config is just as off, and a page that only knew Omarchy's file would
# tell them otherwise. Prints true, false, or null when a file in the chain
# cannot be read and so the answer is not known.
security_sshd_passwords() {
  [[ -r $SECURITY_SSHD_CONFIG ]] || { echo null; return; }
  local line pattern file
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line =~ ^[[:space:]]*[Ii]nclude[[:space:]]+(.+)$ ]]; then
      for pattern in ${BASH_REMATCH[1]}; do
        [[ $pattern == /* ]] || pattern=/etc/ssh/$pattern
        for file in $pattern; do
          [[ -e $file ]] || continue
          if [[ -r $file ]]; then cat "$file"; echo; else echo "@unreadable"; fi
        done
      done
    else
      printf '%s\n' "$line"
    fi
  done <"$SECURITY_SSHD_CONFIG" | awk '
    /^@unreadable/ { print "null"; done = 1; exit }
    tolower($1) == "match" { exit }
    tolower($1) == "passwordauthentication" && pa == "" { pa = tolower($2) }
    (tolower($1) == "kbdinteractiveauthentication" || tolower($1) == "challengeresponseauthentication") && kbd == "" { kbd = tolower($2) }
    END { if (!done) print ((pa != "no" || kbd != "no") ? "true" : "false") }'
}

security_sign_in() {
  local script
  script=$(menu_entries | jq -r --args '. as $menu | $ARGS.positional[] as $id
    | ("setup", "remove") as $side
    | ($menu[$side + ".security." + $id] | if . == null then "false" else (.when // "true") end) as $when
    | "if \($when); then echo \"\($id)\t\($side)\ttrue\"; else echo \"\($id)\t\($side)\tfalse\"; fi"' \
    "${SECURITY_SIGN_IN[@]}")
  local fingerprint=false fido2=false sshd_running=false passwords entries
  grep -q 'pam_fprintd\.so' "$SECURITY_PAM_SUDO" 2>/dev/null && fingerprint=true
  grep -q 'pam_u2f\.so' "$SECURITY_PAM_SUDO" 2>/dev/null && fido2=true
  # Started by hand and never enabled is still a server taking connections.
  [[ $(capture systemctl is-active sshd) == active ]] && sshd_running=true
  passwords=$(security_sshd_passwords)
  # An Omarchy older than these entries, or a menu someone has trimmed, has
  # nothing for a button to run.
  entries=$(menu_entries | jq -c --args '. as $menu | [$ARGS.positional[] as $id
    | { key: $id, value: { canSetup: ($menu | has("setup.security." + $id)),
                           canRemove: ($menu | has("remove.security." + $id)) } }] | from_entries' \
    "${SECURITY_SIGN_IN[@]}")
  capture bash -c "$script" | jq -R -s -c \
    --argjson fingerprint "$fingerprint" --argjson fido2 "$fido2" \
    --argjson running "$sshd_running" --argjson passwords "$(emit_json "$passwords" null)" \
    --argjson entries "$(emit_json "$entries" '{}')" '
    split("\n") | map(select(length > 0) | split("\t"))
    | reduce .[] as $r ({}; .[$r[0]][if $r[1] == "setup" then "available" else "active" end] = ($r[2] == "true"))
    | .fingerprint.active = $fingerprint | .fido2.active = $fido2
    | .sshd.active = (.sshd.active == true or $running) | .sshd.passwords = $passwords
    | . * $entries'
}

security_poll() {
  par_begin || { echo '{}'; return; }
  par_run firewall security_firewall
  par_run rules security_rules
  par_run listeners security_listeners
  par_run signin security_sign_in
  par_wait

  local firewall rules listeners signin
  firewall=$(par_get firewall '{}')
  rules=$(par_get rules '[]')
  listeners=$(par_get listeners '[]')
  signin=$(par_get signin '{}')
  par_end

  jq -cn \
    --argjson firewall "$(emit_json "$firewall" '{}')" \
    --argjson rules "$(emit_json "$rules" '[]')" \
    --argjson listeners "$(emit_json "$listeners" '[]')" \
    --argjson signin "$(emit_json "$signin" '{}')" '
    def covers($spec; $port):
      $spec == "any" or ($spec | split(",") | any(
        if contains(":") then (split(":") | map(tonumber)) as [$lo, $hi] | $port >= $lo and $port <= $hi
        else (tonumber? // -1) == $port end));
    $firewall + {
      signIn: $signin,
      rules: [$rules[] | . as $rule
        # A container rule names the container, not a socket on this machine,
        # so there is nothing here to match it against.
        | [$listeners[] | select($rule.container | not)
            | select(covers($rule.port; .port))
            | select($rule.proto == "any" or .proto == $rule.proto)
            | select($rule.to == "any" or .anyAddress or .address == $rule.to)] as $on
        | $rule + {
            # Bound only to loopback, a program answers this machine alone.
            listening: ($on | any(.loopback | not)),
            localOnly: (($on | length) > 0 and ($on | all(.loopback))),
            by: ([$on[] | select(.loopback | not)
                  | if .name != "" then .name else .service end | select(. != "")] | unique),
            unnamed: ($on | any((.loopback | not) and .name == "" and .service == "" and .owner != "other")),
            otherUser: ($on | any((.loopback | not) and .name == "" and .owner == "other"))
          }]
        # LocalSend is one door with a TCP and a UDP rule behind it.
        | group_by([.action, .port, .to, .from, .app, .comment, .interface, .container])
        | map(.[0] + { protos: (map(.proto) | unique), listening: any(.[]; .listening),
                       localOnly: all(.[]; .localOnly), by: (map(.by[]) | unique),
                       unnamed: any(.[]; .unnamed), otherUser: any(.[]; .otherUser) } | del(.proto))
        | sort_by(.port | split(",")[0] | split(":")[0] | tonumber? // 0)
    }'
}

security_cmd() {
  local action=${1:-}
  case $action in
    poll) security_poll ;;
    *) die "unknown security action '$action'" ;;
  esac
}
