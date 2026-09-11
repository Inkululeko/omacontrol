# Part of OmaControl. Sourced by bin/omacontrol; not run on its own.

# ---------------------------------------------------------------- branding

# The screensaver and the About screen are each one file of ASCII, whether it
# was typed or transcoded from an image — so the page can show what it is
# about to change rather than describing it.
branding_file() {
  local file="$HOME_DIR/.config/omarchy/branding/$1.txt"
  [[ -r $file ]] && read_file "$file" || true
}

branding_state() {
  jq -cn \
    --arg screensaver "$(branding_file screensaver)" \
    --arg about "$(branding_file about)" \
    '{ screensaver: $screensaver, about: $about }'
}
