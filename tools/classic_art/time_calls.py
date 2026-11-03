"""最小 JASS 词法扫描：保留位置，屏蔽注释和字符串，不执行代码。"""
import re

TARGETS = ('SetFloatGameState', 'SetTimeOfDayScale', 'SuspendTimeOfDay')


def mask_source(source):
    """统一换行，屏蔽非代码字符，同时保留原始索引。"""
    source = source.replace('\r\n', '\n').replace('\r', '\n')
    result = list(source)
    index = 0
    while index < len(source):
        if source.startswith('//', index):
            end = source.find('\n', index)
            end = len(source) if end < 0 else end
            result[index:end] = ' ' * (end-index)
            index = end
        elif source[index] == '"':
            start = index
            index += 1
            while index < len(source) and source[index] != '"':
                if source[index] == '\n':
                    raise ValueError('字符串跨行或未闭合')
                index += 2 if source[index] == '\\' else 1
            if index >= len(source):
                raise ValueError('字符串未闭合')
            index += 1
            result[start:index] = ' ' * (index-start)
        else:
            index += 1
    return source, ''.join(result)


def extract_calls(source):
    """提取准确调用及词法条件栈；上下文不等于可达性证明。"""
    original, masked = mask_source(source)
    raw_lines = original.splitlines()
    function = ''
    conditions = []
    result = []
    offset = 0
    for number, line in enumerate(masked.splitlines(), 1):
        stripped = line.strip()
        declaration = re.match(r'function\s+(\w+)\s+takes\b', stripped)
        if declaration:
            function = declaration[1]
            conditions = []
        if re.match(r'if\b', stripped):
            conditions.append(raw_lines[number-1].strip())
        elif re.match(r'(elseif|else)\b', stripped):
            if not conditions:
                raise ValueError('条件分支缺少 if')
            conditions[-1] = conditions[-1].split(' → ')[0]+' → '+raw_lines[number-1].strip()
        elif stripped == 'endif':
            if not conditions:
                raise ValueError('endif 缺少 if')
            conditions.pop()
        for match in re.finditer(r'\bcall\s+('+'|'.join(TARGETS)+r')\s*\(', line):
            start = offset+match.start()
            cursor = offset+match.end()
            depth = 1
            while cursor < len(masked) and depth:
                depth += (masked[cursor] == '(')-(masked[cursor] == ')')
                cursor += 1
            if depth:
                raise ValueError('调用括号未闭合')
            result.append({'function': function or '全局/未归属', 'line': number,
                           'name': match[1], 'text': original[start:cursor],
                           'conditions': list(conditions)})
        if stripped == 'endfunction':
            if conditions:
                raise ValueError('函数条件未闭合')
            function = ''
        offset += len(line)+1
    if conditions:
        raise ValueError('条件未闭合')
    return result
