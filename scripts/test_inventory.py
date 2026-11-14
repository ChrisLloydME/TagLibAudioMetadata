"""Bind required runtime names to a reviewed source file and enclosing suite.

Swift Testing's text log omits suite identities on individual test lines.
Reject source collisions/moves before accepting that name-based evidence.
"""
import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = Path(__file__).with_name('required-test-inventory.json')


def declarations(root):
    spec = importlib.util.spec_from_file_location('swift_api_inventory', Path(__file__).with_name('generate-api-reference.py'))
    parser = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(parser)
    parser.SOURCE_DIR = Path(root).resolve()
    found = {}
    tokens_pattern = re.compile(r'""".*?"""|"(?:\\.|[^"\\])*"|[A-Za-z_]\w*|[{}]', re.S)
    for path in parser.SOURCE_DIR.rglob('*.swift'):
        tokens = [t.group() for t in tokens_pattern.finditer(parser.strip_comments(path.read_text()))
                  if not t.group().startswith('"')]
        stack = []
        pending_type = None
        for index, token in enumerate(tokens):
            following = tokens[index + 1] if index + 1 < len(tokens) else None
            if token in ('struct', 'class', 'enum', 'actor', 'extension', 'protocol') and following not in ('func', 'var', 'let'):
                pending_type = following
            elif token == 'func' and following:
                owner = next((name for name in reversed(stack) if name is not None), '<top>')
                found.setdefault(following, []).append({'suite': owner, 'path': path.relative_to(parser.SOURCE_DIR).as_posix()})
            elif token == '{':
                stack.append(pending_type)
                pending_type = None
            elif token == '}':
                if stack:
                    stack.pop()
                pending_type = None

    return found


def validate(root=None, manifest=None):
    expected = json.loads(MANIFEST.read_text()) if manifest is None else manifest
    actual = declarations(root or ROOT / 'Tests/TagLibAudioMetadataTests')
    return [{'test': name, 'expected': owner, 'actual': actual.get(name, [])}
            for name, owner in expected.items() if actual.get(name) != [owner]]
