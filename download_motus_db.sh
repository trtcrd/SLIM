#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_ROOT="${ROOT_DIR}/lib/mOTUs/db"
IMAGE_NAME="${SLIM_IMAGE:-slim}"

if [ -n "${SLIM_ENGINE:-}" ]; then
    engine="${SLIM_ENGINE}"
elif command -v podman >/dev/null 2>&1; then
    engine="podman"
elif command -v docker >/dev/null 2>&1; then
    engine="docker"
else
    echo "Neither podman nor docker is available."
    exit 1
fi

mkdir -p "${DB_ROOT}"

motus_db_ready()
{
    [ -d "${DB_ROOT}/db_mOTU" ] && \
        find "${DB_ROOT}/db_mOTU" -type f -name "*.bwt" | grep -q .
}

if motus_db_ready; then
    echo "mOTUs database already present: ${DB_ROOT}/db_mOTU"
    exit 0
elif [ -d "${DB_ROOT}/db_mOTU" ]; then
    echo "Removing incomplete mOTUs database: ${DB_ROOT}/db_mOTU"
    rm -rf "${DB_ROOT}/db_mOTU"
fi

if ! "${engine}" image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
    echo "Image ${IMAGE_NAME} was not found."
    echo "This downloader uses the motus executable inside the built SLIM image."
    echo "Run start_slim_v1.0.0.sh, or build the image first with:"
    echo "  ${engine} build -t ${IMAGE_NAME} ."
    echo "Then run this script again."
    exit 1
fi

echo "Downloading mOTUs marker-gene database into ${DB_ROOT}"
echo "This can take a while."

"${engine}" run --rm \
    -v "${DB_ROOT}:/db" \
    "${IMAGE_NAME}" \
    bash -lc '
        set -euo pipefail

        if [ -d /db/db_mOTU ] && find /db/db_mOTU -type f -name "*.bwt" | grep -q .; then
            echo "mOTUs database already present in /db/db_mOTU"
            exit 0
        elif [ -d /db/db_mOTU ]; then
            echo "Removing incomplete mOTUs database in /db/db_mOTU"
            rm -rf /db/db_mOTU
        fi

        motus downloadMGDB

        db_dir="$(python - <<'"'"'PY'"'"'
import importlib.util
import pathlib
import sys

roots = []
spec = importlib.util.find_spec("motus")
if spec and spec.submodule_search_locations:
    roots.extend(pathlib.Path(p) for p in spec.submodule_search_locations)
elif spec and spec.origin:
    roots.append(pathlib.Path(spec.origin).resolve().parent)

roots.append(pathlib.Path("/root/miniforge3/envs/motus"))

candidates = []
for root in roots:
    if root.exists():
        candidates.extend(
            p for p in root.rglob("db_mOTU")
            if p.is_dir() and any(p.iterdir())
        )

if not candidates:
    sys.exit("Unable to locate db_mOTU after motus downloadMGDB")

print(candidates[0])
PY
)"

        rm -rf /db/db_mOTU
        cp -a "${db_dir}" /db/
    '

if ! motus_db_ready; then
    echo "mOTUs database download finished, but ${DB_ROOT}/db_mOTU is missing BWA index files."
    exit 1
fi

echo "mOTUs database ready: ${DB_ROOT}/db_mOTU"
