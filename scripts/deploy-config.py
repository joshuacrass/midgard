#!/usr/bin/env python3
"""Compare before writing; preserve conflicts unless explicitly requested."""
import argparse
import datetime
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--mode', choices=['dry-run', 'apply'], default='dry-run')
    parser.add_argument('--replace', action='store_true')
    parser.add_argument('--merge-json', action='store_true')
    args = parser.parse_args()
    src, dst = args.source, args.destination
    data = src.read_bytes()
    if any(p.is_symlink() for p in [dst, *dst.parents]):
        raise SystemExit(f'Refusing symlink destination: {dst}')
    exists = dst.exists()
    if exists and not dst.is_file():
        raise SystemExit(f'Not a regular file: {dst}')
    if args.merge_json:
        desired = json.loads(data)
        if exists:
            existing = json.loads(dst.read_bytes())
            desired = merge(existing, desired)
            if desired == existing:
                print(f'OK {dst}')
                return
        data = (json.dumps(desired, indent=2) + '\n').encode()
    mode = (dst if args.merge_json and exists else src).stat().st_mode & 0o777
    if exists and dst.read_bytes() == data and dst.stat().st_mode & 0o777 == mode:
        print(f'OK {dst}')
        return
    if exists and not args.replace:
        print(f'PRESERVE {dst}: differs; review before --replace-config')
        return
    print(f'{"BACKUP + UPDATE" if exists else "CREATE"} {dst}')
    if args.mode == 'dry-run':
        return
    if exists:
        root = Path.home() / '.local/state/midgard/backups'
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
        relative = dst.absolute().relative_to(Path.home())
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
