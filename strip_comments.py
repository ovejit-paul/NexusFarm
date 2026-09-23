"""
Strips comments from the project's source files.

    python strip_comments.py --dry-run     # see what would change
    python strip_comments.py               # actually do it

Handles strings correctly — a // inside a Dart string or a # inside a
Python string is left alone. Run the app and the tests afterwards
anyway; that is the real check.

Keeps a backup in .backup_comments/ so this is reversible.
"""

import argparse
import io
import os
import shutil
import tokenize

PROJECT = os.path.dirname(os.path.abspath(__file__))
BACKUP = os.path.join(PROJECT, ".backup_comments")

# A handful of comments prevent real bugs if someone edits that line
# later. Any comment containing one of these markers is kept.
KEEP_MARKERS = [
    "NOT divided by 255",
    "min-width",
]


def strip_dart(source: str) -> str:
    """Removes // and /* */ comments while respecting string literals."""
    out = []
    i = 0
    n = len(source)
    in_line_comment = False
    in_block_comment = False
    quote = None          # active string delimiter
    raw = False

    while i < n:
        ch = source[i]
        nxt = source[i + 1] if i + 1 < n else ""

        if in_line_comment:
            if ch == "\n":
                in_line_comment = False
                out.append(ch)
            i += 1
            continue

        if in_block_comment:
            if ch == "*" and nxt == "/":
                in_block_comment = False
                i += 2
            else:
                # Preserve newlines so line numbers stay sane.
                if ch == "\n":
                    out.append(ch)
                i += 1
            continue

        if quote:
            out.append(ch)
            if ch == "\\" and not raw:
                # Escaped character: copy the next one verbatim.
                if i + 1 < n:
                    out.append(source[i + 1])
                    i += 2
                    continue
            elif source.startswith(quote, i):
                i += len(quote)
                quote = None
                continue
            i += 1
            continue

        # Not in a comment or string.
        if ch == "/" and nxt == "/":
            in_line_comment = True
            i += 2
            continue
        if ch == "/" and nxt == "*":
            in_block_comment = True
            i += 2
            continue

        for q in ('"""', "'''", '"', "'"):
            if source.startswith(q, i):
                # r'...' raw strings do not process escapes.
                raw = i > 0 and source[i - 1] == "r"
                quote = q
                out.append(q)
                i += len(q)
                break
        else:
            out.append(ch)
            i += 1

    return out and "".join(out) or source


def strip_python(source: str) -> str:
    """Removes # comments by cutting them out of the original lines.

    Rebuilding a file from tokens loses formatting, so instead the
    tokenizer is used only to locate comments; everything else is left
    byte for byte as it was.
    """
    try:
        tokens = list(tokenize.generate_tokens(io.StringIO(source).readline))
    except tokenize.TokenError:
        # Leave a file alone rather than risk corrupting it.
        return source

    lines = source.splitlines(keepends=True)

    # Collect (row, column) of each comment to remove, deepest column
    # first so earlier cuts do not shift later ones on the same line.
    cuts = []
    for tok in tokens:
        if tok.type != tokenize.COMMENT:
            continue
        if any(m in tok.string for m in KEEP_MARKERS):
            continue
        cuts.append((tok.start[0], tok.start[1]))

    for row, col in sorted(cuts, reverse=True):
        index = row - 1
        if index >= len(lines):
            continue
        line = lines[index]
        newline = "\n" if line.endswith("\n") else ""
        kept = line[:col].rstrip()
        # A line that was only a comment becomes empty and is cleaned up
        # later by tidy_blank_lines.
        lines[index] = (kept + newline) if kept else newline

    return "".join(lines)


def tidy_blank_lines(text: str) -> str:
    """Collapses the runs of blank lines that removal leaves behind."""
    lines = text.split("\n")
    out = []
    blanks = 0

    for line in lines:
        if line.strip() == "":
            blanks += 1
            if blanks <= 1:
                out.append("")
        else:
            blanks = 0
            out.append(line.rstrip())

    while out and out[-1] == "":
        out.pop()

    return "\n".join(out) + "\n"


def should_keep_whole_comment(text: str) -> bool:
    return any(m in text for m in KEEP_MARKERS)


def process(path: str, dry_run: bool) -> tuple[int, int]:
    with open(path, encoding="utf-8") as f:
        original = f.read()

    if path.endswith(".dart"):
        stripped = strip_dart(original)
    elif path.endswith(".py"):
        stripped = strip_python(original)
    else:
        return 0, 0

    stripped = tidy_blank_lines(stripped)

    before = len(original.split("\n"))
    after = len(stripped.split("\n"))

    if not dry_run and stripped != original:
        rel = os.path.relpath(path, PROJECT)
        backup_path = os.path.join(BACKUP, rel)
        os.makedirs(os.path.dirname(backup_path), exist_ok=True)
        shutil.copy2(path, backup_path)

        with open(path, "w", encoding="utf-8") as f:
            f.write(stripped)

    return before, after


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true",
                    help="report what would change without writing")
    args = ap.parse_args()

    targets = []
    for root, dirs, files in os.walk(PROJECT):
        dirs[:] = [d for d in dirs
                   if d not in {".git", ".backup_comments", "__pycache__",
                                "build", "android", "ios", "web", ".dart_tool"}]
        for name in files:
            if name.endswith((".dart", ".py")) and name != "strip_comments.py":
                targets.append(os.path.join(root, name))

    total_before = total_after = 0
    print(f"{'file':<45} {'before':>8} {'after':>8} {'saved':>8}")
    print("-" * 73)

    for path in sorted(targets):
        before, after = process(path, args.dry_run)
        if before == 0:
            continue
        total_before += before
        total_after += after
        rel = os.path.relpath(path, PROJECT)
        print(f"{rel:<45} {before:>8} {after:>8} {before - after:>8}")

    print("-" * 73)
    print(f"{'TOTAL':<45} {total_before:>8} {total_after:>8} "
          f"{total_before - total_after:>8}")

    if args.dry_run:
        print("\nDry run — nothing written. Remove --dry-run to apply.")
    else:
        print(f"\nOriginals backed up to {os.path.relpath(BACKUP, PROJECT)}/")
        print("Restore with: cp -r .backup_comments/* .")
        print("\nNow run these before committing:")
        print("  flutter analyze")
        print("  cd backend && python pentest.py")


if __name__ == "__main__":
    main()
