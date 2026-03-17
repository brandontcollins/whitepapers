#!/usr/bin/env python3
# Copyright (c) 2026 Brandon T. Collins
# Licensed under the Creative Commons Attribution 4.0 International License (CC BY 4.0).
# See https://creativecommons.org/licenses/by/4.0/ for details.

import sys

USAGE = """Usage: format_filter.py <pdf|html>

Reads markdown from stdin and writes filtered markdown to stdout, keeping:
- pdf:  common content + ::: pdf-only blocks
- html: common content + ::: html-only blocks
"""


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("pdf", "html"):
        sys.stderr.write(USAGE)
        sys.exit(1)

    target = sys.argv[1]  # 'pdf' or 'html'

    in_block = False
    current_block_type = None  # 'pdf-only', 'html-only', or None

    for raw_line in sys.stdin:
        line = raw_line.rstrip("\n")

        # Start of fenced div: ::: pdf-only / ::: html-only
        if not in_block and line.strip().startswith(":::"):
            parts = line.strip().split()
            if len(parts) >= 2 and parts[0] == ":::":
                block_type = parts[1].strip()
                if block_type in ("pdf-only", "html-only"):
                    in_block = True
                    current_block_type = block_type
                    continue  # don't output the fence line

        # End of fenced div: :::
        if in_block and line.strip() == ":::":

            in_block = False
            current_block_type = None
            continue  # don't output closing fence

        # Inside a format-specific block
        if in_block:
            if current_block_type == "pdf-only" and target == "pdf":
                print(line)
            elif current_block_type == "html-only" and target == "html":
                print(line)
            # otherwise skip
            continue

        # Outside any special block: always keep
        print(line)


if __name__ == "__main__":
    main()
