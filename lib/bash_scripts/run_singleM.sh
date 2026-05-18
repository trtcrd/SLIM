#!/usr/bin/env bash

set -euo pipefail

level="species"
fastp_trim="yes"
fastp_report_archive="singleM.fastp_reports.tar.gz"

while getopts i:1:2:t:p:O:a:q:f: flag
do
    case "${flag}" in
        i) dir="${OPTARG}";;
        1) fwd_pattern="${OPTARG}";;
        2) rev_pattern="${OPTARG}";;
        t) threads="${OPTARG}";;
        p) profile="${OPTARG}";;
        O) otu_table="${OPTARG}";;
        a) relative_abundance_archive="${OPTARG}";;
        q) fastp_report_archive="${OPTARG}";;
        f) fastp_trim="${OPTARG}";;
        \?) echo "usage: run_singleM.sh -i dir -1 fwd_pattern -2 rev_pattern -t threads -p profile -O otu_table -a relative_abundance_archive [-q fastp_report_archive] [-f yes|no]"; exit 1;;
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

fastp_report_dir="singleM_fastp_reports"
fastp_trim_dir="singleM_fastp_trimmed"
singlem_fwd_files=("${fwd_files[@]}")
singlem_rev_files=("${rev_files[@]}")

sample_name_from_file() {
    local file="$1"
    local sample

    sample="$(basename "${file}")"
    sample="${sample%.gz}"
    sample="${sample%.fastq}"
    sample="${sample%.fq}"
    sample="${sample%_R1}"
    sample="${sample%_R2}"
    sample="${sample%_1}"
    sample="${sample%_2}"

    printf '%s\n' "${sample}"
}

if [ "${fastp_trim}" = "yes" ]; then
    if ! command -v fastp >/dev/null 2>&1; then
        echo "fastp trimming was requested, but fastp is not available in PATH."
        echo "Rebuild the image with fastp available in the container environment."
        exit 1
    fi

    rm -rf "${fastp_report_dir}" "${fastp_trim_dir}"
    mkdir -p "${fastp_report_dir}" "${fastp_trim_dir}"

    singlem_fwd_files=()
    singlem_rev_files=()

    for idx in "${!fwd_files[@]}"; do
        sample="$(sample_name_from_file "${fwd_files[$idx]}")"
        trimmed_fwd="${fastp_trim_dir}/${sample}.R1.fastp.fastq.gz"
        trimmed_rev="${fastp_trim_dir}/${sample}.R2.fastp.fastq.gz"

        echo
        echo "Trimming adapters/low-quality bases with fastp for sample: ${sample}"
        fastp \
            -i "${fwd_files[$idx]}" \
            -I "${rev_files[$idx]}" \
            -o "${trimmed_fwd}" \
            -O "${trimmed_rev}" \
            --detect_adapter_for_pe \
            --thread "${threads}" \
            --html "${fastp_report_dir}/${sample}.fastp.html" \
            --json "${fastp_report_dir}/${sample}.fastp.json"

        singlem_fwd_files+=("${trimmed_fwd}")
        singlem_rev_files+=("${trimmed_rev}")
    done
else
    rm -rf "${fastp_report_dir}"
    mkdir -p "${fastp_report_dir}"
    echo "fastp trimming was disabled for this SingleM run." > "${fastp_report_dir}/fastp_skipped.txt"
fi

singlem pipe \
    -1 "${singlem_fwd_files[@]}" \
    -2 "${singlem_rev_files[@]}" \
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
tar -czf "${fastp_report_archive}" "${fastp_report_dir}"
rm -rf "${fastp_trim_dir}" "${fastp_report_dir}"


echo "SingleM finished."
