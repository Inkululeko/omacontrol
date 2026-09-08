# Part of OmaControl. Sourced by bin/omacontrol; not run on its own.

# ---------------------------------------------------------------- our store

read_store() {
  [[ -f $STORE ]] && read_file "$STORE" | jq -c . 2>/dev/null && return
  echo '{}'
}

# jq-edit the store, then re-render the generated Hyprland config from it.
edit_store() {
  local filter=$1
  shift
  local current next
  current=$(read_store)
  next=$(jq -c "$filter" "$@" <<<"$current") || die "failed to update $STORE"
  write_file "$STORE" managed <<<"$next" || die "failed to write $STORE"
  render_managed
}

# The same edit without the re-render, for the things the store remembers that
# no Hyprland config is derived from — which notices have been waved away, say.
# Going through edit_store for those would rewrite and reload the generated
# config to record that someone clicked an x.
note_store() {
  local filter=$1
  shift
  local next
  next=$(jq -c "$filter" "$@" <<<"$(read_store)") || die "failed to update $STORE"
  write_file "$STORE" managed <<<"$next" || die "failed to write $STORE"
}

store_get() { jq -r --arg k "$1" '.hypr[$k] // empty' <<<"$(read_store)"; }
