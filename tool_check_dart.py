"""
Static checks for the Dart sources, for when no Dart SDK is available.

Catches the three most common compile errors in hand-written Flutter:
  1. unbalanced brackets (string- and interpolation-aware)
  2. imports that do not resolve to a file
  3. a symbol from another project file used without importing that file

It is not a compiler. `flutter analyze` is still the real check.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.join(ROOT, "lib")
PKG = "nexusfarm"


def strip_code(src):
    """Returns code with strings and comments blanked, and bracket errors."""
    out = []
    stack = []          # brackets
    modes = ["code"]    # code | str
    quote = []          # quote spec per string mode
    i, n = 0, len(src)
    errors = []
    line = 1

    def push_str(q, raw):
        modes.append("str")
        quote.append((q, raw))

    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
        mode = modes[-1]

        if mode == "code":
            if src.startswith("//", i):
                j = src.find("\n", i)
                i = n if j == -1 else j
                continue
            if src.startswith("/*", i):
                j = src.find("*/", i + 2)
                line += src[i:j].count("\n")
                i = n if j == -1 else j + 2
                continue
            raw = False
            k = i
            if c == "r" and i + 1 < n and src[i + 1] in "'\"" and (i == 0 or not (src[i-1].isalnum() or src[i-1] == "_")):
                raw = True
                k = i + 1
            ch = src[k] if k < n else ""
            if ch in "'\"" and (raw or k == i):
                q = ch * 3 if src.startswith(ch * 3, k) else ch
                push_str(q, raw)
                i = k + len(q)
                out.append(" ")
                continue
            if c in "([{":
                stack.append((c, line))
                out.append(c)
            elif c in ")]}":
                if c == "}" and stack and stack[-1][0] == "${":
                    stack.pop()
                    modes.pop()  # back to string
                    i += 1
                    continue
                pairs = {")": "(", "]": "[", "}": "{"}
                if not stack or stack[-1][0] != pairs[c]:
                    errors.append(f"line {line}: unexpected '{c}'")
                else:
                    stack.pop()
                out.append(c)
            else:
                out.append(c)
            i += 1
        else:  # inside a string
            q, raw = quote[-1]
            if not raw and c == "\\":
                i += 2
                continue
            if src.startswith(q, i):
                modes.pop()
                quote.pop()
                i += len(q)
                continue
            if not raw and src.startswith("${", i):
                stack.append(("${", line))
                modes.append("code")
                i += 2
                continue
            if len(q) == 1 and c == "\n":
                errors.append(f"line {line}: unterminated string")
                modes.pop()
                quote.pop()
            i += 1

    for b, l in stack:
        errors.append(f"line {l}: unclosed '{b}'")
    if len(modes) > 1:
        errors.append("unterminated string at end of file")
    return "".join(out), errors


def dart_files():
    for base in ("lib", "test"):
        for dirpath, _, files in os.walk(os.path.join(ROOT, base)):
            for f in files:
                if f.endswith(".dart"):
                    yield os.path.join(dirpath, f)


def resolve(path, imp):
    if imp.startswith("package:" + PKG + "/"):
        return os.path.normpath(os.path.join(LIB, imp[len("package:" + PKG + "/"):]))
    if imp.startswith("package:") or imp.startswith("dart:"):
        return None
    return os.path.normpath(os.path.join(os.path.dirname(path), imp))


DEF_RE = re.compile(
    r"^(?:abstract\s+|sealed\s+|final\s+|base\s+)*(?:class|enum|extension|mixin|typedef)\s+([A-Za-z_]\w*)"
    r"|^(?:[A-Za-z_<>?,\s\[\]()]+?\s)?([a-z_]\w*)\s*(?:<[^>]*>)?\s*\(",
    re.M,
)
TOP_CONST_RE = re.compile(r"^(?:const|final)\s+(?:[\w<>?,\s]+\s)?([a-zA-Z_]\w*)\s*=", re.M)


KEYWORDS = {
    "if", "for", "while", "switch", "return", "final", "const", "var",
    "void", "await", "async", "throw", "catch", "else", "new", "super",
    "this", "assert", "late", "static", "get", "set", "import", "export",
    "part", "library", "class", "enum", "extension", "mixin", "typedef",
    "abstract", "main", "try", "do", "case", "default", "print",
}


def top_level_symbols(code):
    """Names declared at column 0: classes, enums, top-level functions
    and top-level constants. Indented lines are members, not symbols."""
    names = set()
    for m in re.finditer(r"^(?:abstract\s+|sealed\s+)?(?:class|enum|mixin|typedef)\s+([A-Za-z_]\w*)", code, re.M):
        names.add(m.group(1))
    for m in re.finditer(r"^extension\s+([A-Za-z_]\w*)\s+on\b", code, re.M):
        names.add("ext:" + m.group(1))
    for m in re.finditer(r"^(?:const|final)\s+(?:[\w<>?,]+\s+)?([a-zA-Z_]\w*)\s*=", code, re.M):
        names.add(m.group(1))
    # "Type name(" or "Future<X> name(" starting at column 0
    for m in re.finditer(r"^[A-Za-z_][\w<>?,() ]*?\s([a-z_]\w*)\s*(?:<[^>()]*>)?\(", code, re.M):
        if m.group(1) not in KEYWORDS:
            names.add(m.group(1))
    # "name(" at column 0 with no return type
    for m in re.finditer(r"^([a-z_]\w*)\s*\(", code, re.M):
        if m.group(1) not in KEYWORDS:
            names.add(m.group(1))
    return names


def main():
    problems = 0
    sources = {}
    for p in dart_files():
        src = open(p, encoding="utf-8").read()
        code, errs = strip_code(src)
        sources[p] = (src, code)
        rel = os.path.relpath(p, ROOT)
        for e in errs:
            print(f"BRACKETS {rel}: {e}")
            problems += 1

    # symbol table
    defined_in = {}
    for p, (src, code) in sources.items():
        if not p.startswith(LIB):
            continue
        for name in top_level_symbols(code):
            defined_in.setdefault(name, set()).add(p)

    # imports and cross-file usage
    for p, (src, code) in sources.items():
        rel = os.path.relpath(p, ROOT)
        imported = {p}
        for imp in re.findall(r"^import\s+'([^']+)'", src, re.M):
            target = resolve(p, imp)
            if target is None:
                continue
            if not os.path.isfile(target):
                print(f"IMPORT   {rel}: '{imp}' does not resolve")
                problems += 1
            imported.add(target)

        # declared names inside this file shadow project symbols
        local = top_level_symbols(code)
        for name, files in defined_in.items():
            # Names starting with "_" are private to their own file in
            # Dart, so they can never be imported or clash across files.
            if name.startswith("ext:") or name.startswith("_") or name in local:
                continue
            if len(name) < 4:
                continue
            if not re.search(r"(?<![\w.$])" + re.escape(name) + r"\b", code):
                continue
            if files & imported:
                continue
            # skip obvious false positives: members accessed via a dot are
            # handled by the regex lookbehind; named args end with ':'
            uses = [m for m in re.finditer(r"(?<![\w.$])" + re.escape(name) + r"\b(?!\s*:)", code)]
            if not uses:
                continue
            where = ", ".join(sorted(os.path.relpath(f, ROOT) for f in files))
            print(f"SYMBOL   {rel}: uses '{name}' but does not import {where}")
            problems += 1

    print()
    print(f"{len(sources)} files checked, {problems} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
