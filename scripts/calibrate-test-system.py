#!/usr/bin/env python3
"""Compile-and-activate mutations against the actual required package tests."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import time
import uuid
import test_manifest

ROOT = Path(__file__).resolve().parents[1]
MUTANTS = ROOT / 'scripts/calibration-mutants.json'
IGNORED = {'.build', '.git', '.swiftpm', '.local', '__pycache__', 'DerivedData'}


def select_mutants(rows, names, require_all=False, allow_failures=False):
    ids = [row['id'] for row in rows]
    if len(ids) != len(set(ids)): raise ValueError('duplicate mutant definitions')
    if set(names) - set(ids): raise ValueError('unknown mutant selector')
    selected = [row for row in rows if not names or row['id'] in names]
    if require_all and (allow_failures or {row['id'] for row in selected} != set(ids)):
        raise ValueError('--require-all-killed forbids subsets and --allow-failures')
    return selected


def run(command, cwd, log, timeout=900):
    env = os.environ.copy()
    for name in ('TAGLIB_TEST_EVIDENCE_DIR', 'TAGLIB_CAMPAIGN_ID', 'TAGLIB_CAMPAIGN_MODE',
                 'TAGLIB_CAMPAIGN_SOURCE_HASH', 'TAGLIB_WRITE_CLAIMS'):
        env.pop(name, None)
    with log.open('w') as stream:
        process = subprocess.Popen(command, cwd=cwd, env=env, stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try: process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL); process.wait()
            return 124, log.read_text(errors='replace')
    return code, log.read_text(errors='replace')


def apply_patches(package, patches):
    originals, staged = {}, {}
    for patch in patches:
        target = (package / patch['file']).resolve()
        if package.resolve() not in target.parents: raise ValueError('patch escapes package')
        original = target.read_bytes()
        originals.setdefault(target, original)
        text = staged.get(target, original.decode())
        if text.count(patch['find']) != 1: raise ValueError('patch anchor is not unique: ' + patch['file'])
        staged[target] = text.replace(patch['find'], patch['replace'], 1)
    try:
        for target, text in staged.items(): target.write_text(text)
    except BaseException:
        restore(originals); raise
    return originals, {str(p.relative_to(package)): hashlib.sha256(p.read_bytes()).hexdigest() for p in staged}


def restore(originals):
    for path, content in originals.items(): path.write_bytes(content)
    return all(path.read_bytes() == content for path, content in originals.items())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--mutant', action='append', default=[])
    parser.add_argument('--require-all-killed', action='store_true')
    parser.add_argument('--allow-failures', action='store_true')
    parser.add_argument('--run-id')
    args = parser.parse_args()
    rows = json.loads(MUTANTS.read_text())['mutants']
    try:
        selected = select_mutants(rows, args.mutant, args.require_all_killed, args.allow_failures)
        if args.require_all_killed and args.list: raise ValueError('listing is not calibration')
        run_id = args.run_id or time.strftime('%Y%m%dT%H%M%S') + '-' + uuid.uuid4().hex[:8]
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,100}', run_id): raise ValueError('unsafe run id')
        if os.environ.get('TAGLIB_WRITE_CLAIMS') == '1': raise ValueError('claim blessing is forbidden')
    except ValueError as error:
        parser.error(str(error))
    if args.list:
        for row in selected: print(row['id'])
        return 0
    source_hash = test_manifest.current_source_hash()
    workspace = ROOT / '.build/test-calibration' / run_id
    workspace.mkdir(parents=True, exist_ok=False)
    package = workspace / 'package'
    shutil.copytree(ROOT, package, ignore=lambda _, names: set(names) & IGNORED, symlinks=True)
    artifacts = ROOT / '.build/artifacts'
    if artifacts.exists():
        shutil.copytree(artifacts, package / '.build/artifacts', symlinks=True)
    logs = workspace / 'logs'; logs.mkdir()
    options = ['--package-path', str(package), '--disable-sandbox', '--disable-keychain', '--disable-netrc',
               '-Xswiftc', '-warnings-as-errors', '-Xcc', '-Werror']
    build_command = ['swift', 'build', '--build-tests', *options]
    filters = '|'.join(sorted({row['test_filter'] for row in selected}))
    def execute(test_filter, log):
        return run(['swift', 'test', '--skip-build', *options, '--filter', test_filter], package, log, 180)
    result = {'schema_version': 2, 'source_hash': source_hash,
              'commit': test_manifest._git('rev-parse', 'HEAD'), 'runner': 'canonical-package-tests',
              'definition_hash': hashlib.sha256(MUTANTS.read_bytes()).hexdigest(),
              'expected_mutant_ids': [row['id'] for row in rows], 'mutants': [], 'acceptance': 'failed'}
    report = workspace / 'calibration.json'
    def save(): report.write_text(json.dumps(result, indent=2) + '\n')
    build_code, _ = run(build_command, package, logs / 'control-build.log')
    control_code, control_text = execute(filters, logs / 'control-run.log') if build_code == 0 else (2, '')
    def completed_controls(text):
        return all(re.search(r'\bTest ' + re.escape(row['test_filter']) + r'\([^\n]*\)(?: with \d+ test cases?)? passed\b', text)
                   for row in selected)
    result['control'] = {'build_exit_status': build_code, 'exit_status': control_code,
                         'named_tests_passed': completed_controls(control_text)}
    if control_code != 0 or not result['control']['named_tests_passed']:
        result['reason'] = 'unmutated canonical tests failed'; save(); print(report); return 2
    for row in selected:
        detail = {'id': row['id'], 'test_filter': row['test_filter'], 'status': 'inconclusive', 'restored': False}
        originals = {}
        try:
            originals, fingerprints = apply_patches(package, row['patches'])
            detail['fingerprints'] = fingerprints
            build_code, _ = run(build_command, package, logs / (row['id'] + '-build.log'))
            detail['build_exit_status'] = build_code
            if build_code == 0:
                code, output = execute(row['test_filter'], logs / (row['id'] + '-test.log'))
                failed = re.search(r'\bTest ' + re.escape(row['test_filter']) + r'\([^\n]*\)(?: with \d+ test cases?)? failed\b', output)
                completed = re.search(r'Test run with \d+ tests? in \d+ suites? failed\b', output)
                witness = row['witness'] in output
                detail.update({'exit_status': code, 'activation_witness': [line for line in output.splitlines()
                    if row['witness'] in line][:8], 'named_failure': bool(failed)})
                if code == 1 and failed and completed and witness:
                    detail['status'] = 'killed'
                elif code == 0: detail['status'] = 'survived'
            else: detail['reason'] = 'mutant did not compile'
        except (ValueError, OSError) as error:
            detail['reason'] = str(error)
        finally:
            detail['restored'] = restore(originals)
        result['mutants'].append(detail); save()
        print(row['id'], detail['status'], flush=True)
        if detail['status'] != 'killed' or not detail['restored']: break
    final_build, _ = run(build_command, package, logs / 'control-final-build.log')
    final_code, final_text = execute(filters, logs / 'control-final-test.log') if final_build == 0 else (2, '')
    result['control']['final_exit_status'] = final_code
    result['control']['final_build_exit_status'] = final_build
    result['control']['final_named_tests_passed'] = completed_controls(final_text)
    result['source_restored'] = test_manifest.current_source_hash() == source_hash
    complete = {d['id'] for d in result['mutants']} == {row['id'] for row in rows}
    killed = len(result['mutants']) == len(selected) and all(d['status'] == 'killed' and d['restored'] for d in result['mutants'])
    ok = killed and final_build == 0 and final_code == 0 and result['control']['final_named_tests_passed'] and result['source_restored']
    result['acceptance'] = ('accepted' if complete else 'partial') if ok else 'failed'
    save(); print('Calibration evidence:', report)
    return 0 if ok or (args.allow_failures and not args.require_all_killed) else 1


if __name__ == '__main__':
    raise SystemExit(main())
