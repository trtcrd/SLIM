#!/usr/bin/env bash

set -euo pipefail

mode="single"
mapper="aln"
fastp_trim="yes"
min_mapq="0"
reads_pattern=""
fwd_pattern=""
rev_pattern=""

checkpoint() {
    echo
    echo "== checkpoint == $*"
}

while getopts i:s:1:2:t:m:R:p:f:q:b:a: flag
do
    case "${flag}" in
        i) dir="${OPTARG}";;
        s) reads_pattern="${OPTARG}";;
        1) fwd_pattern="${OPTARG}";;
        2) rev_pattern="${OPTARG}";;
        t) threads="${OPTARG}";;
        m) mode="${OPTARG}";;
        R) reference_fasta="${OPTARG}";;
        p) mapper="${OPTARG}";;
        f) fastp_trim="${OPTARG}";;
        q) min_mapq="${OPTARG}";;
        b) bam_pattern="${OPTARG}";;
        a) archive="${OPTARG}";;
        \?) echo "usage: run_map_to_targeted_reference.sh -i dir [-s reads|-1 fwd -2 rev] -t threads -m single|paired -R reference_fasta -p aln|mem -f yes|no -q min_mapq -b bam_pattern -a archive"; exit 1;;
    esac
done

required_vars=(dir threads reference_fasta bam_pattern archive)
for var_name in "${required_vars[@]}"; do
    if [ -z "${!var_name:-}" ]; then
        echo "Missing required option: ${var_name}"
        exit 1
    fi
done

cd "${dir}"

if [ ! -f "${reference_fasta}" ]; then
    echo "Reference FASTA was not found: ${reference_fasta}"
    exit 1
fi

for cmd in bwa samtools; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "${cmd} is required but is not available in PATH."
        exit 1
    fi
done

if [ "${fastp_trim}" = "yes" ] && ! command -v fastp >/dev/null 2>&1; then
    echo "fastp trimming was requested, but fastp is not available in PATH."
    exit 1
fi

if [ ! -f "${reference_fasta}.bwt" ]; then
    checkpoint "BWA index missing; index build started"
    bwa index "${reference_fasta}"
    checkpoint "BWA index build done"
fi

if [ ! -f "${reference_fasta}.fai" ]; then
    checkpoint "samtools FASTA index build started"
    samtools faidx "${reference_fasta}"
    checkpoint "samtools FASTA index build done"
fi

outdir="targeted_reference_mapping"
fastp_report_dir="${outdir}/fastp_reports"
fastp_trim_dir="${outdir}/fastp_trimmed"
stats_dir="${outdir}/stats"
rm -rf "${outdir}"
mkdir -p "${fastp_report_dir}" "${fastp_trim_dir}" "${stats_dir}"

sample_name_from_file() {
    local sample
    sample="$(basename "$1")"
    sample="${sample%.gz}"
    sample="${sample%.fastq}"
    sample="${sample%.fq}"
    sample="${sample%.fasta}"
    sample="${sample%.fa}"
    sample="${sample%_R1}"
    sample="${sample%_R2}"
    sample="${sample%_r1}"
    sample="${sample%_r2}"
    sample="${sample%_1}"
    sample="${sample%_2}"
    sample="${sample%_1sub}"
    sample="${sample%_2sub}"
    sample="${sample%_fwd}"
    sample="${sample%_rev}"
    printf '%s\n' "${sample}"
}

make_bam_name() {
    local sample="$1"
    if [[ "${bam_pattern}" == *"*"* ]]; then
        printf '%s\n' "${bam_pattern/\*/${sample}}"
    else
        printf '%s\n' "${sample}.${bam_pattern}"
    fi
}

finish_bam() {
    local sample="$1"
    local bam="$2"
    local filtered="${bam%.bam}.mapq${min_mapq}.bam"
    local md_tmp="${bam%.bam}.md.bam"

    if [ "${min_mapq}" != "0" ]; then
        samtools view -@ "${threads}" -b -q "${min_mapq}" "${bam}" > "${filtered}"
        mv "${filtered}" "${bam}"
    fi

    samtools calmd -@ "${threads}" -b "${bam}" "${reference_fasta}" > "${md_tmp}"
    mv "${md_tmp}" "${bam}"
    samtools index -@ "${threads}" "${bam}"
    samtools flagstat -@ "${threads}" "${bam}" > "${stats_dir}/${sample}.flagstat.txt"
    samtools idxstats "${bam}" > "${stats_dir}/${sample}.idxstats.tsv"
}

map_single() {
    local sample="$1"
    local reads="$2"
    local bam="$3"
    local sai

    echo
    echo "Mapping sample: ${sample}"
    echo "Reads: ${reads}"
    echo "BAM: ${bam}"

    if [ "${mapper}" = "mem" ]; then
        checkpoint "${sample}: BWA MEM mapping and samtools sort started"
        bwa mem -t "${threads}" "${reference_fasta}" "${reads}" |
            samtools sort -@ "${threads}" -o "${bam}" -
        checkpoint "${sample}: BWA MEM mapping and samtools sort done"
    else
        sai="${outdir}/${sample}.sai"
        checkpoint "${sample}: BWA ALN started"
        bwa aln -t "${threads}" "${reference_fasta}" "${reads}" > "${sai}"
        checkpoint "${sample}: BWA ALN done"
        checkpoint "${sample}: BWA SAMSE and samtools sort started"
        bwa samse "${reference_fasta}" "${sai}" "${reads}" |
            samtools sort -@ "${threads}" -o "${bam}" -
        checkpoint "${sample}: BWA SAMSE and samtools sort done"
    fi

    checkpoint "${sample}: BAM finalisation started"
    finish_bam "${sample}" "${bam}"
    checkpoint "${sample}: BAM finalisation done"
}

map_paired() {
    local sample="$1"
    local fwd="$2"
    local rev="$3"
    local bam="$4"
    local sai_fwd
    local sai_rev

    echo
    echo "Mapping sample: ${sample}"
    echo "Forward: ${fwd}"
    echo "Reverse: ${rev}"
    echo "BAM: ${bam}"

    if [ "${mapper}" = "mem" ]; then
        checkpoint "${sample}: BWA MEM paired mapping and samtools sort started"
        bwa mem -t "${threads}" "${reference_fasta}" "${fwd}" "${rev}" |
            samtools sort -@ "${threads}" -o "${bam}" -
        checkpoint "${sample}: BWA MEM paired mapping and samtools sort done"
    else
        sai_fwd="${outdir}/${sample}.R1.sai"
        sai_rev="${outdir}/${sample}.R2.sai"
        checkpoint "${sample}: BWA ALN forward read started"
        bwa aln -t "${threads}" "${reference_fasta}" "${fwd}" > "${sai_fwd}"
        checkpoint "${sample}: BWA ALN forward read done"
        checkpoint "${sample}: BWA ALN reverse read started"
        bwa aln -t "${threads}" "${reference_fasta}" "${rev}" > "${sai_rev}"
        checkpoint "${sample}: BWA ALN reverse read done"
        checkpoint "${sample}: BWA SAMPE and samtools sort started"
        bwa sampe "${reference_fasta}" "${sai_fwd}" "${sai_rev}" "${fwd}" "${rev}" |
            samtools sort -@ "${threads}" -o "${bam}" -
        checkpoint "${sample}: BWA SAMPE and samtools sort done"
    fi

    checkpoint "${sample}: BAM finalisation started"
    finish_bam "${sample}" "${bam}"
    checkpoint "${sample}: BAM finalisation done"
}

shopt -s nullglob

if [ "${mode}" = "paired" ]; then
    fwd_pattern="${fwd_pattern//€/*}"
    rev_pattern="${rev_pattern//€/*}"
    fwd_files=( ${fwd_pattern} )
    rev_files=( ${rev_pattern} )

    if [ "${#fwd_files[@]}" -eq 0 ] || [ "${#rev_files[@]}" -eq 0 ]; then
        echo "No paired FASTQ files matched."
        echo "Forward pattern: ${fwd_pattern}"
        echo "Reverse pattern: ${rev_pattern}"
        exit 1
    fi

    if [ "${#fwd_files[@]}" -ne "${#rev_files[@]}" ]; then
        echo "Different numbers of forward and reverse reads."
        exit 1
    fi

    for idx in "${!fwd_files[@]}"; do
        sample="$(sample_name_from_file "${fwd_files[$idx]}")"
        fwd="${fwd_files[$idx]}"
        rev="${rev_files[$idx]}"

        if [ "${fastp_trim}" = "yes" ]; then
            trimmed_fwd="${fastp_trim_dir}/${sample}.R1.fastp.fastq.gz"
            trimmed_rev="${fastp_trim_dir}/${sample}.R2.fastp.fastq.gz"
            checkpoint "${sample}: fastp trimming started"
            fastp \
                -i "${fwd}" \
                -I "${rev}" \
                -o "${trimmed_fwd}" \
                -O "${trimmed_rev}" \
                --detect_adapter_for_pe \
                --thread "${threads}" \
                --html "${fastp_report_dir}/${sample}.fastp.html" \
                --json "${fastp_report_dir}/${sample}.fastp.json"
            checkpoint "${sample}: fastp trimming done"
            fwd="${trimmed_fwd}"
            rev="${trimmed_rev}"
        fi

        map_paired "${sample}" "${fwd}" "${rev}" "$(make_bam_name "${sample}")"
    done
else
    reads_pattern="${reads_pattern//€/*}"
    read_files=( ${reads_pattern} )

    if [ "${#read_files[@]}" -eq 0 ]; then
        echo "No FASTQ files matched: ${reads_pattern}"
        exit 1
    fi

    for reads in "${read_files[@]}"; do
        sample="$(sample_name_from_file "${reads}")"
        map_reads="${reads}"

        if [ "${fastp_trim}" = "yes" ]; then
            trimmed="${fastp_trim_dir}/${sample}.fastp.fastq.gz"
            checkpoint "${sample}: fastp trimming started"
            fastp \
                -i "${map_reads}" \
                -o "${trimmed}" \
                --thread "${threads}" \
                --html "${fastp_report_dir}/${sample}.fastp.html" \
                --json "${fastp_report_dir}/${sample}.fastp.json"
            checkpoint "${sample}: fastp trimming done"
            map_reads="${trimmed}"
        fi

        map_single "${sample}" "${map_reads}" "$(make_bam_name "${sample}")"
    done
fi

rm -rf "${fastp_trim_dir}"
checkpoint "Compressing targeted-reference mapping archive"
tar -czf "${archive}" "${outdir}" *.bam *.bam.bai
checkpoint "Targeted-reference mapping archive ready"

echo
echo "Mapping finished."
echo "BAM pattern: ${bam_pattern}"
echo "Archive: ${archive}"
