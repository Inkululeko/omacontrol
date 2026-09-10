# Part of OmaControl. Sourced by bin/omacontrol; not run on its own.

# --------------------------------------------------------------------- themes
#
# The pictures, not the names. A theme is a look, and a list of twenty-five
# words is the one description of a look that helps nobody.
#
# Which picture stands for a theme is Omarchy's own rule, lifted from
# `omarchy-theme-switcher`: a preview file at the theme's root, in any of the
# formats it accepts, and failing that the first of its backgrounds. A second
# rule here would show a different picture for the same theme in two places.
theme_preview() {
  local dir=$1 name

  for name in preview.png preview.jpg preview.jpeg preview.webp preview.gif preview.bmp; do
    local found
    found=$(find -L "$dir" -maxdepth 1 -type f -iname "$name" -print -quit 2>/dev/null)
    [[ -n $found ]] && { printf '%s\n' "$found"; return; }
  done

  [[ -d $dir/backgrounds ]] || return
  find -L "$dir/backgrounds" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \
       -o -iname '*.bmp' -o -iname '*.webp' \) 2>/dev/null | sort | head -n1
}

# `omarchy-theme-list` prints display names — "Catppuccin Latte" — while every
# path is the slug the directory is actually called. The list command builds
# one from the other with a sed; this is that transformation run backwards.
theme_slug() {
  printf '%s\n' "${1,,}" | tr ' ' '-'
}

# Both homes of a theme, user first. `omarchy-theme-dir` answers with one or
# the other, and on this machine the user's copy of Catppuccin holds a single
# neovim.lua — a partial override — so asking it alone finds a theme with no
# colours and no backgrounds. Everything here reads the pair.
theme_dirs() {
  local slug=$1
  [[ -d $HOME_DIR/.config/omarchy/themes/$slug ]] && printf '%s\n' "$HOME_DIR/.config/omarchy/themes/$slug"
  [[ -d ${OMARCHY_PATH:-/usr/share/omarchy}/themes/$slug ]] && printf '%s\n' "${OMARCHY_PATH:-/usr/share/omarchy}/themes/$slug"
  return 0
}

themes_list() {
  local current names name slug dir dirs preview rows=""
  current=$(capture omarchy-theme-current)
  # Read the whole list before looping. Commands run inside a `while read`
  # loop share its stdin and eat the rest of the list — which is why the first
  # version returned exactly one theme.
  names=$(capture omarchy-theme-list)

  while IFS= read -r name; do
    [[ -n $name ]] || continue
    slug=$(theme_slug "$name")
    dirs=$(theme_dirs "$slug")
    [[ -n $dirs ]] || continue

    preview=""
    local isTheme=false first=""
    while IFS= read -r dir; do
      [[ -n $dir ]] || continue
      [[ -z $first ]] && first=$dir
      [[ -f $dir/colors.toml ]] && isTheme=true
      [[ -z $preview ]] && preview=$(theme_preview "$dir")
    done <<<"$dirs"

    # A directory in the themes folder is not a theme unless it says what the
    # colours are; both folders collect other things.
    [[ $isTheme == true ]] || continue
    rows+="$name"$'\t'"$first"$'\t'"$preview"$'\n'
  done <<<"$names"

  jq -R -s -c --arg current "$current" 'split("\n")
    | map(select(length > 0) | split("\t")
      | { name: .[0], dir: .[1], preview: (.[2] // ""),
          current: (.[0] == $current) })' <<<"$rows"
}

# Exactly the two places `omarchy-theme-bg-next` looks, in its order: the
# wallpapers you dropped in for this theme, then the theme's own. And the one
# in force is read off the symlink rather than matched by name —
# `omarchy-theme-bg-current` prints a prettified title, which is a string to
# show a person, not a key to compare paths against.
themes_backgrounds() {
  local theme mine theirs current files
  theme=$(capture omarchy-theme-current)
  mine="$HOME_DIR/.config/omarchy/backgrounds/$theme"
  theirs="$HOME_DIR/.local/state/omarchy/current/theme/backgrounds"
  current=$(readlink -f "$HOME_DIR/.local/state/omarchy/current/background" 2>/dev/null)

  files=$(find -L "$mine" "$theirs" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \
       -o -iname '*.bmp' -o -iname '*.webp' \) 2>/dev/null | sort)

  jq -R -s -c --arg current "${current:-}" 'split("\n") | map(select(length > 0))
    | map({ path: .,
            title: (. | split("/") | last | sub("\\.[^.]+$"; "")
                      | sub("^[0-9]+[-_ ]*"; "") | gsub("[-_]"; " ")
                      | split(" ") | map(select(length > 0)
                      | (.[0:1] | ascii_upcase) + .[1:]) | join(" ")),
            current: (. == $current) })'  <<<"$files"
}

themes_cmd() {
  local action=${1:-}
  case $action in
    list) themes_list ;;
    backgrounds) themes_backgrounds ;;
    bg)
      [[ -n ${2:-} ]] || die "no background given"
      [[ -f $2 ]] || die "no such image"
      omarchy-theme-bg-set "$2" >/dev/null 2>&1 || die "could not set the background" ;;
    *) die "unknown theme action '$action'" ;;
  esac
}
