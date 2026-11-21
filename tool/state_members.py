#!/usr/bin/env python3
"""묶음 79: State 클래스에서 setState · @override 를 쓰지 않는 그리기 도우미 메서드 이름을 고른다 (extension 으로 옮길 후보)."""
import importlib.util, os, re, sys
_spec = importlib.util.spec_from_file_location('sm', os.path.join(os.path.dirname(__file__), 'split_members.py'))
sm = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(sm)
path, cls = sys.argv[1:3]
lines = open(path, encoding='utf-8').read().split('\n')
s, e, ms = sm.members(lines, cls)
out = []
for a, b, n, t in ms:
    text = '\n'.join(lines[a:b + 1])
    if not n or '@override' in text or 'setState(' in text: continue
    if t.startswith(('static', 'final', 'late', 'var', 'const', 'factory')): continue
    if '(' not in t.split('=>')[0] and ' get ' not in ' ' + t: continue  # 필드
    if re.match(r'^[A-Za-z_<>?,\s]+\s[A-Za-z_]\w*\s*(=|;)', t) and '=>' not in t and '(' not in t.split('=')[0]: continue
    out.append(n)
print(' '.join(re.escape(x) for x in out))
