# Part of OmaControl. Sourced by bin/omacontrol; not run on its own.
#
# Headlines from omarchy.org. The only thing in this window that leaves the
# machine, which buys it three rules:
#
#   Cached.     One fetch every few hours, kept on disk, and every read after
#               that is a file read. Opening the Overview page does not mean a
#               request.
#   Never waits. The page polls for whatever is cached and the fetch happens
#               in its own subcommand, so a site that hangs costs the reader
#               nothing. The stamp says how old the answer is.
#   Silent on   omarchy.org has no feed, so this reads the news page's HTML.
#   failure.    That is someone else's markup and it will change — one of the
#               headlines it is parsing right now is about the site being
#               redesigned. When the shape moves, this returns nothing and the
#               section disappears rather than showing wreckage.

NEWS_URL="${OMACONTROL_NEWS_URL:-https://omarchy.org/news/}"
NEWS_CACHE="${OMACONTROL_NEWS_CACHE:-${XDG_CACHE_HOME:-$HOME_DIR/.cache}/omarchy/omacontrol/news.json}"
# Long enough that a day of opening the window is one request; short enough
# that "fetched 08:14" is not yesterday's date.
NEWS_MAX_AGE=${OMACONTROL_NEWS_MAX_AGE:-21600}

news_cached() {
  [[ -f $NEWS_CACHE ]] || { echo '{}'; return; }
  emit_json "$(read_file "$NEWS_CACHE")" '{}'
}

news_age() {
  local at
  at=$(news_cached | jq -r '.fetchedAt // 0' 2>/dev/null)
  echo $(( $(date +%s) - ${at:-0} ))
}

# Whether a fetch is worth making. The page calls this before asking for one,
# so a stale cache is refreshed and a fresh one is left alone.
news_stale() {
  [[ ! -f $NEWS_CACHE ]] && return 0
  (( $(news_age) > NEWS_MAX_AGE ))
}

news_fetch() {
  local html
  # Bounded like every other read here, and identified: a scraper that does not
  # say what it is gives the other end no way to ask it to stop.
  html=$(timeout "$OMACONTROL_READ_TIMEOUT" curl -sS -L --max-time "$OMACONTROL_READ_TIMEOUT" \
    -A "omacontrol (+https://github.com/twiking/omacontrol)" "$NEWS_URL" 2>/dev/null \
    | head -c "$OMACONTROL_READ_MAX")
  [[ -n $html ]] || { news_cached; return; }

  local items
  items=$(printf '%s' "$html" | news_parse)
  # A parse that found nothing means the page moved. The last good cache is
  # better than an empty list, and an empty list is better than a broken one.
  if [[ $(jq -r 'length' <<<"${items:-[]}" 2>/dev/null || echo 0) -eq 0 ]]; then
    news_cached
    return
  fi

  local next
  next=$(jq -cn --argjson items "$items" --argjson at "$(date +%s)" \
    '{ fetchedAt: $at, items: $items }')
  mkdir -p "$(dirname "$NEWS_CACHE")"
  printf '%s\n' "$next" >"$NEWS_CACHE" 2>/dev/null
  printf '%s' "$next"
}

# The news page is Astro-rendered HTML: an anchor per story, holding a <time>
# with a machine-readable date and a <span> whose first text is the headline.
# Python because this is regex over someone else's markup either way, and doing
# it in awk would be the same fragility spelled less clearly.
news_parse() {
  # The program arrives on fd 3, not on stdin. `python3 -` reads its *script*
  # from stdin, which would eat the HTML this is meant to be parsing — the
  # parser then finds nothing in an empty string and reports a page that
  # changed shape, which is a maddening way to debug a working regex.
  python3 /dev/fd/3 3<<'PY'
import html
import json
import re
import sys

page = sys.stdin.read()

# Anchor, then the date, then the headline up to the chevron that follows it.
story = re.compile(
    r'<a\s+href="(?P<href>/news/\d{4}/\d{2}/[^"]+)"[^>]*>'
    r'\s*<time[^>]*dateTime="(?P<iso>[^"]+)"[^>]*>(?P<shown>[^<]*)</time>'
    r'\s*<span[^>]*>(?P<title>.*?)(?:<svg|</span>)',
    re.S)

items = []
seen = set()
for match in story.finditer(page):
    title = re.sub(r'<[^>]+>', '', match.group('title'))
    title = html.unescape(title).strip()
    href = match.group('href')
    if not title or href in seen:
        continue
    seen.add(href)
    items.append({
        'title': title,
        'url': 'https://omarchy.org' + href,
        'date': match.group('iso')[:10],
        # What the site itself chose to print, so the row does not have to
        # guess a format the reader will disagree with.
        'shown': html.unescape(match.group('shown')).strip(),
    })
    if len(items) == 8:
        break

json.dump(items, sys.stdout)
PY
}

news_cmd() {
  case ${1:-state} in
    # What is on disk, whatever its age. This is what the page polls.
    state|poll) news_cached ;;
    # Asked for by the page, once, and only when the cache has aged out.
    fetch) news_fetch ;;
    refresh) news_fetch ;;
    stale) news_stale && echo true || echo false ;;
    open) shift; [[ -n ${1:-} ]] || die "usage: omacontrol news open <url>"
      # Only ever a URL this fetch produced, and only ever on the site it came
      # from: a headline is untrusted text and its link is untrusted with it.
      [[ $1 == https://omarchy.org/* ]] || die "refusing to open $1"
      setsid -f xdg-open "$1" >/dev/null 2>&1 ;;
    *) die "usage: omacontrol news poll|fetch|stale|open <url>" ;;
  esac
}
