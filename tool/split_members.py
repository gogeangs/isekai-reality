#!/usr/bin/env python3
"""묶음 79: 큰 클래스의 메서드 묶음을 같은 라이브러리의 part 파일 extension 으로 옮긴다 (옮기기만).

python3 tool/split_members.py list <파일> <클래스>
python3 tool/split_members.py move <파일> <클래스> <part 파일> <extension 이름> <이름 정규식>...
"""
import importlib.util, os, re, sys

_spec = importlib.util.spec_from_file_location('sd', os.path.join(os.path.dirname(__file__), 'split_dart.py'))
sd = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(sd)

NAME = re.compile(r'^\s*(?:static\s+|external\s+|@override\s+)*(?:[A-Za-z_<>,?\s\[\]().]*?\s)?(?:(?:get|set|operator)\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^>]*>)?\s*(?:\(|=>|\{|;|=)')


def members(lines, cls):
    d = sd.tokens_depth(lines)
    start = next(i for i, l in enumerate(lines) if re.match(rf'^(?:abstract\s+|final\s+)?class\s+{cls}\b', l))
    end = start
    while not (d[end][1] == 0 and lines[end].rstrip().endswith('}')):
        end += 1
    out = []
    i = start + 1
    while i < end:
        if d[i][0] == 1 and lines[i].strip() and lines[i].startswith('  ') and not lines[i].startswith('   '):
            first = i
            while lines[i].strip().startswith(('//', '@', '/*')):
                if lines[i].strip().startswith('/*'):
                    while '*/' not in lines[i]:
                        i += 1
                i += 1
            if not lines[i].strip():
                i += 1
                continue
            j = i
            while j < end and not (d[j][1] == 1 and lines[j].rstrip().endswith((';', '}'))):
                j += 1
            m = NAME.match(lines[i])
            out.append((first, j, m.group(1) if m else None, lines[i].strip()))
            i = j + 1
        else:
            i += 1
    return start, end, out


if __name__ == '__main__':
    cmd, path, cls = sys.argv[1:4]
    lines = open(path, encoding='utf-8').read().split('\n')
    s, e, ms = members(lines, cls)
    if cmd == 'list':
        for a, b, n, t in ms:
            print(f'{a+1:5d}-{b+1:5d} {b-a+1:4d} {n}  | {t[:70]}')
        sys.exit()
    part, ext = sys.argv[4:6]
    pats = [re.compile(p) for p in sys.argv[6:]]
    picked = [(a, b, n) for a, b, n, t in ms if n and any(p.fullmatch(n) for p in pats)
              and not t.startswith(('static', 'final', 'late', 'var', 'const', cls + '(', 'factory'))]
    moved = set()
    body = []
    for a, b, n in picked:
        body.extend(lines[a:b + 1]); body.append('')
        moved.update(range(a, b + 1))
    folder = os.path.dirname(path)
    out = os.path.join(folder, part)
    rel = os.path.relpath(path, os.path.dirname(out))
    exists = os.path.exists(out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'a' if exists else 'w', encoding='utf-8') as f:
        if not exists:
            f.write(f"part of '{rel}';\n\n")
        f.write(f'extension {ext} on {cls} {{\n' + '\n'.join(body).rstrip('\n') + '\n}\n')
    keep = [l for k, l in enumerate(lines) if k not in moved]
    cleaned = []
    for l in keep:
        if not l.strip() and cleaned and not cleaned[-1].strip():
            continue
        cleaned.append(l)
    if not exists:
        hk = 0
        for k, l in enumerate(cleaned):
            st = l.strip()
            if st.startswith(('import ', 'export ', 'part ', 'library ')):
                j = k
                while not cleaned[j].rstrip().endswith(';'):
                    j += 1
                hk = j + 1
        cleaned[hk:hk] = ['', f"part '{part}';"]
    open(path, 'w', encoding='utf-8').write('\n'.join(cleaned))
    print(f'{ext}: {len(picked)}개 · {len(body)}줄 → {part}')
