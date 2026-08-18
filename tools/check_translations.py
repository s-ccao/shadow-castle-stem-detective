"""Report which player-facing lines still lack a Chinese translation.

Run from the repository root:   python3 tools/check_translations.py [--list]

Exits non-zero if a translation is stale (its English no longer appears) or
broken (format specifiers, BBCode tags or line breaks do not match the
original), which is what CI gates on. A low coverage percentage is reported
but never fails the build -- translation is incremental.

Extracts every string literal that reaches a translating sink
(present_feedback / show_message / set_dialogue_text / a clue title or
content / an INTERACT_ITEMS message) and checks it against CaseScriptZh.LINES.

Also fails on translations whose key no longer appears anywhere in the
source, which is how a table like this rots: the English gets reworded and
the Chinese silently stops being used.
"""
import glob
import re
import sys

SRC = sorted(
    glob.glob('scripts/**/*.gd', recursive=True)
    + glob.glob('autoload/*.gd')
    + glob.glob('scenes/**/*.gd', recursive=True)
)
SRC = [p for p in SRC if not p.endswith('case_script_zh.gd')]


def gd_string_literals(text):
    """Yield (literal, start, end) for every GDScript string.

    Adjacent literals joined by `+` are folded into the single string the
    engine produces at runtime. Almost all the long prose in this project is
    written as a parenthesised chain of concatenated literals, so an
    extractor that treats each fragment separately sees strings that never
    exist at runtime and misses every one that does.
    """
    out = []
    i = 0
    while i < len(text):
        if text[i] == '"':
            parts = []
            first_start = i
            last_end = i
            while True:
                j = i + 1
                buf = []
                while j < len(text):
                    if text[j] == '\\':
                        buf.append(text[j:j + 2])
                        j += 2
                        continue
                    if text[j] == '"':
                        break
                    buf.append(text[j])
                    j += 1
                parts.append(''.join(buf))
                last_end = j
                # look past whitespace/newlines/comments for a `+ "`
                k = j + 1
                while k < len(text):
                    if text[k] in ' \t\r\n':
                        k += 1
                    elif text[k] == '#':
                        k = text.find('\n', k)
                        if k == -1:
                            k = len(text)
                    else:
                        break
                if k < len(text) and text[k] == '+':
                    k += 1
                    while k < len(text) and text[k] in ' \t\r\n':
                        k += 1
                    if k < len(text) and text[k] == '"':
                        i = k
                        continue
                break
            out.append((''.join(parts), first_start, last_end))
            i = last_end + 1
            continue
        if text[i] == '#':                       # skip comments
            i = text.find('\n', i)
            if i == -1:
                break
        i += 1
    return out


SINK_CALL = re.compile(
    r'(?:present_feedback|show_message|set_dialogue_text|show_parchment|_show_dining_note|_show_note|add_clue)\s*\(')
FIELD = re.compile(r'"(?:message|title|content)"\s*:\s*$')

# A player-facing line is a sentence, not an id or a resource path.
def looks_like_prose(s):
    if len(s) < 12:
        return False
    if s.startswith('res://') or s.startswith('user://'):
        return False
    if re.fullmatch(r'[a-z0-9_./]+', s):
        return False
    if not re.search(r'[A-Za-z]{3}', s):
        return False
    return ' ' in s.strip()


found = {}     # english -> set of files
for path in SRC:
    text = open(path, encoding='utf-8').read()
    lits = gd_string_literals(text)
    for lit, start, end in lits:
        if not looks_like_prose(lit):
            continue
        before = text[max(0, start - 260):start]
        # inside a sink call, or the value of a message/title/content key
        if SINK_CALL.search(before.replace('\n', ' ')) or FIELD.search(
                before.rstrip().rstrip('\n').rstrip() + ''):
            found.setdefault(lit, set()).add(path)
            continue
        tail = before.rstrip()
        if re.search(r'"(?:message|title|content)"\s*:\s*(?:\(\s*)?$', tail):
            found.setdefault(lit, set()).add(path)

zh_src = open('scripts/case_script_zh.gd', encoding='utf-8').read()
i = zh_src.index('const LINES')
i = zh_src.index('{', i)
depth = 0
for p in range(i, len(zh_src)):
    if zh_src[p] == '{':
        depth += 1
    elif zh_src[p] == '}':
        depth -= 1
        if depth == 0:
            end = p + 1
            break
table = zh_src[i:end]
keys = {lit for lit, _s, _e in gd_string_literals(table)}
# keys alternate with values; a key is any literal that is followed by ':'
translated = set()
for lit, s, e in gd_string_literals(table):
    after = table[e + 1:e + 3]
    if after.lstrip().startswith(':'):
        translated.add(lit)

untranslated = {k: v for k, v in found.items() if k not in translated}
stale = translated - set(found)

# A mistranslated format string is a runtime crash, not a cosmetic bug:
# GDScript's % operator errors if the specifiers do not match the arguments.
# Unbalanced BBCode is less severe but renders as visible garbage.
pairs = {}
lits = gd_string_literals(table)
for idx in range(len(lits) - 1):
    lit, s, e = lits[idx]
    if table[e + 1:e + 3].lstrip().startswith(':'):
        pairs[lit] = lits[idx + 1][0]

SPEC = re.compile(r'%[-+ 0-9.]*[dsfxX%]')
TAG = re.compile(r'\[(/?)(b|i|center|color)(?:=[^\]]*)?\]')
mismatch = []
for eng, zh in pairs.items():
    if SPEC.findall(eng) != SPEC.findall(zh):
        mismatch.append(
            f'format specifiers differ: {SPEC.findall(eng)} vs {SPEC.findall(zh)}'
            f'  <<{eng[:60]}>>')
    if [t for t in TAG.findall(eng)] != [t for t in TAG.findall(zh)]:
        mismatch.append(f'BBCode tags differ  <<{eng[:60]}>>')
    if zh.count('\\n') != eng.count('\\n'):
        mismatch.append(
            f'line breaks differ ({eng.count(chr(92) + "n")} vs '
            f'{zh.count(chr(92) + "n")})  <<{eng[:60]}>>')
    if not zh.strip():
        mismatch.append(f'empty translation  <<{eng[:60]}>>')

total = len(found)
done = total - len(untranslated)
pct = (done / total * 100.0) if total else 100.0
print(f'player-facing lines reaching a sink: {total}')
print(f'translated: {done}  ({pct:.0f}%)')
print(f'remaining:  {len(untranslated)}')

if stale:
    print(f'\nSTALE: {len(stale)} translation(s) whose English no longer appears:')
    for s in sorted(stale)[:10]:
        print('  -', s[:90])

if mismatch:
    print(f'\nBROKEN: {len(mismatch)} translation(s) that would misrender or crash:')
    for m in mismatch:
        print('  -', m)

if '--list' in sys.argv:
    by_file = {}
    for eng, files in untranslated.items():
        by_file.setdefault(sorted(files)[0], []).append(eng)
    for path in sorted(by_file):
        print(f'\n### {path}  ({len(by_file[path])})')
        for eng in sorted(by_file[path]):
            print(f'  {eng}')

sys.exit(1 if (stale or mismatch) else 0)
