"""Phase-local immutable-source evidence implementation (standard library only)."""
import argparse
import json
import pathlib
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("operation")
    parser.add_argument("--subject-file", required=True)
    parser.add_argument("--receipt")
    args = parser.parse_args(sys.argv[3:])
    result = {"outcome": "blocked", "reason": "collector_not_implemented"}
    if args.receipt:
        pathlib.Path(args.receipt).write_text(json.dumps(result))
    print(json.dumps(result))


if __name__ == "__main__":
    main()
