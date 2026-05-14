#!/usr/bin/env bash

set -euo pipefail

level="species"

while getopts i:1:2:t:p:O:a: flag
do
    case "${flag}" in
        i) dir="${OPTARG}";;
        1) fwd_pattern="${OPTARG}";;
        2) rev_pattern="${OPTARG}";;
        t) threads="${OPTARG}";;
        p) profile="${OPTARG}";;
        O) otu_table="${OPTARG}";;
        a) relative_abundance_archive="${OPTARG}";;
        \?) echo "usage: run_singleM.sh -i dir -1 fwd_pattern -2 rev_pattern -t threads -p profile -O otu_table -a relative_abundance_archive"; exit 1;;
    esac
done


cd "${dir}"

fwd_pattern="${fwd_pattern//€/*}"
rev_pattern="${rev_pattern//€/*}"

shopt -s nullglob
fwd_files=( ${fwd_pattern} )
rev_files=( ${rev_pattern} )

if [ "${#fwd_files[@]}" -eq 0 ]; then
    echo "No forward FASTQ files matched: ${fwd_pattern}"
    echo "Available FASTQ files in ${dir}:"
    find . -maxdepth 1 -type f \( -name "*.fastq" -o -name "*.fastq.gz" -o -name "*.fq" -o -name "*.fq.gz" \) -printf "  %f\n" | sort
    exit 1
fi

if [ "${#rev_files[@]}" -eq 0 ]; then
    echo "No reverse FASTQ files matched: ${rev_pattern}"
    echo "Available FASTQ files in ${dir}:"
    find . -maxdepth 1 -type f \( -name "*.fastq" -o -name "*.fastq.gz" -o -name "*.fq" -o -name "*.fq.gz" \) -printf "  %f\n" | sort
    exit 1
fi

if [ "${#fwd_files[@]}" -ne "${#rev_files[@]}" ]; then
    echo "Different numbers of forward and reverse reads:"
    echo "Forward: ${#fwd_files[@]}"
    echo "Reverse: ${#rev_files[@]}"
    exit 1
fi

echo "SingleM metapackage: ${SINGLEM_METAPACKAGE_PATH:-unset}"
if [ -z "${SINGLEM_METAPACKAGE_PATH:-}" ] || [ ! -e "${SINGLEM_METAPACKAGE_PATH}" ]; then
    echo "SINGLEM_METAPACKAGE_PATH is not set or does not exist."
    exit 1
fi
singlem_metapackage="${SINGLEM_METAPACKAGE_PATH}"

# Newer/custom SingleM metapackages must be passed explicitly with
# --metapackage. If they are provided through SINGLEM_METAPACKAGE_PATH,
# SingleM validates them against the default version baked into the installed
# software and may reject newer databases.
unset SINGLEM_METAPACKAGE_PATH

echo "Forward files:"
printf '  %s\n' "${fwd_files[@]}"

echo "Reverse files:"
printf '  %s\n' "${rev_files[@]}"

singlem pipe \
    -1 "${fwd_files[@]}" \
    -2 "${rev_files[@]}" \
    --metapackage "${singlem_metapackage}" \
    --taxonomic-profile "${profile}" \
    --otu-table "${otu_table}" \
    --threads "${threads}"

relative_prefix="singleM.relative_abundance"

singlem summarise \
    --input-taxonomic-profiles "${profile}" \
    --metapackage "${singlem_metapackage}" \
    --output-species-by-site-relative-abundance-prefix "${relative_prefix}"

tar -czf "${relative_abundance_archive}" ${relative_prefix}-*.tsv


echo "SingleM finished."
