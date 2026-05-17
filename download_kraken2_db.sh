#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_ROOT="${ROOT_DIR}/lib/kraken2/db"
choice="${1:-pluspf_16}"

case "${choice}" in
    viral)
        url="https://genome-idx.s3.amazonaws.com/kraken/k2_viral_20260226.tar.gz"
        size_note="archive ~0.5 GB, index ~0.6 GB"
        ;;
    standard_8)
        url="https://genome-idx.s3.amazonaws.com/kraken/k2_standard_08_GB_20260226.tar.gz"
        size_note="archive ~5.5 GB, index ~7.5 GB"
        ;;
    standard_16)
        url="https://genome-idx.s3.amazonaws.com/kraken/k2_standard_16_GB_20260226.tar.gz"
        size_note="archive ~11.2 GB, index ~14.9 GB"
        ;;
    pluspf_8)
        url="https://genome-idx.s3.amazonaws.com/kraken/k2_pluspf_08_GB_20260226.tar.gz"
        size_note="archive ~5.5 GB, index ~7.5 GB"
        ;;
    pluspf_16)
        url="https://genome-idx.s3.amazonaws.com/kraken/k2_pluspf_16_GB_20260226.tar.gz"
        size_note="archive ~11.2 GB, index ~14.9 GB"
        ;;
    *)
        echo "Unknown Kraken2 database: ${choice}"
        echo "Available choices: viral, standard_8, standard_16, pluspf_8, pluspf_16"
        exit 1
        ;;
esac

if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required to download Kraken2 databases."
    exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
    echo "tar is required to extract Kraken2 databases."
    exit 1
fi

dest="${DB_ROOT}/${choice}"
tmp="${DB_ROOT}/.${choice}.download"
archive="${tmp}/$(basename "${url}")"

if [ -f "${dest}/hash.k2d" ] && [ -f "${dest}/opts.k2d" ] && [ -f "${dest}/taxo.k2d" ]; then
    echo "Kraken2 database already present: ${dest}"
    exit 0
fi

echo "Downloading Kraken2 database '${choice}' into ${dest}"
echo "${size_note}"
echo "Source: ${url}"

rm -rf "${tmp}"
mkdir -p "${tmp}" "${dest}"

curl -fL -C - -o "${archive}" "${url}"
tar -xzf "${archive}" -C "${tmp}"

hash_file="$(find "${tmp}" -type f -name "hash.k2d" | head -n 1)"
if [ -z "${hash_file}" ]; then
    echo "Download/extraction finished, but hash.k2d was not found."
    exit 1
fi

extracted_dir="$(dirname "${hash_file}")"
rm -rf "${dest}"
mkdir -p "${dest}"
mv "${extracted_dir}"/* "${dest}/"
rm -rf "${tmp}"

if [ ! -f "${dest}/hash.k2d" ] || [ ! -f "${dest}/opts.k2d" ] || [ ! -f "${dest}/taxo.k2d" ]; then
    echo "Kraken2 database is incomplete after extraction."
    exit 1
fi

echo "Kraken2 database ready: ${dest}"
