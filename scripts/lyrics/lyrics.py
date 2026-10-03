#!/usr/bin/env python3
"""Fetch synchronized lyrics.

Providers are tried in order of how well they sync, then how well they cover:

1. AMLL TTML DB  - word-level timing, keyed straight off the Spotify track id,
                   so there is no fuzzy matching to get wrong. Community built,
                   so it does not have everything.
2. LRCLIB        - line-level, matched on title/artist/album/duration.
3. NetEase       - line-level, catches tracks LRCLIB is missing.
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor

API = "https://lrclib.net/api"
AMLL = "https://raw.githubusercontent.com/amll-dev/amll-ttml-db/main/spotify-lyrics"
NETEASE = "https://music.163.com/api"
NE_HEADERS = {"User-Agent": "Mozilla/5.0", "Referer": "https://music.163.com"}
# LRCLIB answers in ~1.5s and AMLL in ~0.1s; anything past a few seconds is a
# stalled connection, and waiting 12s on each one let a single stall cost a minute.
TIMEOUT = 6
# How long a better provider may keep a finished fallback's answer waiting.
FALLBACK_GRACE = 2.5
REQUEST_DELAY = 0.25
USER_AGENT = "QS-Music-Player/1.1 (https://github.com/zonicisalive/quickshell-music-player/)"

STAMP = re.compile(r"\[(\d{1,3}):(\d{2}(?:[.:]\d{1,3})?)\]")
# TTML clock values: 12.5s, 01:02.345 or 01:02:03.456
CLOCK = re.compile(r"^(?:(\d+):)?(?:(\d+):)?(\d+(?:\.\d+)?)s?$")
SPOTIFY_ID = re.compile(r"^[A-Za-z0-9]{22}$")

q = urllib.parse.quote


def emit(payload: dict, request_id: str = "") -> None:
    if request_id:
        payload["requestId"] = request_id
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def get_json(url: str):
    return get_json_with(url, {"User-Agent": USER_AGENT})


def get_json_with(url: str, headers: dict):
    request = urllib.request.Request(url, headers=headers)
    try:
        response = urllib.request.urlopen(request, timeout=TIMEOUT)
    except urllib.error.HTTPError as exc:
        if exc.code != 429:
            raise
        retry_after = float(exc.headers.get("Retry-After", "1"))
        time.sleep(max(0, retry_after))
        response = urllib.request.urlopen(request, timeout=TIMEOUT)
    with response:
        return json.loads(response.read().decode("utf-8", "replace"))


def parse_lrc(lrc: str) -> list:
    out = []
    for raw in lrc.splitlines():
        stamps = list(STAMP.finditer(raw))
        if not stamps:
            continue
        text = raw[stamps[-1].end():].strip()
        for stamp in stamps:
            minutes = int(stamp.group(1))
            seconds = float(stamp.group(2).replace(":", "."))
            out.append({"t": round(minutes * 60 + seconds, 3), "text": text})
    out.sort(key=lambda line: line["t"])
    return out


def normalize(value: str) -> str:
    return re.sub(r"[^\w\s]", " ", (value or "").lower()).strip()


def overlaps(wanted: str, got: str) -> bool:
    wanted, got = normalize(wanted), normalize(got)
    if not wanted or not got:
        return False
    if wanted in got or got in wanted:
        return True
    wanted_words = {w for w in wanted.split() if len(w) > 3}
    return bool(wanted_words & set(got.split()))


def looks_like(candidate: dict, title: str, artist: str) -> bool:
    if not candidate.get("syncedLyrics"):
        return False
    return (overlaps(title, candidate.get("trackName", ""))
            and overlaps(artist, candidate.get("artistName", "")))


def first_line_time(lines: list):
    for line in lines:
        if line.get("text", "").strip():
            return line["t"]
    return None


def pick_by_consensus(candidates: list, duration) -> list:
    """The parsed lines most uploads agree on.

    LRCLIB holds many uploads of a popular song and a few are synced to a
    different master or just mistimed (Reminder has six uploads twelve seconds
    late, one of them the exact album match). Uploads are grouped by when
    their first line starts and the biggest group wins; within it, the upload
    whose length is closest to the track's.
    """
    groups = {}
    for lines, length in candidates:
        start = first_line_time(lines)
        if start is None:
            continue
        key = round(start * 2) / 2  # half-second buckets
        # Fold a neighbouring bucket in, so 11.26 and 11.5 count as one.
        for near in (key - 0.5, key + 0.5):
            if near in groups:
                key = near
                break
        gap = abs(length - float(duration)) if duration and length else 0.0
        groups.setdefault(key, []).append((gap, lines))
    if not groups:
        return []
    best = max(groups.values(), key=lambda group: len(group))
    best.sort(key=lambda pair: pair[0])
    return best[0][1]


def find_lyrics(title: str, artist: str, album: str, duration) -> list:
    exact = []
    if album and duration:
        exact.append(
            "%s/get?track_name=%s&artist_name=%s&album_name=%s&duration=%d"
            % (API, q(title), q(artist), q(album), int(duration))
        )
    exact.append("%s/search?track_name=%s&artist_name=%s" % (API, q(title), q(artist)))
    # The broad free-text search is only a fallback for when the exact
    # lookups found nothing usable.
    broad = "%s/search?q=%s" % (API, q("%s %s" % (title, artist)))

    had_response = False
    last_error = None
    candidates = []
    seen = set()

    def take(payload) -> None:
        for candidate in payload if isinstance(payload, list) else [payload]:
            if not isinstance(candidate, dict) or candidate.get("id") in seen:
                continue
            seen.add(candidate.get("id"))
            if not looks_like(candidate, title, artist):
                continue
            lines = parse_lrc(candidate.get("syncedLyrics") or "")
            if lines:
                candidates.append((lines, float(candidate.get("duration") or 0)))

    # The exact lookups go out together; consensus needs the search results
    # anyway, and asking in parallel keeps this as fast as the old first-hit path.
    with ThreadPoolExecutor(max_workers=len(exact)) as pool:
        futures = [pool.submit(get_json, url) for url in exact]
        for future in futures:
            try:
                take(future.result())
                had_response = True
            except (urllib.error.URLError, ValueError, OSError) as exc:
                last_error = exc

    if not candidates:
        time.sleep(REQUEST_DELAY)
        try:
            take(get_json(broad))
            had_response = True
        except (urllib.error.URLError, ValueError, OSError) as exc:
            last_error = exc

    if candidates:
        return pick_by_consensus(candidates, duration)
    if not had_response and last_error is not None:
        raise last_error
    return []


def get_text(url: str, headers: dict = None, timeout: float = TIMEOUT) -> str:
    request = urllib.request.Request(url, headers=headers or {"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8", "replace")


def ttml_seconds(value: str):
    match = CLOCK.match((value or "").strip())
    if not match:
        return None
    first, second, rest = match.groups()
    parts = [p for p in (first, second) if p is not None]
    total = float(rest)
    for depth, part in enumerate(reversed(parts)):
        total += int(part) * (60 ** (depth + 1))
    return round(total, 3)


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def span_role(node) -> str:
    for key, value in node.attrib.items():
        if local_name(key) == "role":
            return value
    return ""


def leaf_spans(node, out: list) -> None:
    """Word spans in document order. Background vocals, translations and
    romanisations carry their own timing but would double up the line."""
    for child in node:
        if local_name(child.tag) != "span":
            continue
        if span_role(child) in ("x-bg", "x-translation", "x-roman"):
            continue
        if any(local_name(inner.tag) == "span" for inner in child):
            leaf_spans(child, out)
            continue
        if not (child.text or "").strip():
            continue
        out.append({
            "begin": ttml_seconds(child.attrib.get("begin", "")),
            "end": ttml_seconds(child.attrib.get("end", "")),
            "text": child.text,
            "tail": child.tail or "",
        })


def parse_ttml(raw: str) -> list:
    root = ET.fromstring(raw)
    lines = []
    for node in root.iter():
        if local_name(node.tag) != "p":
            continue
        start = ttml_seconds(node.attrib.get("begin", ""))
        if start is None:
            continue

        spans = []
        leaf_spans(node, spans)
        words = []
        text = ""
        for span in spans:
            if span["begin"] is None:
                continue
            end = span["end"] if span["end"] is not None else span["begin"]
            # A TTML span is a syllable, not a word: "cup"+"boards" have no
            # space between them while "wait" does. The gap lives in the tail,
            # so carry it as a flag the renderer can group and wrap on.
            words.append({
                "t": span["begin"],
                "d": round(max(0.0, end - span["begin"]), 3),
                "text": span["text"],
                "sp": bool(span["tail"] and span["tail"][:1].isspace()),
            })
            text += span["text"] + span["tail"]

        text = text.strip()
        if text and words:
            lines.append({"t": start, "text": text, "words": words})
            continue

        # A line with no usable word spans still carries its own timing.
        plain = "".join(node.itertext()).strip()
        if plain:
            lines.append({"t": start, "text": plain})

    lines.sort(key=lambda line: line["t"])
    return lines


def fetch_amll(spotify_id: str) -> list:
    """Word-level lyrics addressed by Spotify track id, so nothing is matched
    by guesswork; the id either has an entry or it does not."""
    if not spotify_id or not SPOTIFY_ID.match(spotify_id):
        return []
    try:
        # A static file on a CDN answers in ~0.1s. It is also first in line, so
        # an occasional stall here would hold back the providers behind it.
        return parse_ttml(get_text("%s/%s.ttml" % (AMLL, spotify_id), timeout=2.5))
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return []
        raise
    except (ET.ParseError, TimeoutError, urllib.error.URLError):
        # A stalled or unreachable CDN is a miss for this provider, not an error
        # for the whole lookup — the line-level providers still get their say.
        return []


# NetEase prefixes its LRC with timed credit lines — "作词 : …" (lyricist),
# "作曲 : …" (composer), "编曲 : …", "Producer : …" — which otherwise play as
# if they were sung. Match the known roles only, so a real lyric with a colon
# ("Listen: …") is never dropped.
CREDIT = re.compile(
    r"^\s*(作词|作曲|编曲|制作人|制作|监制|混音|母带|录音|和声|和音|吉他|贝斯|鼓|键盘|弦乐|"
    r"出品|发行|策划|统筹|企划|OP|SP|词|曲|"
    r"lyricist|lyrics?|composer|composed by|written by|writer|producer|produced by|"
    r"arranger|arranged by|mix(ing)?( engineer)?|master(ing)?( engineer)?|recording|"
    r"vocal( producer)?|guitar|bass|drums|keyboards?|strings|publisher|label)"
    r"\s*(by)?\s*[:：]", re.IGNORECASE)


def drop_credits(lines: list) -> list:
    return [line for line in lines if not CREDIT.match(line.get("text", ""))]


def fetch_netease(title: str, artist: str, duration) -> list:
    found = get_json_with("%s/search/get?s=%s&type=1&limit=5"
                          % (NETEASE, q("%s %s" % (title, artist))), NE_HEADERS)
    songs = ((found or {}).get("result") or {}).get("songs") or []

    matches = []
    for song in songs:
        if not overlaps(title, song.get("name", "")):
            continue
        names = " ".join(a.get("name", "") for a in song.get("artists") or [])
        if not overlaps(artist, names):
            continue
        gap = abs((song.get("duration", 0) / 1000.0) - float(duration)) if duration else 0.0
        matches.append((gap, song))

    # Masters differ in length between services, so rank by how close the
    # runtime is rather than discarding everything outside a fixed window.
    matches.sort(key=lambda pair: pair[0])
    for gap, song in matches:
        if duration and gap > 20:
            break
        payload = get_json_with("%s/song/lyric?id=%s&lv=1&kv=1&tv=-1"
                                % (NETEASE, song.get("id")), NE_HEADERS)
        lines = drop_credits(parse_lrc(((payload or {}).get("lrc") or {}).get("lyric") or ""))
        if lines:
            return lines
    return []


def main() -> None:
    args = sys.argv[1:]
    title = args[0].strip() if len(args) > 0 else ""
    artist = args[1].strip() if len(args) > 1 else ""
    album = args[2].strip() if len(args) > 2 else ""
    request_id = args[4].strip() if len(args) > 4 else ""
    spotify_id = args[5].strip() if len(args) > 5 else ""

    if not title or not artist:
        emit({"status": "no_info"}, request_id)
        return

    try:
        duration = float(args[3]) if len(args) > 3 and args[3] else None
    except ValueError:
        duration = None

    # Word-level first, then the two line-level sources for coverage. All three
    # are asked at once and the answers read back in priority order, so a slow
    # or dead provider only costs its own timeout instead of delaying the ones
    # behind it, and one failing never stops the others being heard.
    providers = (
        ("amll", lambda: fetch_amll(spotify_id)),
        ("lrclib", lambda: find_lyrics(title, artist, album, duration)),
        ("netease", lambda: fetch_netease(title, artist, duration)),
    )

    pool = ThreadPoolExecutor(max_workers=len(providers))
    pending = [(name, pool.submit(provider)) for name, provider in providers]

    def answer(name: str, lines: list) -> None:
        emit({
            "status": "ok",
            "source": name,
            "worded": any(line.get("words") for line in lines),
            "lines": lines,
        }, request_id)
        # The shell reads the answer when this process exits; don't linger on
        # lower-priority lookups nobody needs any more.
        os._exit(0)

    results = {}
    last_error = None
    fallback_since = None
    while True:
        for name, future in pending:
            if name in results or not future.done():
                continue
            try:
                results[name] = future.result() or []
            except Exception as exc:
                last_error = exc
                results[name] = []

        # Walk in priority order: stop at the first provider still thinking,
        # take the first one that answered with lyrics.
        for name, _ in pending:
            if name not in results:
                break
            if results[name]:
                answer(name, results[name])

        # A lower-priority provider has lyrics while a better one is still
        # thinking. Give the better one a short grace, then stop waiting — a
        # stalled connection should not hold a good answer hostage.
        fallback = next((n for n, _ in pending if results.get(n)), None)
        if fallback is not None:
            if fallback_since is None:
                fallback_since = time.monotonic()
            elif time.monotonic() - fallback_since >= FALLBACK_GRACE:
                answer(fallback, results[fallback])

        if len(results) == len(pending):
            break
        time.sleep(0.05)

    if last_error is not None:
        emit({"status": "error", "message": str(last_error)}, request_id)
    else:
        emit({"status": "not_found"}, request_id)
    os._exit(0)


if __name__ == "__main__":
    main()
