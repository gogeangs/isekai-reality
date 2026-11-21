#!/usr/bin/env python3
"""묶음 79: 큰 Dart 파일을 `part` 파일로 나눈다 (옮기기만, 내용은 그대로).

쓰는 법:
  python3 tool/split_dart.py list <파일>            # 맨 위 선언 목록 (줄 · 이름)
  python3 tool/split_dart.py split <파일> <spec.json>

spec.json: {"<part 파일 이름(같은 폴더 기준 상대 경로)>": ["선언 이름 정규식", ...], ...}
정해지지 않은 선언은 원래 파일에 남는다. 선언 바로 위 주석 · 애너테이션은 그 선언과 함께 옮긴다.
원래 파일이 이미 `part of` 이면 쓸 수 없다 (부모 라이브러리에 part 를 더해야 해서).
"""
import json
import os
import re
import sys


def tokens_depth(lines):
    """줄마다 (줄을 시작할 때 깊이, 줄을 끝낼 때 깊이)를 센다. 문자열 · 주석 안 괄호는 셈하지 않는다."""
    depth = 0
    out = []
    in_block = False  # /* */
    str_stack = []  # 열린 문자열 종류 (따옴표, 세 겹 여부, raw)
    interp = []  # ${ 안 깊이
    for line in lines:
        start = depth
        i = 0
        n = len(line)
        while i < n:
            ch = line[i]
            if in_block:
                if line.startswith('*/', i):
                    in_block = False
                    i += 2
                    continue
                i += 1
                continue
            if str_stack and str_stack[-1] is not None:
                q, triple, raw = str_stack[-1]
                if not raw and ch == '\\':
                    i += 2
                    continue
                if not raw and line.startswith('${', i):
                    interp.append(depth)
                    depth += 1
                    str_stack.append(None)  # 표시: 보간 중
                    i += 2
                    continue
                if triple and line.startswith(q * 3, i):
                    str_stack.pop()
                    i += 3
                    continue
                elif not triple and ch == q:
                    str_stack.pop()
                    i += 1
                    continue
                i += 1
                continue
            # 코드
            if line.startswith('//', i):
                break
            if line.startswith('/*', i):
                in_block = True
                i += 2
                continue
            raw = False
            if ch in 'rR' and i + 1 < n and line[i + 1] in '\'"' and (i == 0 or not (line[i - 1].isalnum() or line[i - 1] == '_')):
                raw = True
                i += 1
                ch = line[i]
            if ch in '\'"':
                if line.startswith(ch * 3, i):
                    str_stack.append((ch, True, raw))
                    i += 3
                else:
                    str_stack.append((ch, False, raw))
                    i += 1
                continue
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if interp and depth == interp[-1]:
                    interp.pop()
                    # 보간 끝: 문자열로 돌아감
                    if str_stack and str_stack[-1] is None:
                        str_stack.pop()
            i += 1
        # 한 줄 문자열이 줄 끝에서 닫히지 않았으면 (있을 수 없음) 그대로
        out.append((start, depth))
    return out


DECL = re.compile(
    r'^(?:abstract\s+|sealed\s+|final\s+|base\s+|mixin\s+)*'
    r'(?:class|enum|mixin|extension|typedef)\s+([A-Za-z_][A-Za-z0-9_]*)'
)
FUNC = re.compile(r'^[A-Za-z_<>,?\s\[\]().]*?\b([A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^>]*>)?\s*\(')
VAR = re.compile(r'^(?:const|final|var|late)\s+(?:[A-Za-z_<>,?\s\[\]().]+\s)?([A-Za-z_][A-Za-z0-9_]*)\s*=')
VAR2 = re.compile(r'^[A-Za-z_][A-Za-z0-9_<>,?\s\[\]().]*\s([A-Za-z_][A-Za-z0-9_]*)\s*=')


def decls(lines):
    """맨 위 선언: [(첫 줄(주석 포함), 끝 줄, 이름)] (0부터). 머리(import · part)는 빼고."""
    d = tokens_depth(lines)
    out = []
    i = 0
    n = len(lines)
    head_end = 0
    for k, l in enumerate(lines):
        s = l.strip()
        if s.startswith(('import ', 'export ', 'part ', 'library ')) or (s.startswith('part of')):
            head_end = k + 1
            # 여러 줄 import
            j = k
            while not lines[j].rstrip().endswith(';'):
                j += 1
            head_end = j + 1
    i = head_end
    while i < n:
        s = lines[i]
        if d[i][0] != 0 or not s.strip():
            i += 1
            continue
        # 주석 · 애너테이션은 다음 선언에 붙인다
        first = i
        while i < n and (lines[i].startswith('//') or lines[i].startswith('@') or lines[i].startswith('/*')):
            if lines[i].startswith('/*'):
                while '*/' not in lines[i]:
                    i += 1
            i += 1
        if i >= n:
            break
        if not lines[i].strip():
            # 떨어진 주석 덩어리: 따로 (원래 자리에 남김)
            out.append((first, i - 1, None))
            continue
        name = None
        st = lines[i]
        m = DECL.match(st)
        if m:
            name = m.group(1)
        else:
            m = VAR.match(st) or VAR2.match(st)
            if m and '(' not in st.split('=')[0]:
                name = m.group(1)
            else:
                m = FUNC.match(st)
                if m:
                    name = m.group(1)
        # 끝: 깊이가 0으로 돌아오고 ; 또는 } 로 끝나는 줄
        j = i
        while j < n:
            if d[j][1] == 0 and lines[j].rstrip().endswith((';', '}')):
                break
            j += 1
        out.append((first, j, name))
        i = j + 1
    return head_end, out


def cmd_list(path):
    lines = open(path, encoding='utf-8').read().split('\n')
    _, ds = decls(lines)
    for a, b, name in ds:
        print(f'{a + 1:5d}-{b + 1:5d} {b - a + 1:5d}  {name}')


def cmd_split(path, spec_path):
    spec = json.load(open(spec_path, encoding='utf-8'))
    src = open(path, encoding='utf-8').read()
    lines = src.split('\n')
    if any(l.startswith('part of') for l in lines):
        sys.exit('이미 part of 인 파일')
    head_end, ds = decls(lines)
    pats = {part: [re.compile(p) for p in ps] for part, ps in spec.items()}
    taken = {}
    for a, b, name in ds:
        if name is None:
            continue
        for part, ps in pats.items():
            if any(p.fullmatch(name) for p in ps):
                taken.setdefault(part, []).append((a, b, name))
                break
    moved = set()
    base = os.path.basename(path)
    folder = os.path.dirname(path)
    for part, blocks in taken.items():
        rel_back = os.path.relpath(path, os.path.dirname(os.path.join(folder, part)))
        body = [f"part of '{rel_back}';", '']
        for a, b, name in sorted(blocks):
            # 바로 앞 빈 줄 하나는 남김
            body.extend(lines[a:b + 1])
            body.append('')
            moved.update(range(a, b + 1))
        out = os.path.join(folder, part)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, 'w', encoding='utf-8') as f:
            f.write('\n'.join(body).rstrip('\n') + '\n')
        print(f'{part}: {len(blocks)}개 · {len(body)}줄')
    keep = [l for k, l in enumerate(lines) if k not in moved]
    # 빈 줄 여러 개를 하나로
    cleaned = []
    for l in keep:
        if not l.strip() and cleaned and not cleaned[-1].strip():
            continue
        cleaned.append(l)
    # part 지시문: 머리 끝에
    hk = 0
    for k, l in enumerate(cleaned):
        s = l.strip()
        if s.startswith(('import ', 'export ', 'part ', 'library ')):
            j = k
            while not cleaned[j].rstrip().endswith(';'):
                j += 1
            hk = j + 1
    parts = [f"part '{p}';" for p in taken]
    cleaned[hk:hk] = [''] + parts
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(cleaned))
    print(f'{base}: {len(lines)} → {len(cleaned)}줄')


if __name__ == '__main__':
    if sys.argv[1] == 'list':
        cmd_list(sys.argv[2])
    else:
        cmd_split(sys.argv[2], sys.argv[3])
