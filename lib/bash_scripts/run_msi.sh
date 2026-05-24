#!/usr/bin/env bash

# This script runs the MSI pipeline for one primer set at a time.

checkpoint() {
    echo
    echo "== checkpoint == $*"
}

while getopts i:y:t:o:p:C:a:A:m:M:q:x:X:b:c: flag
do
    case "${flag}" in
        i) dir="$( cd -P "$( dirname "${OPTARG}" )" >/dev/null 2>&1 && pwd )/$( echo ${OPTARG%\/} | rev | cut -f1 -d '/' | rev )/";;
        y) input_file="${OPTARG}";;
        t) threads="${OPTARG}";;
        o) output_file="${OPTARG}";;
        p) primers="${OPTARG}";;
        C) cluster_min_reads="${OPTARG}";;
        a) cd_hit_cluster_threshold="${OPTARG}";;
        A) primer_max_error="${OPTARG}";;
        m) min_length="${OPTARG}";;
        M) max_length="${OPTARG}";;
        q) min_quality="${OPTARG}";;
        x) clust_mapped_threshold="${OPTARG}";;
        X) clust_aligned_threshold="${OPTARG}";;
        \?) echo "usage: bash run_msi.sh [-i|y|t|o|p|C|a|A|m|M|q|x|X]"; exit 1;;
    esac
done

if [[ "${input_file}" == *'€'* ]]; then
    echo "more than one fastq file"
    output_file=$(echo "${output_file}" | sed 's/\*/\€/g')
    output_sufix=${output_file/${input_file/.fastq/}/}
    input_file=$(echo "${input_file}" | sed 's/\€/\*/g')
else
    output_sufix=${output_file/${input_file/.fastq/}/}
fi

echo "output_sufix: ${output_sufix}"

# Load MSI runtime environment.
export MSI_DIR=/app/lib/msi

checkpoint "MSI runtime environment setup started"
if [ -f "${MSI_DIR}/msi_env.sh" ]; then
    source "${MSI_DIR}/msi_env.sh"
fi

export PATH="${MSI_DIR}/bin:${MSI_DIR}/python/bin:/root/.local/bin:${PATH}"
export PYTHONUSERBASE="${MSI_DIR}/python"

for sitepkg in "${MSI_DIR}"/python/lib/python*/site-packages; do
    if [ -d "${sitepkg}" ]; then
        export PYTHONPATH="${sitepkg}:${MSI_DIR}:${PYTHONPATH:-}"
    fi
done

hash -r
checkpoint "MSI runtime environment setup done"

cd "${dir}" || exit 1

shopt -s nullglob
fastq_files=( ${input_file} )

if [ ${#fastq_files[@]} -eq 0 ]; then
    echo "No FASTQ files matched: ${input_file}"
    exit 1
fi

config_file="${dir}params_file.cfg"

checkpoint "MSI configuration file creation started"
cat <<EOF > "${config_file}"
TL_DIR="${dir}input_msi"
OUT_FOLDER="${dir}"
THREADS=${threads}
METADATAFILE="metadata.tsv"
CLUSTER_MIN_READS=${cluster_min_reads}
CD_HIT_CLUSTER_THRESHOLD=${cd_hit_cluster_threshold}
PRIMER_MAX_ERROR=${primer_max_error}

MIN_LEN=${min_length}
MAX_LEN=${max_length}
MIN_QUAL=${min_quality}

EXPERIMENT_ID=.
CLUST_MAPPED_THRESHOLD=${clust_mapped_threshold}
CLUST_ALIGNED_THRESHOLD=${clust_aligned_threshold}
EOF
checkpoint "MSI configuration file creation done"

checkpoint "MSI primer parsing and metadata creation started"
primer_f=$(sed -n '2p' "${primers}")
primer_r=$(sed -n '4p' "${primers}")

if [[ "${primer_f}" == *'-'* ]]; then
    primer_f=$(echo "${primer_f}" | sed 's/-//g')
fi

if [[ "${primer_r}" == *'-'* ]]; then
    primer_r=$(echo "${primer_r}" | sed 's/-//g')
fi

echo -e "sample_id\tss_sample_id\tprimer_set\tprimer_f\tprimer_r\tmin_length\tmax_length\ttarget_gene\tbarcode_name" > metadata.tsv

i=1
dir2="${dir}/redirected_fastq/"
mkdir -p "${dir2}"

for file in "${fastq_files[@]}"; do
    base=$(basename "${file}")
    sample_id="${base%.fastq}"

    echo -e "${sample_id}\tsample_${i}\t${primers}\t${primer_f}\t${primer_r}\t${min_length}\t${max_length}\t${primers}\t${sample_id}" >> metadata.tsv
    i=$((i+1))

    cp "${file}" "${dir2}${sample_id}.fastq"
done
checkpoint "MSI primer parsing and metadata creation done"

mkdir -p input_msi

checkpoint "MSI input FASTQ preparation started"
for file in "${fastq_files[@]}"; do
    base=$(basename "${file}")
    sample_id="${base%.fastq}"

    mkdir -p "input_msi/${sample_id}"
    sed -i "s/\t/ /g" "${dir2}${sample_id}.fastq"
    gzip -c "${dir2}${sample_id}.fastq" > "input_msi/${sample_id}/${sample_id}.fastq.gz"
done
checkpoint "MSI input FASTQ preparation done"

checkpoint "MSI core pipeline started"
msi -c "${config_file}" -i "${dir}input_msi"
checkpoint "MSI core pipeline done"

empty_files=''
there_are_empty_files='N'

checkpoint "MSI centroid export started"
for file in "${fastq_files[@]}"; do
    base=$(basename "${file}")
    sample_id="${base%.fastq}"

    cp "${dir}${sample_id}/${sample_id}.centroids.fasta" "${dir}${sample_id}${output_sufix}"
    sed -i 's/:\([^=]*=\)/;\1/g' "${dir}${sample_id}${output_sufix}"

    if [ ! -s "${dir}${sample_id}${output_sufix}" ]; then
        empty_files="${empty_files} ${sample_id}"
        there_are_empty_files='Y'
    else
        rm -r "${dir}${sample_id}"
    fi
done
checkpoint "MSI centroid export done"

if [ "${there_are_empty_files}" == 'Y' ]; then
    echo "The following files are empty: ${empty_files}"
    exit 1
else
    rm -r "${dir2}"
    exit 0
fi
