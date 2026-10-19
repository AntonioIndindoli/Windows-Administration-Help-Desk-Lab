"""Resume official ISO downloads in verified byte ranges; Python standard library only."""
import argparse
import concurrent.futures
import hashlib
import pathlib
import re
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--url', required=True)
parser.add_argument('--output', required=True)
parser.add_argument('--size', required=True, type=int)
parser.add_argument('--workers', type=int, default=8)
args = parser.parse_args()
output = pathlib.Path(args.output).resolve()
parts = output.parent / (output.name + '.parts')
parts.mkdir(parents=True, exist_ok=True)
chunk_size = 4 * 1024 * 1024
count = (args.size + chunk_size - 1) // chunk_size

def fetch(index):
    start = index * chunk_size
    end = min(args.size, start + chunk_size) - 1
    expected = end - start + 1
    part = parts / f'{index:06d}.part'
    headers = parts / f'{index:06d}.headers'
    range_pattern = rf'content-range:\s*bytes {start}-{end}/{args.size}\s*$'
    def valid():
        return (part.exists() and part.stat().st_size == expected and headers.exists()
                and re.search(range_pattern, headers.read_text(errors='replace'), re.I | re.M))
    if valid():
        return index
    for attempt in range(3):
        result = subprocess.run([
            'curl.exe', '--fail', '--location', '--silent', '--show-error',
            '--connect-timeout', '10', '--max-time', '30',
            '--range', f'{start}-{end}', '--output', str(part),
            '--dump-header', str(headers),
            '--write-out', '%{http_code}', args.url,
        ], capture_output=True, text=True)
        if result.returncode == 0 and result.stdout.strip() == '206' and valid():
            return index
        time.sleep(attempt + 1)
    raise RuntimeError(f'Chunk {index} failed: HTTP {result.stdout}; {result.stderr[:200]}')

started = time.monotonic()
failures = []
with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
    futures = [pool.submit(fetch, i) for i in range(count)]
    for completed, future in enumerate(concurrent.futures.as_completed(futures), 1):
        try:
            future.result()
        except Exception as error:
            failures.append(str(error))
            print(f'RETRY REQUIRED: {error}', flush=True)
        if completed % 32 == 0 or completed == count:
            print(f'{output.name}: {completed}/{count} chunks ({completed/count:.1%}); {time.monotonic()-started:.0f}s', flush=True)

if failures:
    raise RuntimeError(f'{len(failures)} chunks failed; rerun to resume. First: {failures[0]}')

digest = hashlib.sha256()
with output.open('wb') as target:
    for index in range(count):
        with (parts / f'{index:06d}.part').open('rb') as source:
            while block := source.read(1024 * 1024):
                target.write(block)
                digest.update(block)
if output.stat().st_size != args.size:
    raise RuntimeError('Assembled size mismatch')
output.with_suffix(output.suffix + '.sha256').write_text(f'{digest.hexdigest()}  {output.name}\n')
print(f'COMPLETE {output.name}: {args.size} bytes; SHA256 {digest.hexdigest()}', flush=True)
# Keep verified parts for recovery until OS installation succeeds.
