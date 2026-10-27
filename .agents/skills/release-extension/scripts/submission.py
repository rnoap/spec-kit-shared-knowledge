#!/usr/bin/env python3
"""Render the github/spec-kit Extension Submission for a published release.

  submission.py check --version X.Y.Z             validate; print the archive's SHA-256
  submission.py body  --version X.Y.Z [--update]  issue body, as the issue form writes it
  submission.py url   --version X.Y.Z [--update]  prefilled form URL to open in a browser

The release archive is downloaded and its own extension.yml is the reference: every
field of references/submission-template.md must agree with it, and with the catalog
bot's rules, or nothing is rendered. Pass --sha256 to assert the digest you expect.
"""
import argparse
import hashlib
import io
import json
import platform
import re
import subprocess
import sys
import urllib.parse
import urllib.request
import zipfile
from datetime import date
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit('submission.py needs PyYAML (the same python3 that runs validate-extension.sh)')

SKILL = Path(__file__).resolve().parent.parent
ROOT = SKILL.parents[1].parent
TEMPLATE = SKILL / 'references' / 'submission-template.md'
FORM = 'https://github.com/github/spec-kit/issues/new'
MAX_URL = 6500  # GitHub answers 500 above ~6,600 characters

# (template heading, heading in the issue body, form field id, render)
FIELDS = [
    ('Extension ID', 'Extension ID', 'extension-id', None),
    ('Extension Name', 'Extension Name', 'extension-name', None),
    ('Version', 'Version', 'version', None),
    ('Description', 'Description', 'description', None),
    ('Author', 'Author', 'author', None),
    ('Repository URL', 'Repository URL', 'repository', None),
    ('Download URL', 'Download URL', 'download-url', None),
    ('License', 'License', 'license', None),
    ('Homepage', 'Homepage (optional)', 'homepage', None),
    ('Documentation URL', 'Documentation URL (optional)', 'documentation', None),
    ('Changelog URL', 'Changelog URL (optional)', 'changelog', None),
    ('Required Spec Kit Version', 'Required Spec Kit Version', 'speckit-version', None),
    ('Required Tools', 'Required Tools (optional)', 'required-tools', 'markdown'),
    ('Number of Commands', 'Number of Commands', 'commands-count', None),
    ('Number of Hooks', 'Number of Hooks (optional)', 'hooks-count', None),
    ('Tags', 'Tags', 'tags', None),
    ('Key Features', 'Key Features', 'features', None),
]
TAIL = [
    ('Testing Details', 'Testing Details', 'testing-details', None),
    ('Example Usage', 'Example Usage', 'example-usage', 'markdown'),
    ('Proposed Catalog Entry', 'Proposed Catalog Entry', 'catalog-entry', 'json'),
    ('Additional Context', 'Additional Context', 'additional-context', None),
]
CHECKBOXES = [
    ('Testing Checklist', [
        'Extension installs successfully via download URL',
        'All commands execute without errors',
        'Documentation is complete and accurate',
        'No security vulnerabilities identified',
        'Tested on at least one real project']),
    ('Submission Requirements', [
        'Valid `extension.yml` manifest included',
        'README.md with installation and usage instructions',
        'LICENSE file included',
        'GitHub release created with version tag',
        'All command files exist and are properly formatted',
        'Extension ID follows naming conventions (lowercase-with-hyphens)']),
]

problems = []


def expect(cond, msg):
    if not cond:
        problems.append(msg)


def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'release-extension-skill'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def specify_version():
    try:
        out = subprocess.run(['specify', 'version'], capture_output=True, text=True, timeout=30).stdout
        m = re.search(r'CLI Version\s+(\S+)', out)
        return m.group(1) if m else 'unknown'
    except (OSError, subprocess.SubprocessError):
        return 'unknown'


def tested_on():
    system = platform.system()
    if system == 'Darwin':
        system = f'macOS {platform.mac_ver()[0]}'
    elif system == 'Linux':
        try:
            system = platform.freedesktop_os_release().get('PRETTY_NAME', system)
        except OSError:
            pass
    return f'{system} ({platform.machine()}) with Spec Kit {specify_version()}'


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('mode', choices=['check', 'body', 'url'])
    ap.add_argument('--version', required=True, help='released version, without the v')
    ap.add_argument('--sha256', help='expected archive digest; fails if it differs')
    ap.add_argument('--update', action='store_true', help='the catalog already lists the extension')
    ap.add_argument('--tested-on', help='overrides the detected OS and Spec Kit version')
    args = ap.parse_args()
    if args.version.startswith('v'):
        sys.exit('--version takes X.Y.Z, without the v')

    local = yaml.safe_load((ROOT / 'extension.yml').read_text(encoding='utf-8'))
    repo = local['extension']['repository'].rstrip('/')
    url = f'{repo}/archive/refs/tags/v{args.version}.zip'

    # The published archive is the truth, not the working tree.
    try:
        blob = fetch(url)
    except Exception as e:  # noqa: BLE001 - report any download failure the same way
        sys.exit(f'cannot download {url}: {e}')
    sha = hashlib.sha256(blob).hexdigest()
    if args.sha256 and args.sha256.lower() != sha:
        sys.exit(f'archive SHA-256 is {sha}, not {args.sha256}')
    zf = zipfile.ZipFile(io.BytesIO(blob))
    files = [n.split('/', 1)[1] for n in zf.namelist() if not n.endswith('/') and '/' in n]
    man = yaml.safe_load(zf.read(next(n for n in zf.namelist() if n.endswith('/extension.yml')
                                      and n.count('/') == 1)).decode('utf-8'))
    ext, req = man['extension'], man.get('requires', {})

    ci = re.search(r'SPEC_KIT_REF:\s*v?(\S+)', (ROOT / '.github/workflows/validate.yml').read_text())
    text = TEMPLATE.read_text(encoding='utf-8')
    text = re.sub(r'\A<!--.*?-->\s*', '', text, flags=re.S)
    for key, val in {'VERSION': args.version, 'DOWNLOAD_URL': url, 'SHA256': sha,
                     'DATE': date.today().isoformat(), 'TESTED_ON': args.tested_on or tested_on(),
                     'SPECKIT_CI': ci.group(1) if ci else 'unknown',
                     'ARCHIVE_FILES': str(len(files))}.items():
        text = text.replace('{{' + key + '}}', val)
    expect('{{' not in text, 'template has an unknown {{PLACEHOLDER}}')
    sec = {m[1].strip(): m[2].strip() for m in re.finditer(r'^### (.+?)\n(.*?)(?=^### |\Z)', text, re.S | re.M)}
    missing = [f[0] for f in FIELDS + TAIL if f[0] not in sec]
    if missing:
        sys.exit(f'template is missing sections: {missing}')

    # Template vs the released manifest.
    hooks = man.get('hooks') or {}
    want = {'Extension ID': ext['id'], 'Extension Name': ext['name'], 'Version': ext['version'],
            'Description': ext['description'], 'Author': ext['author'],
            'Repository URL': ext['repository'], 'License': ext['license'],
            'Homepage': ext.get('homepage', ext['repository']),
            'Required Spec Kit Version': req['speckit_version'],
            'Number of Commands': str(len(man['provides']['commands'])),
            'Number of Hooks': str(len(hooks)), 'Tags': ', '.join(man['tags'])}
    for label, value in want.items():
        expect(sec[label] == value, f'{label}: template says {sec[label]!r}, extension.yml says {value!r}')
    expect(ext['version'] == args.version, f'v{args.version} archive declares version {ext["version"]}')

    try:
        entry = json.loads(sec['Proposed Catalog Entry'])[ext['id']]
    except (ValueError, KeyError) as e:
        sys.exit(f'Proposed Catalog Entry is not valid JSON keyed by the id: {e}')
    for key, value in {'name': ext['name'], 'id': ext['id'], 'description': ext['description'],
                       'author': ext['author'], 'version': args.version, 'download_url': url,
                       'repository': ext['repository'], 'license': ext['license'],
                       'category': ext.get('category'), 'effect': ext.get('effect'), 'sha256': sha,
                       'tags': man['tags']}.items():
        expect(entry.get(key) == value, f'entry.{key} is {entry.get(key)!r}, expected {value!r}')
    expect(entry['requires']['speckit_version'] == req['speckit_version'], 'entry speckit_version drifted')
    expect([(t['name'], t.get('required', False)) for t in entry['requires'].get('tools', [])]
           == [(t['name'], t.get('required', False)) for t in req.get('tools', [])],
           'entry tools differ from extension.yml requires.tools')
    expect(entry['provides'] == {'commands': len(man['provides']['commands']), 'hooks': len(hooks)},
           'entry provides counts differ from extension.yml')

    # What the catalog bot rejects.
    expect(re.fullmatch(r'[a-z][a-z0-9-]*', ext['id']), 'id must match ^[a-z][a-z0-9-]*$')
    expect(re.fullmatch(r'\d+\.\d+\.\d+', args.version), 'version must be X.Y.Z')
    expect(re.fullmatch(r'[A-Za-z0-9._~%/:-]+', url), 'download URL has characters the bot rejects')
    expect(len(ext['description']) < 200, 'description must be under 200 characters')
    expect(2 <= len(man['tags']) <= 5 and all(t == t.lower() for t in man['tags']), 'tags: 2-5, lowercase')
    expect('```' not in sec['Example Usage'] + sec['Required Tools'],
           'no code fences in Example Usage or Required Tools: the form already wraps them')
    expect(not any(re.match(r'^(\.specify|\.github|specs|\.claude|\.agents)/|^AGENTS\.md$', f) for f in files),
           'dev-only paths in the archive')

    if problems:
        print('Not rendered:', *problems, sep='\n  - ', file=sys.stderr)
        sys.exit(1)

    title = (f'[Extension]: Update {ext["name"]} to v{args.version}' if args.update
             else f'[Extension]: Add {ext["name"]}')
    if args.update:
        sec['Additional Context'] = (f'- This updates the existing `{ext["id"]}` entry in the community '
                                     f'catalog to v{args.version}.\n' + sec['Additional Context'])

    if args.mode == 'check':
        print(f'OK  {title}\n    {url}\n    sha256 {sha}\n    {len(files)} files in the archive')
    elif args.mode == 'body':
        out = []
        for label, heading, _, render in FIELDS:
            out.append(f'### {heading}\n\n' + (f'```{render}\n{sec[label]}\n```' if render else sec[label]))
        for group, items in CHECKBOXES:
            out.append(f'### {group}\n\n' + '\n'.join(f'- [x] {i}' for i in items))
        for label, heading, _, render in TAIL:
            out.append(f'### {heading}\n\n' + (f'```{render}\n{sec[label]}\n```' if render else sec[label]))
        print(f'<!-- title: {title} -->', file=sys.stderr)
        print('\n\n'.join(out))
    else:
        params = [('template', 'extension_submission.yml'), ('title', title)]
        params += [(fid, sec[label]) for label, _, fid, _ in FIELDS + TAIL]
        link = FORM + '?' + urllib.parse.urlencode(params, quote_via=urllib.parse.quote)
        if len(link) > MAX_URL:
            sys.exit(f'prefilled URL is {len(link)} characters; GitHub fails above ~6,600. '
                     'Shorten the template, or use `body` and paste.')
        print(link)


if __name__ == '__main__':
    main()
