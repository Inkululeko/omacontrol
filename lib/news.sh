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
# Half an hour. Short enough that a headline posted this morning is on the page
# by lunch; long enough that a window opened twenty times in an afternoon is
# still one request. `news fetch` checks this itself, so the page can ask on
# every open and on a timer without either of those meaning a request.
NEWS_MAX_AGE=${OMACONTROL_NEWS_MAX_AGE:-1800}

# How many read marks to keep. The list only ever grows, and a headline that
# scrolled off omarchy.org years ago cannot come back to be unread — so old
# marks are dropped rather than kept for ever in a config file.
NEWS_READ_KEEP=${OMACONTROL_NEWS_READ_KEEP:-60}

# The cache, with each item told whether it has been read.
#
# Read state lives in OmaControl's own store rather than beside the cache: the
# cache is disposable — delete it and the next fetch rebuilds it — while what
# you have already read is yours, and losing it would light up eight stars for
# news you read last week.
news_cached() {
  [[ -f $NEWS_CACHE ]] || { echo '{}'; return; }
  local cache read
  cache=$(emit_json "$(read_file "$NEWS_CACHE")" '{}')
  read=$(news_read_list)

  emit_json "$(jq -cn --argjson cache "${cache:-{\}}" --argjson read "${read:-[]}" '''
    $cache + { items: [ $cache.items[]? | . as $item
                        | $item + { read: ($read | index($item.url) != null) } ] }''')" '{}'
}

news_read_list() {
  read_store | jq -c '[ (.newsRead // [])[] ]' 2>/dev/null || echo '[]'
}

# Marking read is idempotent and bounded, and it does not re-render anything:
# note_store writes the store without rebuilding the Hyprland config, which a
# read headline has no business touching.
news_mark_read() {
  local url=$1
  [[ -n $url ]] || return 0
  note_store '.newsRead = (((.newsRead // []) + [$url]) | unique | .[-($keep):])' \
    --arg url "$url" --argjson keep "$NEWS_READ_KEEP"
}

news_mark_unread() {
  local url=$1
  [[ -n $url ]] || return 0
  note_store '.newsRead = ((.newsRead // []) - [$url])' --arg url "$url"
}

# Everything currently in the cache, in one write.
news_mark_all_read() {
  local urls
  urls=$(news_cached | jq -c '[ .items[]?.url ]')
  note_store '.newsRead = (((.newsRead // []) + $urls) | unique | .[-($keep):])' \
    --argjson urls "${urls:-[]}" --argjson keep "$NEWS_READ_KEEP"
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
  # The age check lives here, not in the caller. Every comment about this being
  # free to ask depends on it, and for a while it was not true: `fetch` ran the
  # request unconditionally and `stale` was a subcommand nobody called, so a
  # window opened twenty times made twenty requests.
  if [[ ${1:-} != --force ]] && ! news_stale; then
    # Still seed, in case a cache was written before read marks existed.
    news_seed
    news_cached
    return
  fi

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
  news_seed
  # Read back through news_cached so callers always get the same shape, read
  # marks included.
  news_cached
}

# The first list anyone sees is not "new". Without this, a fresh install opens
# on eight starred headlines — every one of which is simply the news, and none
# of which the reader has missed. So the first successful fetch marks what it
# found as read, and a star from then on means *since you last looked*.
#
# Flagged separately from the read list itself, or marking everything unread
# again would be undone by the next fetch.
news_seed() {
  [[ $(read_store | jq -r '.newsSeeded // false') == true ]] && return 0
  local urls
  urls=$(emit_json "$(read_file "$NEWS_CACHE")" '{}' | jq -c '[ .items[]?.url ]')
  note_store '.newsSeeded = true | .newsRead = (($urls // []) | unique)' \
    --argjson urls "${urls:-[]}"
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
    refresh) news_fetch --force ;;
    stale) news_stale && echo true || echo false ;;
    read) shift; [[ -n ${1:-} ]] || die "usage: omacontrol news read <url>"
      news_mark_read "$1" ;;
    unread) shift; [[ -n ${1:-} ]] || die "usage: omacontrol news unread <url>"
      news_mark_unread "$1" ;;
    read-all) news_mark_all_read ;;
    open) shift; [[ -n ${1:-} ]] || die "usage: omacontrol news open <url>"
      # Only ever a URL this fetch produced, and only ever on the site it came
      # from: a headline is untrusted text and its link is untrusted with it.
      [[ $1 == https://omarchy.org/* ]] || die "refusing to open $1"
      # Opening one is reading it. Anything else means a headline you clicked
      # is still starred when you come back, which is the one thing a star
      # must never do.
      news_mark_read "$1"
      setsid -f xdg-open "$1" >/dev/null 2>&1 ;;
    *) die "usage: omacontrol news poll|fetch|stale|read <url>|unread <url>|read-all|open <url>" ;;
  esac
}
