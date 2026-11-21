#!/usr/bin/env python3
"""묶음 79: 나누기 전(git HEAD)과 뒤(원래 파일 + part 파일들)의 줄이 같은지 (빈 줄 · part 지시문 빼고)."""
import collections, os, re, subprocess, sys

path = sys.argv[1]
before = subprocess.run(['git', 'show', f'HEAD:{path}'], capture_output=True, text=True, check=True).stdout
def lines(t):
    return collections.Counter(l for l in t.split('\n') if l.strip() and not re.match(r"^part (of )?'", l))
after_main = open(path, encoding='utf-8').read()
parts = re.findall(r"^part '([^']+)';", after_main, re.M)
txt = after_main
for p in parts:
    txt += '\n' + open(os.path.join(os.path.dirname(path), p), encoding='utf-8').read()
a, b = lines(before), lines(txt)
if a == b:
    print(f'같음 · {path} ({len(parts)}개 part)')
else:
    print(f'다름 · {path}')
    print(' 빠진 줄:', list((a - b).items())[:10])
    print(' 더한 줄:', list((b - a).items())[:10])
    sys.exit(1)
