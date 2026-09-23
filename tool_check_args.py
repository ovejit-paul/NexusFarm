"""Checks named arguments at every call of a project class or function
against the parameters it actually declares."""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tool_check_dart import strip_code, dart_files

def matching(code, i, open_c="(", close_c=")"):
    depth = 0
    for j in range(i, len(code)):
        if code[j] in "([{": depth += 1
        elif code[j] in ")]}":
            depth -= 1
            if depth == 0: return j
    return -1

def top_level_split(s):
    parts, depth, cur = [], 0, ""
    for ch in s:
        if ch in "([{": depth += 1
        elif ch in ")]}": depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur); cur = ""
        else:
            cur += ch
    if cur.strip(): parts.append(cur)
    return parts

def named_params(param_text):
    m = re.search(r"\{", param_text)
    if not m: return set(), False
    inner = param_text[m.start()+1:param_text.rfind("}")]
    names = set()
    for p in top_level_split(inner):
        p = p.strip()
        if not p: continue
        p = re.sub(r"=.*$", "", p, flags=re.S).strip()
        mm = re.search(r"(?:this|super)\.(\w+)$", p) or re.search(r"(\w+)$", p)
        if mm: names.add(mm.group(1))
    return names, True

sigs = {}   # name -> (set of named params, has_named_section)
files = {p: strip_code(open(p, encoding='utf-8').read())[0] for p in dart_files()}

for p, code in files.items():
    if "/lib/" not in p: continue
    # constructors: "Name({" or "const Name({" inside a class body
    for m in re.finditer(r"\b(?:const\s+)?([A-Z]\w*)\s*\((?=\s*\{)", code):
        name = m.group(1)
        # only if a class of that name is declared in this file
        if not re.search(r"^(?:abstract\s+)?class\s+" + name + r"\b", code, re.M): continue
        end = matching(code, m.end()-1)
        if end < 0: continue
        params, has = named_params(code[m.end():end])
        sigs[name] = (params | sigs.get(name, (set(), False))[0], True)
    # top-level functions with named params
    for m in re.finditer(r"^[A-Za-z_][\w<>?,() ]*?\s([a-z_]\w*)\s*\(", code, re.M):
        name = m.group(1)
        end = matching(code, m.end()-1)
        if end < 0: continue
        params, has = named_params(code[m.end():end])
        if has: sigs[name] = (params, True)

problems = 0
for p, code in files.items():
    rel = os.path.relpath(p)
    for name, (params, _) in sigs.items():
        for m in re.finditer(r"(?<![\w.])" + re.escape(name) + r"\s*\(", code):
            # skip the declaration itself
            before = code[max(0, m.start()-40):m.start()]
            if re.search(r"(class|enum)\s+$", before): continue
            end = matching(code, m.end()-1)
            if end < 0: continue
            args = code[m.end():end]
            if args.lstrip().startswith("{"): continue  # declaration
            for a in top_level_split(args):
                mm = re.match(r"\s*(\w+)\s*:(?!:)", a)
                if mm and mm.group(1) not in params:
                    line = code[:m.start()].count("\n") + 1
                    print(f"ARG      {rel}:{line}: {name}(...) has no parameter '{mm.group(1)}'  (known: {sorted(params)})")
                    problems += 1

print(f"\n{len(sigs)} signatures, {problems} problem(s)")
sys.exit(1 if problems else 0)
