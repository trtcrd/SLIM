#!/usr/bin/env bash

set -euo pipefail

rank="S"
min_abundance="0.001"
max_taxa="25"
max_genomes="1"
assembly_choice="reference_then_representative"

checkpoint() {
    echo
    echo "== checkpoint == $*"
}

while getopts i:k:r:a:n:g:c:o:m:A:x: flag
do
    case "${flag}" in
        i) dir="${OPTARG}";;
        k) kraken_table="${OPTARG}";;
        r) rank="${OPTARG}";;
        a) min_abundance="${OPTARG}";;
        n) max_taxa="${OPTARG}";;
        g) max_genomes="${OPTARG}";;
        c) assembly_choice="${OPTARG}";;
        o) reference_fasta="${OPTARG}";;
        m) manifest="${OPTARG}";;
        A) acc2tax="${OPTARG}";;
        x) archive="${OPTARG}";;
        \?) echo "usage: run_targeted_reference_builder.sh -i dir -k kraken_table -r rank -a min_abundance -n max_taxa -g max_genomes -c assembly_choice -o reference_fasta -m manifest -A acc2tax -x archive"; exit 1;;
    esac
done

required_vars=(dir kraken_table reference_fasta manifest acc2tax archive)
for var_name in "${required_vars[@]}"; do
    if [ -z "${!var_name:-}" ]; then
        echo "Missing required option: ${var_name}"
        exit 1
    fi
done

cd "${dir}"

if [ ! -f "${kraken_table}" ]; then
    echo "Kraken2/Bracken table was not found: ${kraken_table}"
    exit 1
fi

for cmd in datasets unzip bwa samtools awk; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "${cmd} is required but is not available in PATH."
        echo "Rebuild the image with the ancient-DNA environment."
        exit 1
    fi
done

workdir="targeted_reference_builder"
download_dir="${workdir}/downloads"
tmp_selected="${workdir}/selected_taxa.tsv"
mkdir -p "${download_dir}"
rm -f "${reference_fasta}" "${reference_fasta}.fai" "${manifest}" "${acc2tax}" "${archive}"

checkpoint "Selecting taxa from abundance table started"
echo "Selecting taxa from ${kraken_table}"
awk -F '\t' \
    -v rank="${rank}" \
    -v min_abundance="${min_abundance}" \
    -v max_taxa="${max_taxa}" '
    NR == 1 { next }
    $2 !~ /^[0-9]+$/ { next }
    rank != "any" && $3 != rank { next }
    {
        max = 0
        for (i = 4; i <= NF; i++) {
            if ($i + 0 > max) {
                max = $i + 0
            }
        }
        if (max >= min_abundance) {
            print max "\t" $1 "\t" $2 "\t" $3
        }
    }
' "${kraken_table}" | sort -gr | head -n "${max_taxa}" > "${tmp_selected}"
checkpoint "Selecting taxa from abundance table done"

if [ ! -s "${tmp_selected}" ]; then
    echo "No taxa passed the selection filters."
    echo "Input table: ${kraken_table}"
    echo "Rank: ${rank}"
    echo "Minimum abundance: ${min_abundance}"
    exit 1
fi

printf "taxid\tname\trank\tmax_abundance\tassembly_choice\tsequence_file\tsequence_id\n" > "${manifest}"

download_taxon()
{
    local taxid="$1"
    local taxon_dir="$2"
    local mode="$3"
    local zip_file="${taxon_dir}/${mode}.zip"

    rm -rf "${taxon_dir}/${mode}"
    mkdir -p "${taxon_dir}/${mode}"

    case "${mode}" in
        reference)
            datasets download genome taxon "${taxid}" \
                --reference \
                --include genome \
                --filename "${zip_file}" >/dev/null 2>&1
            ;;
        representative)
            datasets download genome taxon "${taxid}" \
                --representative \
                --include genome \
                --filename "${zip_file}" >/dev/null 2>&1
            ;;
        complete)
            datasets download genome taxon "${taxid}" \
                --assembly-source RefSeq \
                --assembly-level complete \
                --include genome \
                --filename "${zip_file}" >/dev/null 2>&1
            ;;
        any)
            datasets download genome taxon "${taxid}" \
                --assembly-source RefSeq \
                --include genome \
                --filename "${zip_file}" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac

    unzip -q "${zip_file}" -d "${taxon_dir}/${mode}"
}

try_download_taxon()
{
    local taxid="$1"
    local taxon_dir="$2"
    local modes=()
    local mode

    case "${assembly_choice}" in
        reference)
            modes=(reference)
            ;;
        representative)
            modes=(representative)
            ;;
        complete)
            modes=(complete)
            ;;
        any)
            modes=(any)
            ;;
        reference_then_representative)
            modes=(reference representative complete any)
            ;;
        *)
            modes=(reference representative complete any)
            ;;
    esac

    for mode in "${modes[@]}"; do
        checkpoint "Trying ${mode} RefSeq genome download for taxid ${taxid}" >&2
        if download_taxon "${taxid}" "${taxon_dir}" "${mode}"; then
            if find "${taxon_dir}/${mode}" -type f \( -name "*.fna" -o -name "*.fna.gz" \) | grep -q .; then
                printf '%s\n' "${mode}"
                return 0
            fi
        fi
    done

    return 1
}

append_fasta_for_taxon()
{
    local taxid="$1"
    local taxon_name="$2"
    local taxon_rank="$3"
    local abundance="$4"
    local chosen_mode="$5"
    local taxon_dir="$6"
    local count=0
    local fasta
    local base

    while IFS= read -r fasta; do
        count=$((count + 1))
        if [ "${count}" -gt "${max_genomes}" ]; then
            break
        fi

        base="$(basename "${fasta}")"
        echo "Adding ${base} for ${taxon_name} (${taxid})"

        if [[ "${fasta}" == *.gz ]]; then
            pigz -dc "${fasta}"
        else
            cat "${fasta}"
        fi | awk \
            -v taxid="${taxid}" \
            -v taxon_name="${taxon_name}" \
            -v taxon_rank="${taxon_rank}" \
            -v abundance="${abundance}" \
            -v chosen_mode="${chosen_mode}" \
            -v manifest="${manifest}" \
            -v base="${base}" '
            /^>/ {
                header = substr($0, 2)
                split(header, parts, /[[:space:]]+/)
                seq_id = parts[1]
                safe_id = seq_id "|taxid_" taxid
                print ">" safe_id
                print taxid "\t" taxon_name "\t" taxon_rank "\t" abundance "\t" chosen_mode "\t" base "\t" safe_id >> manifest
                next
            }
            { print }
        ' >> "${reference_fasta}"
    done < <(find "${taxon_dir}/${chosen_mode}" -type f \( -name "*.fna" -o -name "*.fna.gz" \) | sort)
}

while IFS=$'\t' read -r abundance name taxid taxon_rank; do
    safe_taxid="${taxid//[^0-9A-Za-z_.-]/_}"
    taxon_dir="${download_dir}/${safe_taxid}"
    mkdir -p "${taxon_dir}"

    checkpoint "Processing selected taxon ${name} (${taxid}), max abundance ${abundance}"
    if chosen_mode="$(try_download_taxon "${taxid}" "${taxon_dir}")"; then
        checkpoint "Appending FASTA sequences for taxid ${taxid} from ${chosen_mode} assembly set"
        append_fasta_for_taxon "${taxid}" "${name}" "${taxon_rank}" "${abundance}" "${chosen_mode}" "${taxon_dir}"
        checkpoint "FASTA sequences appended for taxid ${taxid}"
    else
        echo "No genome could be downloaded for taxid ${taxid}; skipping."
    fi
done < "${tmp_selected}"

if [ ! -s "${reference_fasta}" ]; then
    echo "No reference sequences were downloaded."
    exit 1
fi

awk -F '\t' 'NR > 1 {print $7 "\t" $1}' "${manifest}" > "${acc2tax}"

checkpoint "Building samtools FASTA index for targeted reference"
samtools faidx "${reference_fasta}"
checkpoint "samtools FASTA index done"
checkpoint "Building BWA index for targeted reference"
bwa index "${reference_fasta}"
checkpoint "BWA index done"

checkpoint "Compressing targeted reference archive"
tar --use-compress-program=pigz -cf "${archive}" "${reference_fasta}" "${reference_fasta}.fai" "${reference_fasta}".* "${manifest}" "${acc2tax}" "${tmp_selected}"
checkpoint "Targeted reference archive ready"

echo
echo "Targeted reference ready."
echo "Reference FASTA: ${reference_fasta}"
echo "Manifest: ${manifest}"
echo "acc2tax: ${acc2tax}"
echo "Archive: ${archive}"
