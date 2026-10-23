#!/usr/bin/env bash
# Only the root-lock Jason/yamerl parsers are needed by the cheap CI fixtures.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
output="${1:?usage: prepare_readiness_fixture_runtime.sh NEW_EXTERNAL_DIRECTORY}"
test ! -e "$output"
mkdir -m 700 -p "$output"
output="$(cd "$output" && pwd -P)"
case "$output/" in "$root/"*) echo 'fixture runtime must be external' >&2; exit 1;; esac
cat > "$output/mix.exs" <<'EX'
defmodule ReadinessParserRuntime.MixProject do
  use Mix.Project
  def project, do: [app: :readiness_parser_runtime, version: "0.0.0", deps: [{:jason, "== 1.4.5"}, {:yamerl, "== 0.10.0"}]]
end
EX
cp "$root/mix.lock" "$output/mix.lock"
(cd "$output" && export MIX_HOME="$output/mix-home" HEX_HOME="$output/hex-home" && MIX_ENV=dev mix local.hex --force && MIX_ENV=dev mix local.rebar --force && MIX_ENV=dev mix deps.get --check-locked && MIX_ENV=dev mix deps.compile)
mkdir -m 700 "$output/bin"
real_elixir="$(command -v elixir)"
python3 - "$output" "$real_elixir" <<'PY'
import pathlib,sys
out=pathlib.Path(sys.argv[1]);elixir=sys.argv[2]
ebins=[str(out/'_build/dev/lib'/dep/'ebin') for dep in ('jason','yamerl')]
assert all(pathlib.Path(p).is_dir() for p in ebins)
# This fixture-only adapter refuses compilation, installs and arbitrary Mix tasks.
script='''#!/usr/bin/env python3
import os,sys
args=sys.argv[1:]
if not args or args.pop(0)!='run':raise SystemExit('fixture runtime supports only mix run')
while args and args[0] in ('--no-start','--no-compile','--no-deps-check'):args.pop(0)
if not args or args[0].startswith('--'):raise SystemExit('invalid fixture mix run')
os.execv(ELIXIR,[ELIXIR,*LIBS,*args])
'''.replace('ELIXIR',repr(elixir)).replace('LIBS',repr([x for p in ebins for x in ('-pa',p)]))
(out/'bin/mix').write_text(script);(out/'bin/mix').chmod(0o700)
PY
if [ -n "${GITHUB_PATH:-}" ]; then echo "$output/bin" >> "$GITHUB_PATH"; fi
printf 'PASS: root-lock parser-only fixture runtime at %s/bin\n' "$output"
