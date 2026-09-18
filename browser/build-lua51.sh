#!/usr/bin/env bash

set -euo pipefail

LUA_VERSION="5.1.5"
LUA_SHA256="2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333"
OUTPUT_DIR="${1:-.cache/wasm-lua51}"
WORK_DIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/rubikotc-lua-${LUA_VERSION}"
ARCHIVE="${WORK_DIR}/lua-${LUA_VERSION}.tar.gz"

command -v emcc >/dev/null
command -v emar >/dev/null
command -v emranlib >/dev/null

mkdir -p "${WORK_DIR}" "${OUTPUT_DIR}"
curl --fail --location --retry 3 --output "${ARCHIVE}" \
  "https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz"
echo "${LUA_SHA256}  ${ARCHIVE}" | sha256sum --check --strict

rm -rf "${WORK_DIR}/lua-${LUA_VERSION}"
tar -xzf "${ARCHIVE}" -C "${WORK_DIR}"

make -C "${WORK_DIR}/lua-${LUA_VERSION}/src" liblua.a \
  CC=emcc \
  AR="emar rcu" \
  RANLIB=emranlib \
  MYCFLAGS="-O2 -pthread -matomics -mbulk-memory"

install -m 0644 "${WORK_DIR}/lua-${LUA_VERSION}/src/liblua.a" \
  "${OUTPUT_DIR}/liblua.a"

test -s "${OUTPUT_DIR}/liblua.a"
