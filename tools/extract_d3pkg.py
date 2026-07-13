#!/usr/bin/env python3
# Copyright 2024 Sebastien Noel <sebastien@twolife.be>
# Copyright 2026 Descent 3 Revival contributors
# SPDX-License-Identifier: GPL-2.0-or-later
"""Safely extract the OPKG archives used by Descent 3: Mercenary.

The archive layout is based on Debian game-data-packager's d3pkg reader.
This standalone version has no third-party Python dependencies and validates
archive paths and bounds before writing any files.
"""

from __future__ import annotations

import argparse
import struct
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import BinaryIO, Iterator


MAGIC = b"GKPO"
COPY_CHUNK_SIZE = 1024 * 1024


class ArchiveError(ValueError):
    """Raised when an input is not a valid Descent 3 OPKG archive."""


@dataclass(frozen=True)
class Entry:
    path: PurePosixPath
    offset: int
    size: int


def read_exact(reader: BinaryIO, size: int, context: str) -> bytes:
    data = reader.read(size)
    if len(data) != size:
        raise ArchiveError(f"truncated archive while reading {context}")
    return data


def read_u32(reader: BinaryIO, context: str) -> int:
    return struct.unpack("<I", read_exact(reader, 4, context))[0]


def read_archive_string(reader: BinaryIO, context: str) -> str:
    size = read_u32(reader, f"{context} length")
    if size < 1:
        raise ArchiveError(f"invalid zero-length {context}")

    raw = read_exact(reader, size, context)
    if raw[-1] != 0:
        raise ArchiveError(f"unterminated {context}")
    return raw[:-1].decode("windows-1252").replace("\\", "/")


def safe_relative_path(dirname: str, basename: str) -> PurePosixPath:
    path = PurePosixPath(dirname, basename)
    if not basename or path.is_absolute() or ".." in path.parts:
        raise ArchiveError(f"unsafe archive path: {path}")
    return path


def parse_entries(reader: BinaryIO, archive_size: int) -> list[Entry]:
    if read_exact(reader, 4, "magic") != MAGIC:
        raise ArchiveError("magic does not match a Descent 3 OPKG archive")

    entry_count = read_u32(reader, "entry count")
    entries: list[Entry] = []

    for index in range(entry_count):
        dirname = read_archive_string(reader, f"entry {index} directory")
        basename = read_archive_string(reader, f"entry {index} filename")
        size = read_u32(reader, f"entry {index} size")
        read_exact(reader, 8, f"entry {index} metadata")

        offset = reader.tell()
        end = offset + size
        if end > archive_size:
            raise ArchiveError(f"entry exceeds archive bounds: {basename}")

        entries.append(Entry(safe_relative_path(dirname, basename), offset, size))
        reader.seek(end)

    if reader.tell() != archive_size:
        raise ArchiveError(
            f"entry table ended at {reader.tell()}, archive size is {archive_size}"
        )
    return entries


def iter_chunks(reader: BinaryIO, size: int) -> Iterator[bytes]:
    remaining = size
    while remaining:
        chunk = read_exact(reader, min(remaining, COPY_CHUNK_SIZE), "entry data")
        remaining -= len(chunk)
        yield chunk


def extract(archive: Path, output: Path) -> list[Entry]:
    archive_size = archive.stat().st_size
    output_root = output.resolve()
    output_root.mkdir(parents=True, exist_ok=True)

    with archive.open("rb") as reader:
        entries = parse_entries(reader, archive_size)
        for entry in entries:
            destination = (output_root / Path(*entry.path.parts)).resolve()
            try:
                destination.relative_to(output_root)
            except ValueError as error:
                raise ArchiveError(f"unsafe output path: {entry.path}") from error

            destination.parent.mkdir(parents=True, exist_ok=True)
            reader.seek(entry.offset)
            with destination.open("wb") as writer:
                for chunk in iter_chunks(reader, entry.size):
                    writer.write(chunk)

    return entries


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    if not args.archive.is_file():
        parser.error(f"archive does not exist: {args.archive}")

    try:
        entries = extract(args.archive, args.output)
    except (ArchiveError, OSError, UnicodeError) as error:
        parser.error(str(error))

    total_size = sum(entry.size for entry in entries)
    print(f"Extracted {len(entries)} files ({total_size} bytes) to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
