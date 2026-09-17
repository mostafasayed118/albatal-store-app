#!/usr/bin/env python3
"""Emits every Unicode Nd (decimal digit) block as SQL `translate` tables,
Dart range constants, and probe fixtures — and verifies the invariants the
migration depends on.

Run from the worktree root:

    python3 supabase/tests/gen_phone_digit_ranges.py          # print the blocks
    python3 supabase/tests/gen_phone_digit_ranges.py --verify # check the artifacts agree

`--verify` reads the SHIPPED artifacts (065, supabase_admin_repository.dart,
run_keyset_paging_proof.mjs) and fails if any of them disagrees with the block
list this module derives from Python's `unicodedata` — i.e. from the Unicode
database of whatever Python 3 ships in this environment. Regenerate outputs
after a Unicode bump with the printed snippets; re-run --verify in CI-style
gates to catch drift.

Why a generator at all: a wrong entry in a `translate` table does not merely
miss a match — it CORRUPTS the stored `phone_digits` value. Hand-writing 70
blocks of ten codepoints each is exactly how such an entry happens. The
generator also asserts the structural facts the SQL depends on:

  * every Nd block is a multiple of 10 codepoints, and consecutive runs are
    split so each emitted block starts at DIGIT VALUE 0 (this is what lets one
    shared ASCII TO table serve every block positionally);
  * no block appears twice (duplicate FROM entries would silently make the
    first mapping win);
  * codepoint VALUE maps positionally to DIGIT VALUE (base + i -> i).

`unicodedata` version is printed with the output so a Unicode bump is visible
in the evidence rather than silent.
"""

import re
import sys
import unicodedata

# Blocks are derived, not hardcoded: walk the whole BMP + astral ranges and
# group consecutive Nd codepoints. Grouping by consecutive runs rather than by
# named blocks is what makes this robust to a Unicode bump adding a block the
# author has never heard of.


def nd_blocks():
    """Consecutive runs of Nd codepoints, as (first_cp, length) pairs."""
    runs = []
    start = prev = None
    for cp in range(0x110000):
        if unicodedata.category(chr(cp)) == "Nd":
            if start is None:
                start = prev = cp
            elif cp == prev + 1:
                prev = cp
            else:
                runs.append((start, prev - start + 1))
                start = prev = cp
    if start is not None:
        runs.append((start, prev - start + 1))
    return runs


def digit_blocks():
    """Nd blocks as (first_cp, 10) pairs — consecutive RUNS split into tens.

    A run can be longer than 10 when two digit blocks are adjacent in the
    code space (the Mathematical Alphanumeric Symbols digits are five blocks
    back to back), so runs are split into chunks of 10 and every chunk is
    ASSERTED to start at digit value 0. That assertion is what lets one shared
    ASCII TO table serve every block positionally.
    """
    blocks = []
    for start, length in nd_blocks():
        if length % 10 != 0:
            raise AssertionError(
                f"Nd run at U+{start:04X} has length {length}, not a multiple of 10"
            )
        for offset in range(0, length, 10):
            base = start + offset
            if unicodedata.digit(chr(base)) != 0:
                raise AssertionError(
                    f"chunk at U+{base:04X} does not start at digit 0"
                )
            blocks.append((base, 10))
    return blocks


def sql_blocks():
    return [(b, n) for b, n in digit_blocks() if b > 0x7F]


def sql_from_table():
    # One character per CODEPOINT of every block — not per block. `translate`
    # pairs FROM and TO positionally, so the FROM table must carry all ten
    # digits of each block, not just its zero.
    return "".join(chr(b + i) for b, n in sql_blocks() for i in range(n))


def sql_to_table():
    # ASCII digits, aligned positionally with the FROM table above. Because
    # every block starts at digit value 0 and maps value positionally, this is
    # just 0-9 repeated once per block.
    return "0123456789" * len(sql_blocks())


def probe_fixture_rows():
    """(id, display_name, db_name, stored_phone, digits) for one row per block.

    The stored value is <native 0><native 9><two ASCII digits encoding the row
    index>. The two ASCII digits are what keep the rows from colliding: with a
    fixed '0909' everywhere, a search for '0909' would match all 75 rows and
    the probe's "reaches THIS row and nothing else" check would be false for
    every one of them. Two decimal digits give 100 combinations for 75 rows.

    The DB name is index-based ('Digits 03') and deliberately NOT the hex code:
    the search goes through an or-tree whose full_name branch would otherwise
    match a DIFFERENT row's digits — a term of '0966' matches the Devanagari
    row when its name is 'Digits U+0966', and the exact-one-match check fails
    (found live, U+1D7E2 vs U+0966). Names carry at most two consecutive
    digits, so no digit term can match a name.

    The display name keeps the hex — it is probe OUTPUT only, never searched.
    """
    rows = []
    for idx, (base, _) in enumerate(sql_blocks()):
        zero, nine = chr(base), chr(base + 9)
        tail = f"{idx:02d}"  # '00'..'74' — unique per row
        rows.append(
            (
                f"00000000-0000-0000-0000-{400 + idx + 1:012d}",
                f"Digits U+{base:04X}",
                f"Digits {tail}",
                f"{zero}{nine}{tail}",
                f"09{tail}",
            )
        )
    return rows


def python_unicode_version():
    return unicodedata.unidata_version


def translit_pairs():
    """The (native_digit_char, ascii_digit_char) pairs, one per codepoint.

    Same enumeration the migration's `translate` tables and the Dart block
    list are derived from — so the probe's JS mirror cannot disagree with
    either without the verify step failing.
    """
    return [
        (chr(base + i), str(i)) for base, _ in sql_blocks() for i in range(10)
    ]


# ---------------------------------------------------------------------------
# Generated regions.
#
# The `translate` tables are 750 characters of exotic Unicode. Typing them by
# hand is exactly how a corrupting typo happens, so the artifacts carry marked
# regions that THIS SCRIPT owns; everything around them is hand-written.
# Regenerate after a Unicode bump:
#
#     python3 supabase/tests/gen_phone_digit_ranges.py --apply
# ---------------------------------------------------------------------------

M_BEGIN = "-- unicode-digit-tables:generated — do not edit by hand"
M_END = "-- unicode-digit-tables:end"

# A distinct marker pair for the fixture rows: each region must keep its own
# markers, or one --apply run consumes the other region's anchors and the next
# run can no longer find them (which is exactly what happened on the first
# attempt — the INSERT replaced the rows markers and re-running aborted).
R_BEGIN = "-- unicode-digit-rows:generated — do not edit by hand"
R_END = "-- unicode-digit-rows:end"

JS_BEGIN = "// unicode-digit-blocks:generated — do not edit by hand"
JS_END = "// unicode-digit-blocks:end"

# The probe's JS transliteration table: the same (native -> ascii) pairs the
# migration bakes into `translate`, emitted for the probe's JS MIRROR of the
# Dart client. A mirror that hardcodes only the Arabic pairs while the column
# maps all of them is not a mirror — it silently routes native terms down the
# literal `phone` path and green-checks a filter the real client never builds.
P_BEGIN = "// unicode-digit-translit:generated — do not edit by hand"
P_END = "// unicode-digit-translit:end"


def js_translit_region():
    """The (FROM_char, TO_char) pairs for the probe's JS mirror, as JS text."""
    pairs = ", ".join(
        f"['{f}', '{t}']" for f, t in translit_pairs()
    )
    return (
        f"{P_BEGIN}\n"
        f"// {len(sql_blocks())} non-ASCII Nd blocks, unicodedata "
        f"{python_unicode_version()}; regenerate with\n"
        f"//   python3 supabase/tests/gen_phone_digit_ranges.py --apply\n"
        f"const TRANSLIT_PAIRS = [\n{pairs},\n];\n"
        f"{P_END}"
    )


def sql_translate_region():
    """The `translate(...)` call for the generated column, as SQL text.

    The TO table is `repeat('0123456789', N)` rather than a second 750-char
    literal: `repeat` is IMMUTABLE, so the generated column accepts it, and a
    derived TO table cannot fall out of alignment with the FROM table the way
    two independently hand-edited literals can. N is the block count.
    """
    blocks = sql_blocks()
    n = len(blocks)
    return (
        f"{M_BEGIN}\n"
        f"      -- {n} non-ASCII Nd blocks, unicodedata "
        f"{python_unicode_version()}; regenerate with\n"
        f"      --   python3 supabase/tests/gen_phone_digit_ranges.py --apply\n"
        f"      translate(\n"
        f"        COALESCE(phone, ''),\n"
        f"        '{sql_from_table()}',\n"
        f"        repeat('0123456789', {n})\n"
        f"      ),\n"
        f"{M_END}"
    )


def sql_fixture_rows_region():
    """The per-block fixture INSERT for seed.sql."""
    rows = probe_fixture_rows()
    values = ",\n".join(
        f"  ('{i}', '{db_name}', '{stored}', 'standard', "
        f"timestamptz '2026-09-15 23:00:00+00' - {idx} * interval '1 minute')"
        for idx, (i, _display, db_name, stored, _digits) in enumerate(rows)
    )
    return (
        f"{R_BEGIN}\n"
        f"insert into public.profiles (id, full_name, phone, membership_tier, created_at) values\n"
        f"{values};\n"
        f"{R_END}"
    )


def dart_blocks_region():
    """The Dart block-base list, between markers.

    One base per line on purpose: `dart format` settles a 75-entry const list
    that does not fit on the line into exactly that layout, so emitting it
    here keeps --apply output byte-stable under the formatter instead of
    churning ~60 lines on every regeneration cycle.
    """
    bases = [f"0x{b:04X}," for b, _ in sql_blocks()]
    lines = [
        f"{JS_BEGIN}",
        f"// {len(bases)} non-ASCII Nd blocks, unicodedata "
        f"{python_unicode_version()}; regenerate with",
        "//   python3 supabase/tests/gen_phone_digit_ranges.py --apply",
        "const List<int> _digitBlockBases = <int>[",
    ]
    lines += ["  " + b for b in bases]
    lines += ["];", JS_END]
    return "\n".join(lines)


def js_blocks_region():
    """The probe's per-block fixture array, between markers."""
    rows = probe_fixture_rows()
    entries = ",\n".join(
        f"  {{ id: '{i}', base: '0x{b:04X}', block: '{display}', "
        f"stored: '{stored}', digits: '{d}' }}"
        for ((i, display, _db_name, stored, d), (b, _)) in zip(rows, sql_blocks())
    )
    return (
        f"{JS_BEGIN}\n"
        f"const DIGIT_BLOCKS = [\n{entries}\n];\n"
        f"{JS_END}"
    )


def _replace_marked(text, begin, end, replacement):
    b = text.find(begin)
    e = text.find(end)
    if b < 0 or e < 0 or e < b:
        raise SystemExit(
            f"marked region not found (begin={begin!r}, end={end!r}) — "
            f"the artifacts must carry the markers before --apply can update them"
        )
    return text[:b] + replacement + text[e + len(end) :]


def _function_body(source, fn_name):
    """Crude body slice for the probe's top-level `function name(...) {...}`.
    Only good enough for the parity spot-checks in verify(); it must NOT be
    the mechanism that keeps the mirror honest — the generated TRANSLIT_PAIRS
    region is. Returns '' when the function is absent.
    """
    m = re.search(
        rf"^function {re.escape(fn_name)}\([^)]*\) \{{",
        source,
        flags=re.MULTILINE,
    )
    if not m:
        return ""
    depth = 0
    for i in range(m.start(), len(source)):
        c = source[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return source[m.start() : i + 1]
    return ""


def apply():
    """Rewrite the marked generated regions in 065, seed.sql and the probe."""
    targets = {
        "supabase/migrations/065_profiles_phone_digits.sql": [
            (M_BEGIN, M_END, sql_translate_region()),
        ],
        "supabase/tests/keyset-proof/seed.sql": [
            (M_BEGIN, M_END, sql_translate_region()),
            ("-- unicode-digit-rows:generated — do not edit by hand",
             "-- unicode-digit-rows:end", sql_fixture_rows_region()),
        ],
        "supabase/tests/run_keyset_paging_proof.mjs": [
            (JS_BEGIN, JS_END, js_blocks_region()),
            (P_BEGIN, P_END, js_translit_region()),
        ],
        "lib/features/admin/data/supabase_admin_repository.dart": [
            (JS_BEGIN, JS_END, dart_blocks_region()),
        ],
    }
    for path, regions in targets.items():
        text = _read(path)
        for begin, end, replacement in regions:
            text = _replace_marked(text, begin, end, replacement)
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"updated {path}")


def _read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def verify():
    """Fail (exit 1) if any shipped artifact disagrees with the derived blocks."""
    failures = []

    blocks = sql_blocks()
    from_table = sql_from_table()
    # The TO table ships as `repeat('0123456789', N)` — see the region builder.
    to_table_check = f"repeat('0123456789', {len(blocks)})"

    # 1. Migration 065 must carry BOTH tables, verbatim and aligned.
    migration = _read("supabase/migrations/065_profiles_phone_digits.sql")
    if from_table not in migration:
        failures.append(
            "065: the FROM table literal is absent, truncated or reordered"
        )
    if to_table_check not in migration:
        failures.append("065: the derived TO table is absent or misaligned")
    # Aligned by construction (repeat), but the length must match the block
    # count or the FROM table and the TO table disagree positionally.
    if len(from_table) != 10 * len(blocks):
        failures.append(
            f"065: FROM table length {len(from_table)} != 10 x {len(blocks)} blocks"
        )

    # 2. The Dart block list must be exactly the derived bases, no more, no
    #    fewer. Scoped to the marked list so unrelated hex in the file (doc
    #    comments, other constants) cannot trip it.
    dart = _read("lib/features/admin/data/supabase_admin_repository.dart")
    marker_begin = "// unicode-digit-blocks:generated — do not edit by hand"
    marker_end = "// unicode-digit-blocks:end"
    begin = dart.find(marker_begin)
    end = dart.find(marker_end)
    if begin < 0 or end < 0 or end < begin:
        failures.append("Dart: the generated block-list markers are missing")
    else:
        import re

        listed = [
            int(tok, 16)
            for tok in re.findall(r"0x([0-9A-Fa-f]{4,6})", dart[begin:end])
        ]
        expected = [b for b, _ in blocks]
        if listed != expected:
            missing = sorted(set(expected) - set(listed))
            extra = sorted(set(listed) - set(expected))
            failures.append(
                f"Dart: block list disagrees (missing={[f'U+{b:04X}' for b in missing]} "
                f"extra={[f'U+{b:04X}' for b in extra]})"
            )

    # 3. The probe must carry one fixture row per block, named by block.
    probe = _read("supabase/tests/run_keyset_paging_proof.mjs")
    for base, _ in blocks:
        if f"U+{base:04X}" not in probe:
            failures.append(f"probe: no fixture for U+{base:04X}")

    # 4. The probe's JS transliteration table must be exactly the derived
    #    pairs. The mirror is what makes the native-direction checks exercise
    #    phone_digits; a stale table there means those checks test a filter
    #    the real client never builds.
    p_begin = probe.find(P_BEGIN)
    p_end = probe.find(P_END)
    if p_begin < 0 or p_end < 0 or p_end < p_begin:
        failures.append("probe: the translit-table markers are missing")
    else:
        pairs_region = probe[p_begin:p_end]
        expected_pairs = translit_pairs()
        listed_pairs = re.findall(
            r"\['(.)', '(.)'\]", pairs_region, flags=re.DOTALL
        )
        if [tuple(p) for p in listed_pairs] != expected_pairs:
            failures.append(
                "probe: TRANSLIT_PAIRS disagrees with the derived table"
            )
        # The mirror's phone path must reach the table: filter → digit gate →
        # transliterate → TRANSLIT_PAIRS. A textual check on each body would
        # false-positive on indirection (or miss it), so the CHAIN is what is
        # asserted: if any link stops consulting the generated table, the
        # native-direction checks below it are testing a filter the real
        # client never builds.
        chain = (
            ("customerSearchFilter", "customerPhoneDigitPattern("),
            ("customerPhoneDigitPattern", "transliterate("),
            ("transliterate", "TRANSLIT_PAIRS"),
        )
        for fn, needed in chain:
            if needed not in _function_body(probe, fn):
                failures.append(
                    f"probe: {fn}() no longer reaches TRANSLIT_PAIRS "
                    f"(missing {needed!r} in its body)"
                )

    if failures:
        print("VERIFY FAILED:")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    print(
        f"VERIFY OK: {len(blocks)} blocks agree across 065, the Dart mapping "
        f"and the probe (unicodedata {python_unicode_version()})"
    )


def main():
    if "--verify" in sys.argv:
        verify()
        return
    if "--apply" in sys.argv:
        apply()
        return

    blocks = nd_blocks()
    print(f"# unicodedata version: {python_unicode_version()}")
    print(f"# total Nd blocks (incl. ASCII): {len(blocks)}")
    print(f"# non-ASCII blocks to normalise: {len(sql_blocks())}")
    print()
    print("# SQL `translate` FROM table (all non-ASCII block bases):")
    print(f"#   '{sql_from_table()}'")
    print()
    print("# Dart block list (base, length):")
    for base, length in sql_blocks():
        print(f"#   (0x{base:04X}, {length}),")
    print()
    print("# Probe fixture rows (id, name, stored, digits):")
    for row in probe_fixture_rows():
        print("#  ", row)


if __name__ == "__main__":
    main()
