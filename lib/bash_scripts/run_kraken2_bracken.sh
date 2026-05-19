#!/usr/bin/env bash

set -euo pipefail

mode="single"
db_name=""
confidence="0.05"
tax_level="S"
read_length="300"
bracken_threshold="10"
memory_mapping="no"
fastp_trim="yes"
reads_pattern=""
fwd_pattern=""
rev_pattern=""

checkpoint() {
    echo
    echo "== checkpoint == $*"
}

while getopts i:s:1:2:t:m:d:c:l:r:T:M:f:o:O:a: flag
do
    case "${flag}" in
        i) dir="${OPTARG}";;
        s) reads_pattern="${OPTARG}";;
        1) fwd_pattern="${OPTARG}";;
        2) rev_pattern="${OPTARG}";;
        t) threads="${OPTARG}";;
        m) mode="${OPTARG}";;
        d) db_name="${OPTARG}";;
        c) confidence="${OPTARG}";;
        l) tax_level="${OPTARG}";;
        r) read_length="${OPTARG}";;
        T) bracken_threshold="${OPTARG}";;
        M) memory_mapping="${OPTARG}";;
        f) fastp_trim="${OPTARG}";;
        o) abundance_matrix="${OPTARG}";;
        O) relative_abundance_matrix="${OPTARG}";;
        a) results_archive="${OPTARG}";;
        \?) echo "usage: run_kraken2_bracken.sh -i dir [-s reads|-1 fwd -2 rev] -t threads -m single|paired -d db -c confidence -l tax_level -r read_length -T bracken_threshold -M yes|no -f yes|no -o abundance_matrix -O relative_matrix -a archive"; exit 1;;
    esac
done

required_vars=(dir threads db_name abundance_matrix relative_abundance_matrix results_archive)
for var_name in "${required_vars[@]}"; do
    if [ -z "${!var_name:-}" ]; then
        echo "Missing required option: ${var_name}"
        exit 1
    fi
done

cd "${dir}"

db_root="${KRAKEN2_DB_ROOT:-/app/lib/kraken2/db}"
case "${db_name}" in
    /*) kraken_db="${db_name}" ;;
    custom) kraken_db="${db_root}/custom" ;;
    *) kraken_db="${db_root}/${db_name}" ;;
esac

echo "Kraken2 database: ${kraken_db}"
if [ ! -f "${kraken_db}/hash.k2d" ] || [ ! -f "${kraken_db}/opts.k2d" ] || [ ! -f "${kraken_db}/taxo.k2d" ]; then
    echo "Kraken2 database is missing or incomplete."
    echo "Expected hash.k2d, opts.k2d and taxo.k2d in ${kraken_db}"
    exit 1
fi

if ! ls "${kraken_db}/database${read_length}mers."* >/dev/null 2>&1; then
    echo "No Bracken database for ${read_length} bp reads was found in ${kraken_db}."
    echo "Choose another Bracken read length or rebuild/add the Bracken database files."
    exit 1
fi
checkpoint "Kraken2/Bracken database validation done"

outdir="kraken2_bracken"
rm -rf "${outdir}"
mkdir -p "${outdir}"
fastp_report_dir="${outdir}/fastp_reports"
fastp_trim_dir="${outdir}/fastp_trimmed"

if [ "${fastp_trim}" = "yes" ]; then
    if ! command -v fastp >/dev/null 2>&1; then
        echo "fastp trimming was requested, but fastp is not available in PATH."
        echo "Rebuild the image with fastp in the Kraken2/Bracken conda environment."
        exit 1
    fi

    mkdir -p "${fastp_report_dir}" "${fastp_trim_dir}"
fi

is_fastq_file() {
    local lower
    lower="$(printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]')"

    case "${lower}" in
        *.fastq|*.fastq.gz|*.fq|*.fq.gz) return 0 ;;
        *) return 1 ;;
    esac
}

sample_name_from_file() {
    local file="$1"
    local sample

    sample="$(basename "${file}")"
    sample="${sample%.gz}"
    sample="${sample%.fastq}"
    sample="${sample%.fq}"
    sample="${sample%.fasta}"
    sample="${sample%.fa}"
    sample="${sample%_R1}"
    sample="${sample%_R2}"
    sample="${sample%_1}"
    sample="${sample%_2}"

    printf '%s\n' "${sample}"
}

run_one_sample() {
    local sample="$1"
    shift

    local report="${outdir}/${sample}.kraken2.report"
    local output="${outdir}/${sample}.kraken2.output"
    local bracken="${outdir}/${sample}.bracken.${tax_level}.tsv"
    local bracken_report="${outdir}/${sample}.bracken.${tax_level}.report"
    local kraken_options=()

    if [ "${memory_mapping}" = "yes" ]; then
        kraken_options+=(--memory-mapping)
    fi

    echo
    echo "Processing sample: ${sample}"
    echo "Kraken2 input files:"
    printf '  %s\n' "$@"

    checkpoint "${sample}: Kraken2 classification started"
    kraken2 \
        --db "${kraken_db}" \
        --threads "${threads}" \
        --use-names \
        --confidence "${confidence}" \
        --report "${report}" \
        --output "${output}" \
        "${kraken_options[@]}" \
        "$@"
    checkpoint "${sample}: Kraken2 classification done"

    checkpoint "${sample}: Bracken abundance estimation started"
    bracken \
        -d "${kraken_db}" \
        -i "${report}" \
        -o "${bracken}" \
        -w "${bracken_report}" \
        -r "${read_length}" \
        -l "${tax_level}" \
        -t "${bracken_threshold}"
    checkpoint "${sample}: Bracken abundance estimation done"
}

shopt -s nullglob

sample_names=()
if [ "${mode}" = "paired" ]; then
    fwd_pattern="${fwd_pattern//€/*}"
    rev_pattern="${rev_pattern//€/*}"
    fwd_files=( ${fwd_pattern} )
    rev_files=( ${rev_pattern} )

    if [ "${#fwd_files[@]}" -eq 0 ]; then
        echo "No forward FASTQ files matched: ${fwd_pattern}"
        exit 1
    fi

    if [ "${#rev_files[@]}" -eq 0 ]; then
        echo "No reverse FASTQ files matched: ${rev_pattern}"
        exit 1
    fi

    if [ "${#fwd_files[@]}" -ne "${#rev_files[@]}" ]; then
        echo "Different numbers of forward and reverse reads:"
        echo "Forward: ${#fwd_files[@]}"
        echo "Reverse: ${#rev_files[@]}"
        exit 1
    fi

    for idx in "${!fwd_files[@]}"; do
        sample="$(sample_name_from_file "${fwd_files[$idx]}")"
        sample_names+=("${sample}")

        kraken_fwd="${fwd_files[$idx]}"
        kraken_rev="${rev_files[$idx]}"

        if [ "${fastp_trim}" = "yes" ]; then
            if is_fastq_file "${kraken_fwd}" && is_fastq_file "${kraken_rev}"; then
                trimmed_fwd="${fastp_trim_dir}/${sample}.R1.fastp.fastq.gz"
                trimmed_rev="${fastp_trim_dir}/${sample}.R2.fastp.fastq.gz"

                checkpoint "${sample}: fastp trimming started"
                fastp \
                    -i "${kraken_fwd}" \
                    -I "${kraken_rev}" \
                    -o "${trimmed_fwd}" \
                    -O "${trimmed_rev}" \
                    --detect_adapter_for_pe \
                    --thread "${threads}" \
                    --html "${fastp_report_dir}/${sample}.fastp.html" \
                    --json "${fastp_report_dir}/${sample}.fastp.json"
                checkpoint "${sample}: fastp trimming done"

                kraken_fwd="${trimmed_fwd}"
                kraken_rev="${trimmed_rev}"
            else
                echo "Skipping fastp for sample ${sample}: paired inputs are not FASTQ files."
            fi
        fi

        run_one_sample "${sample}" --paired "${kraken_fwd}" "${kraken_rev}"
    done
else
    reads_pattern="${reads_pattern//€/*}"
    read_files=( ${reads_pattern} )

    if [ "${#read_files[@]}" -eq 0 ]; then
        echo "No FASTQ/FASTA files matched: ${reads_pattern}"
        echo "Available sequence files in ${dir}:"
        find . -maxdepth 1 -type f \( -name "*.fastq" -o -name "*.fastq.gz" -o -name "*.fq" -o -name "*.fq.gz" -o -name "*.fasta" -o -name "*.fasta.gz" -o -name "*.fa" -o -name "*.fa.gz" \) -printf "  %f\n" | sort
        exit 1
    fi

    for file in "${read_files[@]}"; do
        sample="$(sample_name_from_file "${file}")"
        sample_names+=("${sample}")

        kraken_file="${file}"

        if [ "${fastp_trim}" = "yes" ]; then
            if is_fastq_file "${kraken_file}"; then
                trimmed_file="${fastp_trim_dir}/${sample}.fastp.fastq.gz"

                checkpoint "${sample}: fastp trimming started"
                fastp \
                    -i "${kraken_file}" \
                    -o "${trimmed_file}" \
                    --thread "${threads}" \
                    --html "${fastp_report_dir}/${sample}.fastp.html" \
                    --json "${fastp_report_dir}/${sample}.fastp.json"
                checkpoint "${sample}: fastp trimming done"

                kraken_file="${trimmed_file}"
            else
                echo "Skipping fastp for sample ${sample}: input is not a FASTQ file."
            fi
        fi

        run_one_sample "${sample}" "${kraken_file}"
    done
fi

checkpoint "Building Kraken2/Bracken long table and matrices"
long_table="${outdir}/bracken_long.${tax_level}.tsv"
taxa_table="${outdir}/taxa.${tax_level}.tsv"

printf "sample\tname\ttaxonomy_id\ttaxonomy_lvl\test_reads\tfraction_total_reads\n" > "${long_table}"
for sample in "${sample_names[@]}"; do
    bracken_file="${outdir}/${sample}.bracken.${tax_level}.tsv"
    awk -F '\t' -v sample="${sample}" 'NR > 1 {print sample "\t" $1 "\t" $2 "\t" $3 "\t" $6 "\t" $7}' "${bracken_file}" >> "${long_table}"
done

tail -n +2 "${long_table}" | cut -f2-4 | sort -u > "${taxa_table}"

write_matrix() {
    local value_column="$1"
    local output_file="$2"

    printf "name\ttaxonomy_id\ttaxonomy_lvl" > "${output_file}"
    for sample in "${sample_names[@]}"; do
        printf "\t%s" "${sample}" >> "${output_file}"
    done
    printf "\n" >> "${output_file}"

    while IFS=$'\t' read -r name taxonomy_id taxonomy_lvl; do
        printf "%s\t%s\t%s" "${name}" "${taxonomy_id}" "${taxonomy_lvl}" >> "${output_file}"
        for sample in "${sample_names[@]}"; do
            awk -F '\t' \
                -v sample="${sample}" \
                -v taxonomy_id="${taxonomy_id}" \
                -v value_column="${value_column}" \
                '$1 == sample && $3 == taxonomy_id {print $value_column; found=1} END {if (!found) print 0}' \
                "${long_table}" | tr -d '\n' | sed 's/^/\t/' >> "${output_file}"
        done
        printf "\n" >> "${output_file}"
    done < "${taxa_table}"
}

write_matrix 5 "${abundance_matrix}"
write_matrix 6 "${relative_abundance_matrix}"
checkpoint "Kraken2/Bracken matrices ready"

cp "${abundance_matrix}" "${outdir}/${abundance_matrix}"
cp "${relative_abundance_matrix}" "${outdir}/${relative_abundance_matrix}"
rm -rf "${fastp_trim_dir}"
checkpoint "Compressing Kraken2/Bracken results archive"
tar -czf "${results_archive}" "${outdir}"
checkpoint "Kraken2/Bracken results archive ready"

echo
echo "Kraken2/Bracken finished."
echo "Abundance matrix: ${abundance_matrix}"
echo "Relative-abundance matrix: ${relative_abundance_matrix}"
echo "Results archive: ${results_archive}"
