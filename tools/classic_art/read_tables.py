"""只读 SLK 与单位文本配置，保留原字段和单位代码，不执行 JASS。"""
from pathlib import Path
import re


def slk(path):
    rows = {}
    x = y = 1
    for line in Path(path).read_text(encoding="utf-8-sig", errors="replace").splitlines():
        if not line.startswith("C;"):
            continue
        for axis, value in re.findall(r";([XY])(\d+)", line):
            if axis == "X": x = int(value)
            else: y = int(value)
        match = re.search(r";K(.*)$", line)
        if match:
            value = match.group(1)
            if value.startswith('"') and value.endswith('"'):
                value = value[1:-1].replace('""', '"')
            rows.setdefault(y, {})[x] = value
    header = rows.pop(1)
    return {row[1]: {header[column]: value for column, value in row.items() if column in header}
            for row in rows.values() if 1 in row}


def sections(path):
    result = {}
    current = None
    for line in Path(path).read_text(encoding="utf-8-sig", errors="replace").splitlines():
        line = line.strip()
        if line.startswith("//") or not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            current = result.setdefault(line[1:-1], {})
        elif current is not None and "=" in line:
            key, value = line.split("=", 1)
            current[key] = value
    return result
