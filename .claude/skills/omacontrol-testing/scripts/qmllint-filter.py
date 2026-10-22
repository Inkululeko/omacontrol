"""Report the qmllint findings this tree did not already have.

qmllint cannot type three things this codebase is built on — the `Style` and
`Color` singletons, the parent chain a row walks to reach its page, and
anything reached through a `Loader`'s `item` — so it emits about two hundred
missing-property findings on a clean tree and will go on doing so. Everything
else it reports is fixable, and was fixed on the move to Qt 6.12.

The first version of this script excused them by *category*, and measured
afterwards it removed 679 findings out of 679: an undefined identifier dropped
into any file was reported as clean. A check that cannot fail is worse than no
check, because it turns "not verified" into "verified fine".

So nothing is excused by category. The findings of a known-good tree are
recorded in qmllint-baseline.txt, and what is reported is the difference: a
finding this tree did not already have, or one occurrence more of a finding it
did. Regenerate the baseline with --update when a real fix removes findings,
and read the diff before you commit it.
"""
import os
import re
import sys
from collections import Counter
from pathlib import Path

FINDING = re.compile(r"^(Warning|Error|Info):\s+(\S+?):(\d+):(\d+):\s+(.*?)\s*$")
BASELINE = Path(__file__).with_name("qmllint-baseline.txt")


def key(level: str, path: str, message: str) -> str:
    """File and message, without line:col — a finding must not become 'new'
    because something above it gained a line."""
    return f"{level}\t{path}\t{message}"


def parse(stream, repo: str) -> Counter:
    seen: Counter = Counter()
    for raw in stream:
        m = FINDING.match(raw)
        if not m:
            continue
        level, path, _line, _col, message = m.groups()
        if repo and path.startswith(repo + "/"):
            path = path[len(repo) + 1:]
        seen[key(level, path, message)] += 1
    return seen


def main() -> int:
    repo = os.environ.get("ROOT", "")
    found = parse(sys.stdin, repo)
    total = sum(found.values())

    if "--update" in sys.argv:
        BASELINE.write_text("".join(f"{n}\t{k}\n" for k, n in sorted(found.items())))
        print(f"baseline written: {len(found)} distinct findings, {total} occurrences")
        return 0

    base: Counter = Counter()
    if BASELINE.exists():
        for line in BASELINE.read_text().splitlines():
            n, _, k = line.partition("\t")
            if k:
                base[k] = int(n)
    else:
        print(f"no baseline at {BASELINE.name} — run lint-qml.sh --update once on a known-good tree", file=sys.stderr)
        return 1

    new = {k: n - base.get(k, 0) for k, n in found.items() if n > base.get(k, 0)}
    gone = {k: base[k] - found.get(k, 0) for k in base if base[k] > found.get(k, 0)}

    print(f"{total} findings, {sum(base.values())} in the baseline")
    if gone:
        print(f"{sum(gone.values())} fewer than the baseline — rerun with --update to record that")
    if not new:
        print("nothing new")
        return 0

    print(f"\n{sum(new.values())} NEW:")
    for k, n in sorted(new.items()):
        level, path, message = k.split("\t")
        print(f"  {level}: {path}: {message}" + (f"  (×{n} more)" if n > 1 else ""))
    return 1


if __name__ == "__main__":
    sys.exit(main())
