---
paths:
  - "lib/news.sh"
  - "sections/OverviewSection.qml"
---

# The one thing that leaves the machine

> **Read this when:** you touch `lib/news.sh` or the news list on Overview.

## The one thing that leaves the machine

`lib/news.sh` fetches headlines from omarchy.org. It is the only outbound
request this window makes, and it earns three rules:

**Cached, stamped, and asked for once.** The page calls `news fetch` on open;
that subcommand decides for itself whether the cache has aged out
(`NEWS_MAX_AGE`, half an hour) and does nothing if it has not. The poll picks up whatever landed. So opening
Overview is not a request, and the "Fetched 20 min ago" note is there because a
headline with no age on it is a headline you cannot judge.

**The feed, not the page.** omarchy.org publishes RSS at `/news/rss.xml`. It
is *not* advertised with a `<link rel="alternate">` in the news page's head,
which is how the first version of this ended up scraping the HTML — four
guessed feed paths came back 404 and the search stopped there. Check the head,
then check `rss.xml` as well as `feed.xml`.

A feed is a contract and markup is not: the scraper had to be told which
`<span>` held a headline, and one of the headlines it returned was about the
site being redesigned. A parse that finds nothing still keeps the last good
cache, and the section disappears rather than showing wreckage.

**Read marks are keyed on the URL, so the URL has to be normalised.** The
feed's `<link>` has no trailing slash; the scraped `href` did. Switching to the
feed without normalising would have made all eight already-read headlines look
new. Both sides are compared with `rtrimstr("/")`, which also means marks
written before the switch keep working without a migration.

**Half an hour, checked in the reader.** `news fetch` compares the cache's age
itself and returns the cache untouched if it is under `NEWS_MAX_AGE`. That is
what lets the page ask on open *and* on a half-hourly timer without either
being a request — and it was briefly a lie: `fetch` ran the request
unconditionally while `stale` sat there as a subcommand nobody called.

**A star means new since you last looked, so the first list is not new.** The
first successful fetch marks everything it found as read and sets
`newsSeeded`; without it a fresh install opens on eight starred headlines, none
of which the reader has missed. The flag is separate from the read list, or
marking everything unread again would be undone by the next fetch.

Read marks live in **our store**, not beside the cache. The cache is
disposable — delete it and the next fetch rebuilds it — while what you have
already read is yours. They go through `note_store`, so recording a read
headline does not re-render the Hyprland config, and the list is capped: a
headline that scrolled off omarchy.org cannot come back to be unread.

**A headline is untrusted text.** `news open` refuses any URL that is not on
omarchy.org, so a link cannot be turned into a way to open something else.

The trap worth remembering: `python3 - <<'PY'` reads the *program* from stdin,
so the heredoc eats the HTML the parser was meant to read. The program goes on
another descriptor (`python3 /dev/fd/3 3<<'PY'`) and stdin stays the data.

