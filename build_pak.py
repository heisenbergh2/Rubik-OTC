#!/usr/bin/env python3
"""Pack OTC modules/mods/assets into a single assets.pak (ZIP) for embedding in exe.

Usage:
    python build_pak.py                       # plain pak, no encryption
    python build_pak.py --password P --header H   # encrypt each file inside

Outputs:
    D:/OTS/OTC-check/assets.pak  (uncompressed-stored ZIP)

When --password and --header are provided, every file is prefixed with HEADER
and XOR-encrypted with the OTC built-in algorithm (matches ResourceManager::
encrypt / decrypt in src/framework/core/resourcemanager.cpp). The C++ side
reads the HEADER at runtime in readFileContents() and decrypts on the fly.

For end-to-end protection, PASSWORD/HEADER in this script MUST match the
ENCRYPTION_PASSWORD / ENCRYPTION_HEADER #defines in src/framework/config.h
and ENABLE_ENCRYPTION must be set to 1 in that file.
"""
import argparse
import os
import sys
import zipfile
import time
import hashlib
import subprocess
import tempfile
from Crypto.Cipher import ChaCha20_Poly1305  # pip install pycryptodome

# LuaJIT used to bytecode-compile .lua before encryption (bytecode protection).
LUAJIT_EXE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          "vc18", "vcpkg_installed", "x64-windows-static", "tools", "luajit", "luajit.exe")
LUAJIT_COMPILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "luajit_compile.lua")


def lua_to_bytecode(src_bytes: bytes, chunkname: str) -> bytes:
    """Compile Lua source -> LuaJIT bytecode (via string.dump), keeping the module path
    as the chunk name so in-game tracebacks stay readable."""
    with tempfile.TemporaryDirectory() as td:
        src = os.path.join(td, "in.lua")
        out = os.path.join(td, "out.bc")
        with open(src, "wb") as fh:
            fh.write(src_bytes)
        r = subprocess.run([LUAJIT_EXE, LUAJIT_COMPILE, src, out, chunkname],
                           capture_output=True)
        if r.returncode != 0 or not os.path.isfile(out):
            raise RuntimeError(f"luajit compile failed for {chunkname}: {r.stderr.decode(errors='replace')[:300]}")
        with open(out, "rb") as fh:
            return fh.read()

REPO = os.path.dirname(os.path.abspath(__file__))
OUT  = os.path.join(REPO, "assets.pak")

# Roots we want to include. Each entry is a path relative to REPO that gets walked.
INCLUDE_DIRS = [
    "modules",
    "mods",
    "assets/cursors",
    "assets/fonts",
    "assets/images",
    "assets/json",
    "assets/locales",
    "assets/particles",
    # SPIR-V bytecode for the Vulkan renderer. The client loads it at runtime via
    # ResourceManager, so without this entry releases with an embedded pak would have
    # Vulkan without shaders (the renderer then degrades to just clearing the screen).
    # The .vert/.frag sources are filtered out below by SKIP_NAME_SUFFIXES - only .spv go into the pak.
    "assets/shaders",
    "assets/styles",
]

# Single files at the assets root we want too.
INCLUDE_FILES = [
    "assets/setup.otml",
]

# File patterns / paths to skip while walking.
# Archives (.rar/.zip/.7z) and graphic sources (.psd) are the artist's working material:
# the client never reads them, and they sit in the same directories as the finished .png,
# so without this filter they ended up in the pak and needlessly bloated the exe.
SKIP_NAME_PREFIXES = (".", "__")            # hidden + python cache
SKIP_NAME_SUFFIXES = (".pdb", ".exp", ".lib", ".log", ".bak", ".swp", ".tmp",
                      ".rar", ".zip", ".7z", ".psd",   # archives + PSD sources
                      ".bat")
SKIP_NAMES        = {"Thumbs.db", ".DS_Store", ".gitkeep", ".gitignore"}
# Directories skipped entirely: _backup_original holds copies of the original,
# uncompressed graphics and must NOT end up in the pak.
SKIP_DIRS         = {"_backup_original"}

# NOTE: .vert/.frag must NOT be in SKIP_NAME_SUFFIXES. Vulkan reads the compiled .spv, so it is
# tempting to filter out the GLSL sources - but the same extensions are used by OpenGL shaders in
# modules (game_shaders, game_exaltationforge - 26 files), which the client loads as TEXT
# at runtime. A global rule would cut them out of the pak and the effects would stop working.
# So we filter out the Vulkan shader sources selectively, by path.
SKIP_PATH_PREFIXES = ("assets/shaders/vulkan/",)


def should_skip(name: str) -> bool:
    if name in SKIP_NAMES:
        return True
    for p in SKIP_NAME_PREFIXES:
        if name.startswith(p):
            return True
    for s in SKIP_NAME_SUFFIXES:
        if name.endswith(s):
            return True
    return False


def walk_files(root_dir: str):
    for dp, dn, fn in os.walk(root_dir):
        # prune skipped subdirs in-place so os.walk doesn't descend into them
        dn[:] = [d for d in dn if d not in SKIP_DIRS and not should_skip(d)]
        for f in fn:
            if should_skip(f):
                continue

            full = os.path.join(dp, f)

            # selective filtering of Vulkan shader sources (see the comment at SKIP_PATH_PREFIXES):
            # only compiled .spv go into the pak, but the GLSL of other modules must stay
            rel = full.replace("\\", "/")
            if any(pref in rel for pref in SKIP_PATH_PREFIXES) and not f.endswith(".spv"):
                continue

            yield full


def encrypt_otc(data: bytes, password: str) -> bytes:
    """XChaCha20-Poly1305 (24-byte nonce) — matches ResourceManager::decrypt in
    src/framework/core/resourcemanager.cpp. Key = BLAKE2b-256(password). Returns
    [24B nonce][ciphertext][16B Poly1305 tag]; the ENCRYPTION_HEADER magic is
    prepended by add()."""
    if not password:
        return data
    key = hashlib.blake2b(password.encode("utf-8"), digest_size=32).digest()
    nonce = os.urandom(24)  # 24 bytes -> XChaCha20
    ct, tag = ChaCha20_Poly1305.new(key=key, nonce=nonce).encrypt_and_digest(data)
    return nonce + ct + tag


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--password", default="",
                        help="Encryption password — must match ENCRYPTION_PASSWORD in config.h")
    parser.add_argument("--header", default="",
                        help="Encryption header marker — must match ENCRYPTION_HEADER in config.h")
    args = parser.parse_args()

    encrypt = bool(args.password and args.header)
    if (args.password and not args.header) or (args.header and not args.password):
        print("ERROR: --password and --header must be provided together (or neither)", file=sys.stderr)
        sys.exit(2)

    start = time.time()

    if os.path.exists(OUT):
        os.remove(OUT)

    # ZIP_STORED (no compression) — exe link step compresses the .rc resource
    # block anyway, and stored archives let PhysFS open files via direct memory
    # offset (no per-file inflate at mount time). Faster startup.
    with zipfile.ZipFile(OUT, "w", compression=zipfile.ZIP_STORED) as zf:
        total_files = 0
        total_bytes = 0
        header_bytes = args.header.encode("utf-8") if encrypt else b""

        # File types OTC reads with bespoke decoders that don't go through
        # ResourceManager::readFileContents (so per-file XOR encryption would
        # corrupt them). Matches the excluded list in
        # ResourceManager::runEncryption in src/framework/core/resourcemanager.cpp.
        encrypt_skip_exts = {".rar", ".ogg", ".xml", ".dll", ".exe", ".log", ".otb"}

        def add(arcname: str, src: str):
            nonlocal total_files, total_bytes
            with open(src, "rb") as fh:
                data = fh.read()
            total_bytes += len(data)
            ext = os.path.splitext(arcname)[1].lower()
            if encrypt and ext not in encrypt_skip_exts:
                if ext == ".lua":
                    data = lua_to_bytecode(data, arcname)  # bytecode before encrypt
                data = header_bytes + encrypt_otc(data, args.password)
            zf.writestr(arcname, data)
            total_files += 1

        for inc in INCLUDE_DIRS:
            abs_dir = os.path.join(REPO, inc.replace("/", os.sep))
            if not os.path.isdir(abs_dir):
                print(f"WARN: missing dir {abs_dir}, skipping")
                continue
            for full in walk_files(abs_dir):
                arcname = os.path.relpath(full, REPO).replace(os.sep, "/")
                add(arcname, full)

        for inc in INCLUDE_FILES:
            full = os.path.join(REPO, inc.replace("/", os.sep))
            if not os.path.isfile(full):
                print(f"WARN: missing file {full}, skipping")
                continue
            add(inc, full)

    pak_size = os.path.getsize(OUT)
    elapsed  = time.time() - start

    label = "encrypted" if encrypt else "plain"
    print(f"Built {OUT} ({label})")
    print(f"  {total_files} files, {total_bytes/1024/1024:.1f} MB content -> {pak_size/1024/1024:.1f} MB pak (stored)")
    print(f"  {elapsed:.1f}s")
    if encrypt:
        print(f"  password len={len(args.password)}, header={args.header!r}")
        print(f"  REMEMBER: set the same values in src/framework/config.h and ENABLE_ENCRYPTION=1")


if __name__ == "__main__":
    main()
