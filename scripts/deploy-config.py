#!/usr/bin/env python3
"""Compare before writing; preserve conflicts unless explicitly requested."""
import argparse
import datetime
import difflib
import json
import os
from pathlib import Path
import shutil
import tempfile


def merge(existing, desired):
    if isinstance(existing, dict) and isinstance(desired, dict):
        result = dict(existing)
        for key, value in desired.items():
            result[key] = merge(result[key], value) if key in result else value
        return result
    if isinstance(existing, list) and isinstance(desired, list):
        return existing + [item for item in desired if item not in existing]
    return desired


def show_diff(dst, data, merge_json):
    if merge_json:
        print('  (JSON merge result not shown; compare the file by hand)')
        return
    try:
        old = dst.read_text().splitlines(keepends=True)
        new = data.decode().splitlines(keepends=True)
    except UnicodeDecodeError:
        print('  (binary content not shown)')
        return
    for line in difflib.unified_diff(old, new, f'{dst} (current)', f'{dst} (repository)'):
        print('  ' + line, end='' if line.endswith('\n') else '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--mode', choices=['dry-run', 'apply'], default='dry-run')
    parser.add_argument('--replace', action='store_true')
    parser.add_argument('--merge-json', action='store_true')
    # For files the application rewrites itself: seed once, private, never replaced.
    parser.add_argument('--create-only', action='store_true')
    # Show what PRESERVE hides. Plain text only: merged JSON may hold private local values.
    parser.add_argument('--diff', action='store_true')
    args = parser.parse_args()
    src, dst = args.source, args.destination
    data = src.read_bytes()
    if any(p.is_symlink() for p in [dst, *dst.parents]):
        raise SystemExit(f'Refusing symlink destination: {dst}')
    exists = dst.exists()
    if exists and not dst.is_file():
        raise SystemExit(f'Not a regular file: {dst}')
    if args.create_only and exists:
        print(f'KEEP {dst}: application-managed; created only when missing')
        return
    if args.merge_json:
        desired = json.loads(data)
        if exists:
            try:
                existing = json.loads(dst.read_bytes())
            except ValueError as error:
                raise SystemExit(f'Existing {dst} is not valid JSON ({error}); repair it before merging')
            desired = merge(existing, desired)
            if desired == existing:
                print(f'OK {dst}')
                return
        data = (json.dumps(desired, indent=2) + '\n').encode()
    mode = 0o600 if args.create_only else (dst if args.merge_json and exists else src).stat().st_mode & 0o777
    if exists and dst.read_bytes() == data and dst.stat().st_mode & 0o777 == mode:
        print(f'OK {dst}')
        return
    if exists and not args.replace:
        print(f'PRESERVE {dst}: differs; review before --replace-config')
        if args.diff:
            show_diff(dst, data, args.merge_json)
        return
    print(f'{"BACKUP + UPDATE" if exists else "CREATE"} {dst}')
    if args.mode == 'dry-run':
        return
    if exists:
        root = Path.home() / '.local/state/midgard/backups'
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
        try:
            relative = dst.absolute().relative_to(Path.home())
        except ValueError:
            raise SystemExit(f'Refusing to replace {dst}: backups cover files under {Path.home()} only')
        backup = root / stamp / relative
        backup.parent.mkdir(parents=True, mode=0o700)
        shutil.copy2(dst, backup)
        backup.chmod(0o600)
        print(f'Backup: {backup}')
    dst.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.midgard-', dir=dst.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            os.fchmod(stream.fileno(), mode)
        os.replace(tmp, dst)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


if __name__ == '__main__':
    main()
