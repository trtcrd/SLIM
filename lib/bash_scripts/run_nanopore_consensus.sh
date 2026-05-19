#!/usr/bin/env bash

set -euo pipefail

min_length="1"
max_length="2147483647"
maxee="0"
cluster_id="0.90"
min_cluster_size="5"
medaka_model="auto"
primer_file=""
trim_primers="yes"
polish_medaka="yes"
primer_error_rate="0.20"
discard_untrimmed="no"

checkpoint() {
    echo
    echo "== checkpoint == $*"
}

while getopts i:y:p:t:m:M:e:r:E:u:P:c:s:k:o:O:S:a: flag
do
    case "${flag}" in
        i) dir="${OPTARG}";;
        y) reads_pattern="${OPTARG}";;
        p) primer_file="${OPTARG}";;
        t) threads="${OPTARG}";;
        m) min_length="${OPTARG}";;
        M) max_length="${OPTARG}";;
        e) maxee="${OPTARG}";;
        r) trim_primers="${OPTARG}";;
        E) primer_error_rate="${OPTARG}";;
        u) discard_untrimmed="${OPTARG}";;
        P) polish_medaka="${OPTARG}";;
        c) cluster_id="${OPTARG}";;
        s) min_cluster_size="${OPTARG}";;
        k) medaka_model="${OPTARG}";;
        o) consensus_fasta="${OPTARG}";;
        O) otu_table="${OPTARG}";;
        S) stats_tsv="${OPTARG}";;
        a) results_archive="${OPTARG}";;
        \?) echo "usage: run_nanopore_consensus.sh -i dir -y reads_pattern [-p primers.fasta] -t threads -m min_len -M max_len -e maxee -r yes|no -E primer_error_rate -u yes|no -P yes|no -c cluster_id -s min_cluster_size -k medaka_model|auto -o consensus.fasta -O otu_table.tsv -S stats.tsv -a archive.tar.gz"; exit 1;;
    esac
done

required_vars=(dir reads_pattern threads consensus_fasta otu_table stats_tsv results_archive)
for var_name in "${required_vars[@]}"; do
    if [ -z "${!var_name:-}" ]; then
        echo "Missing required option: ${var_name}"
        exit 1
    fi
done

cd "${dir}"

reads_pattern="${reads_pattern//€/*}"

shopt -s nullglob
read_files=( ${reads_pattern} )

if [ "${#read_files[@]}" -eq 0 ]; then
    echo "No FASTQ files matched: ${reads_pattern}"
    echo "Available FASTQ files in ${dir}:"
    find . -maxdepth 1 -type f \( -name "*.fastq" -o -name "*.fastq.gz" -o -name "*.fq" -o -name "*.fq.gz" \) -printf "  %f\n" | sort
    exit 1
fi

vsearch_bin="${VSEARCH_BIN:-/app/lib/vsearch/bin/vsearch}"
if [ ! -x "${vsearch_bin}" ]; then
    vsearch_bin="$(command -v vsearch || true)"
fi

if [ -z "${vsearch_bin}" ] || [ ! -x "${vsearch_bin}" ]; then
    echo "VSEARCH was not found. Expected /app/lib/vsearch/bin/vsearch or vsearch in PATH."
    exit 1
fi

for tool in minimap2; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "${tool} was not found in PATH."
        echo "Rebuild the image with the nanopore-consensus conda environment."
        exit 1
    fi
done

if [ "${polish_medaka}" = "yes" ] && ! command -v medaka_consensus >/dev/null 2>&1; then
    echo "Medaka polishing was requested, but medaka_consensus was not found in PATH."
    echo "Rebuild the image with medaka in the nanopore-consensus conda environment, or disable Medaka polishing."
    exit 1
fi

if [ -n "${primer_file}" ] && [ ! -f "${primer_file}" ]; then
    echo "Primer FASTA file was provided but does not exist: ${primer_file}"
    exit 1
fi

cutadapt_bin="$(command -v cutadapt || true)"

if [ -n "${primer_file}" ] && [ "${trim_primers}" = "yes" ] && [ -z "${cutadapt_bin}" ]; then
    echo "Primer trimming was requested, but cutadapt was not found."
    echo "Rebuild the image with cutadapt in the nanopore-consensus environment, or hot-fix the running container:"
    echo "  conda install -n nanopore-consensus -y -c conda-forge -c bioconda cutadapt"
    exit 1
fi

outdir="nanopore_consensus"
rm -rf "${outdir}" "${consensus_fasta}" "${otu_table}" "${stats_tsv}" "${results_archive}"
mkdir -p "${outdir}"/{primer_trimmed,filtered,dereplicated,drafts,retained_drafts,mappings,medaka,per_sample,otu_counts}

printf "sample\traw_reads\tfiltered_reads\tdereplicated_sequences\tdraft_clusters\tretained_clusters\tconsensus_sequences\tpolishing\n" > "${stats_tsv}"
: > "${consensus_fasta}"

sample_name_from_file() {
    local file="$1"
    local sample

    sample="$(basename "${file}")"
    sample="${sample%.gz}"
    sample="${sample%.fastq}"
    sample="${sample%.fq}"

    printf '%s\n' "${sample}"
}

count_fastq_reads() {
    local file="$1"

    if [[ "${file}" == *.gz ]]; then
        gzip -cd "${file}" | awk 'END {print int(NR / 4)}'
    else
        awk 'END {print int(NR / 4)}' "${file}"
    fi
}

count_fasta_records() {
    local file="$1"

    if [ ! -s "${file}" ]; then
        printf '0\n'
        return
    fi

    grep -c '^>' "${file}" || true
}

reverse_complement() {
    printf '%s\n' "$1" | tr '[:lower:]' '[:upper:]' | tr 'ACGTRYKMSWBDHVN' 'TGCAYRMKSWVHDBN' | rev
}

load_primers() {
    local file="$1"
    local seqs

    seqs="$(awk '
        /^>/ {
            if (seq != "") {
                print seq
                seq = ""
            }
            next
        }
        {
            gsub(/[[:space:]-]/, "")
            seq = seq toupper($0)
        }
        END {
            if (seq != "")
                print seq
        }
    ' "${file}")"

    primer_f="$(printf '%s\n' "${seqs}" | sed -n '1p')"
    primer_r="$(printf '%s\n' "${seqs}" | sed -n '2p')"

    if [ -z "${primer_f}" ] || [ -z "${primer_r}" ]; then
        echo "Primer FASTA must contain at least two sequences: forward primer first, reverse primer second."
        exit 1
    fi

    primer_r_rc="$(reverse_complement "${primer_r}")"
}

trim_primers_from_reads() {
    local input="$1"
    local output="$2"
    local sample="$3"
    local log_file="${outdir}/primer_trimmed/${sample}.cutadapt.log"
    local status
    local cutadapt_options

    cutadapt_options=(
        -e "${primer_error_rate}"
        -g "${primer_f}...${primer_r_rc}"
        --cores "${threads}"
        -o "${output}"
    )

    if [ "${discard_untrimmed}" = "yes" ]; then
        cutadapt_options+=(--discard-untrimmed)
    fi

    echo "Trimming primers with cutadapt for sample: ${sample}"
    echo "Forward primer: ${primer_f}"
    echo "Reverse primer: ${primer_r}"
    echo "Reverse primer reverse-complement used for trimming: ${primer_r_rc}"
    echo "Primer max error rate: ${primer_error_rate}"
    echo "Discard reads without linked primer match: ${discard_untrimmed}"
    echo "cutadapt executable: ${cutadapt_bin}"
    echo "cutadapt log: ${log_file}"

    set +e
    if "${cutadapt_bin}" --help 2>/dev/null | grep -q -- '--revcomp'; then
        "${cutadapt_bin}" \
            --revcomp \
            "${cutadapt_options[@]}" \
            "${input}" > "${log_file}" 2>&1
        status=$?
    else
        echo "cutadapt --revcomp is not available; trimming only reads already in forward orientation." | tee "${log_file}"
        "${cutadapt_bin}" \
            "${cutadapt_options[@]}" \
            "${input}" >> "${log_file}" 2>&1
        status=$?
    fi
    set -e

    if [ "${status}" -ne 0 ]; then
        echo
        echo "cutadapt failed for sample ${sample} with exit code ${status}."
        echo "--- cutadapt log ---"
        cat "${log_file}" || true
        echo "--- end cutadapt log ---"
        exit "${status}"
    fi

    echo "cutadapt finished for sample ${sample}."
    echo "--- cutadapt summary ---"
    grep -E "^(Total reads processed|Reads with adapters|Reads written|Total basepairs processed|Quality-trimmed|Total written|Pairs written)" "${log_file}" || tail -n 20 "${log_file}" || true
    echo "--- end cutadapt summary ---"
}

filter_centroids_by_size() {
    local input="$1"
    local output="$2"
    local minimum="$3"

    awk -v min="${minimum}" '
        /^>/ {
            header = $0
            size = 1
            if (header ~ /;size=[0-9]+/) {
                sub(/^.*;size=/, "", header)
                sub(/;.*/, "", header)
                size = header + 0
            }
            keep = (size >= min)
        }
        keep { print }
    ' "${input}" > "${output}"
}

rename_headers_with_sample() {
    local input="$1"
    local output="$2"
    local sample="$3"

    awk -v sample="${sample}" '
        /^>/ {
            count += 1
            sub(/^>/, "")
            print ">" sample "_consensus_" count " " $0
            next
        }
        { print }
    ' "${input}" > "${output}"
}

run_medaka_polishing() {
    local sample="$1"
    local log_file="${outdir}/medaka/${sample}.medaka.log"
    shift

    local status

    set +e
    medaka_consensus "$@" > "${log_file}" 2>&1
    status=$?
    set -e

    cat "${log_file}"

    if [ "${status}" -ne 0 ]; then
        echo
        echo "Medaka failed for sample ${sample} with exit code ${status}."

        if [ "${status}" -eq 137 ]; then
            echo "Exit code 137 usually means the process was killed by the operating system, often because the container ran out of RAM."
            echo "Try lowering the number of threads or increasing Docker/Podman memory."
        fi

        echo "Available memory inside the container:"
        free -h || true

        echo "Medaka executable: $(command -v medaka_consensus)"
        echo "Medaka model requested: ${medaka_model}"

        if [ "${medaka_model}" = "auto" ]; then
            echo "The module did not pass a Medaka model because the model field is set to auto."
            echo "If this Medaka version requires an explicit model, set the module's Medaka model field to the model matching the basecaller/chemistry."
        fi

        if [ "${status}" -eq 132 ]; then
            echo "Exit code 132 is an illegal CPU instruction. This is usually a binary/CPU compatibility problem, not a RAM problem."
            echo "Try disabling Medaka polishing in the module options, or rebuild/install Medaka for this machine."
        else
            echo "Installed Medaka models, if the command is available:"
            medaka tools list_models 2>/dev/null || true
        fi

        exit "${status}"
    fi
}

write_otu_table() {
    local table="$1"
    local otu_ids_file="${outdir}/otu_counts/otu_ids.txt"
    local sample_order_file="${outdir}/otu_counts/sample_order.txt"
    local mapping_file
    local counts_file
    local otu_id
    local sample
    local count

    grep '^>' "${consensus_fasta}" | sed 's/^>//; s/[[:space:]].*$//' > "${otu_ids_file}"
    printf '%s\n' "${sample_names[@]}" > "${sample_order_file}"

    if [ ! -s "${otu_ids_file}" ]; then
        echo "No polished consensus sequences were available for OTU table creation."
        exit 1
    fi

    for idx in "${!sample_names[@]}"; do
        sample="${sample_names[$idx]}"
        mapping_file="${outdir}/otu_counts/${sample}.reads_to_consensus.paf"
        counts_file="${outdir}/otu_counts/${sample}.counts.tsv"

        checkpoint "${sample}: minimap2 final-consensus mapping for OTU counts started"
        minimap2 -x map-ont -t "${threads}" "${consensus_fasta}" "${sample_filtered_fastqs[$idx]}" > "${mapping_file}"
        checkpoint "${sample}: minimap2 final-consensus mapping for OTU counts done"

        checkpoint "${sample}: best-hit read counting started"
        awk '
            BEGIN { OFS = "\t" }
            {
                read = $1
                target = $6
                matches = $10 + 0
                mapq = $12 + 0

                if (!(read in best_matches) || matches > best_matches[read] || (matches == best_matches[read] && mapq > best_mapq[read])) {
                    best_matches[read] = matches
                    best_mapq[read] = mapq
                    best_target[read] = target
                }
            }
            END {
                for (read in best_target)
                    counts[best_target[read]] += 1
                for (target in counts)
                    print target, counts[target]
            }
        ' "${mapping_file}" > "${counts_file}"
        checkpoint "${sample}: best-hit read counting done"
    done

    {
        printf "OTU"
        for sample in "${sample_names[@]}"; do
            printf "\t%s" "${sample}"
        done
        printf "\n"

        while IFS= read -r otu_id; do
            printf "%s" "${otu_id}"

            for sample in "${sample_names[@]}"; do
                counts_file="${outdir}/otu_counts/${sample}.counts.tsv"
                count="$(awk -v otu="${otu_id}" '$1 == otu { print $2; found = 1 } END { if (!found) print 0 }' "${counts_file}")"
                printf "\t%s" "${count}"
            done

            printf "\n"
        done < "${otu_ids_file}"
    } > "${table}"
}

checkpoint "Nanopore consensus input validation done"
echo "Nanopore consensus input files:"
printf '  %s\n' "${read_files[@]}"
echo "VSEARCH: ${vsearch_bin}"
echo "minimap2: $(command -v minimap2)"
if [ "${polish_medaka}" = "yes" ]; then
    echo "medaka_consensus: $(command -v medaka_consensus)"
    python - <<'PY' || true
try:
    import torch
    print("Medaka PyTorch CUDA available: {}".format(torch.cuda.is_available()))
    if torch.cuda.is_available():
        print("Medaka PyTorch CUDA devices: {}".format(torch.cuda.device_count()))
except Exception as exc:
    print("Unable to inspect Medaka/PyTorch CUDA status: {}".format(exc))
PY
else
    echo "medaka_consensus: disabled"
fi
echo "Medaka polishing: ${polish_medaka}"
echo "Medaka model: ${medaka_model}"
if [ -n "${primer_file}" ]; then
    echo "Primer FASTA: ${primer_file}"
    echo "Trim primers: ${trim_primers}"
    if [ "${trim_primers}" = "yes" ]; then
        echo "Primer max error rate: ${primer_error_rate}"
        echo "Discard reads without linked primer match: ${discard_untrimmed}"
        load_primers "${primer_file}"
    fi
else
    echo "Primer FASTA: none"
fi

sample_names=()
sample_filtered_fastqs=()

for read_file in "${read_files[@]}"; do
    sample="$(sample_name_from_file "${read_file}")"

    filtered_fastq="${outdir}/filtered/${sample}.filtered.fastq"
    filtered_fasta="${outdir}/filtered/${sample}.filtered.fasta"
    derep_fasta="${outdir}/dereplicated/${sample}.derep.fasta"
    sorted_derep_fasta="${outdir}/dereplicated/${sample}.derep.sorted.fasta"
    draft_fasta="${outdir}/drafts/${sample}.drafts.fasta"
    retained_fasta="${outdir}/retained_drafts/${sample}.drafts.min${min_cluster_size}.fasta"
    paf_file="${outdir}/mappings/${sample}.reads_to_drafts.paf"
    medaka_dir="${outdir}/medaka/${sample}"
    sample_consensus="${outdir}/per_sample/${sample}.consensus.fasta"

    echo
    echo "Processing sample: ${sample}"

    raw_reads="$(count_fastq_reads "${read_file}")"
    preprocessing_fastq="${read_file}"

    if [ -n "${primer_file}" ] && [ "${trim_primers}" = "yes" ]; then
        primer_trimmed_fastq="${outdir}/primer_trimmed/${sample}.primer_trimmed.fastq"
        checkpoint "${sample}: primer trimming started"
        trim_primers_from_reads "${read_file}" "${primer_trimmed_fastq}" "${sample}"
        checkpoint "${sample}: primer trimming done"

        primer_trimmed_reads="$(count_fastq_reads "${primer_trimmed_fastq}")"
        if [ "${primer_trimmed_reads}" -eq 0 ]; then
            echo "No reads retained after primer trimming for sample ${sample}."
            echo "Check primer orientation/order or disable primer trimming to keep primers in the output."
            exit 1
        fi

        preprocessing_fastq="${primer_trimmed_fastq}"
    elif [ -n "${primer_file}" ]; then
        echo "Primer FASTA was provided, but primer trimming is disabled; primers will be kept in consensus sequences."
    fi

    filter_options=(
        --fastq_filter "${preprocessing_fastq}"
        --fastq_qmin 0
        --fastq_qmax 93
        --fastq_minlen "${min_length}"
        --fastq_maxlen "${max_length}"
        --fastqout "${filtered_fastq}"
        --threads "${threads}"
    )

    if [ "${maxee}" != "0" ] && [ "${maxee}" != "0.0" ]; then
        filter_options+=(--fastq_maxee "${maxee}")
    fi

    checkpoint "${sample}: VSEARCH read filtering started"
    "${vsearch_bin}" "${filter_options[@]}"
    checkpoint "${sample}: VSEARCH read filtering done"

    filtered_reads="$(count_fastq_reads "${filtered_fastq}")"
    if [ "${filtered_reads}" -eq 0 ]; then
        echo "No reads survived filtering for sample ${sample}."
        exit 1
    fi

    sample_names+=("${sample}")
    sample_filtered_fastqs+=("${filtered_fastq}")

    awk 'NR % 4 == 1 {sub(/^@/, ">"); print; next} NR % 4 == 2 {print}' "${filtered_fastq}" > "${filtered_fasta}"

    checkpoint "${sample}: VSEARCH dereplication started"
    "${vsearch_bin}" \
        --derep_fulllength "${filtered_fasta}" \
        --output "${derep_fasta}" \
        --sizeout \
        --relabel "${sample}_derep_" \
        --threads "${threads}"
    checkpoint "${sample}: VSEARCH dereplication done"

    derep_count="$(count_fasta_records "${derep_fasta}")"
    if [ "${derep_count}" -eq 0 ]; then
        echo "No dereplicated sequences were produced for sample ${sample}."
        exit 1
    fi

    checkpoint "${sample}: VSEARCH dereplicated reads sorting started"
    "${vsearch_bin}" \
        --sortbysize "${derep_fasta}" \
        --output "${sorted_derep_fasta}" \
        --sizein \
        --sizeout
    checkpoint "${sample}: VSEARCH dereplicated reads sorting done"

    checkpoint "${sample}: VSEARCH clustering started"
    "${vsearch_bin}" \
        --cluster_size "${sorted_derep_fasta}" \
        --id "${cluster_id}" \
        --centroids "${draft_fasta}" \
        --sizein \
        --sizeout \
        --threads "${threads}"
    checkpoint "${sample}: VSEARCH clustering done"

    draft_count="$(count_fasta_records "${draft_fasta}")"
    filter_centroids_by_size "${draft_fasta}" "${retained_fasta}" "${min_cluster_size}"
    retained_count="$(count_fasta_records "${retained_fasta}")"

    if [ "${retained_count}" -eq 0 ]; then
        echo "No clusters with at least ${min_cluster_size} reads were retained for sample ${sample}."
        echo "Try lowering the minimum cluster size or clustering identity."
        exit 1
    fi

    checkpoint "${sample}: minimap2 draft-consensus mapping started"
    minimap2 -x map-ont -t "${threads}" "${retained_fasta}" "${filtered_fastq}" > "${paf_file}"
    checkpoint "${sample}: minimap2 draft-consensus mapping done"

    if [ "${polish_medaka}" = "yes" ]; then
        medaka_options=(
            -i "${filtered_fastq}"
            -d "${retained_fasta}"
            -o "${medaka_dir}"
            -t "${threads}"
        )

        if [ "${medaka_model}" != "auto" ] && [ -n "${medaka_model}" ]; then
            medaka_options+=(-m "${medaka_model}")
        fi

        checkpoint "${sample}: Medaka polishing started"
        run_medaka_polishing "${sample}" "${medaka_options[@]}"
        checkpoint "${sample}: Medaka polishing done"

        if [ ! -s "${medaka_dir}/consensus.fasta" ]; then
            echo "Medaka did not create ${medaka_dir}/consensus.fasta for sample ${sample}."
            exit 1
        fi

        rename_headers_with_sample "${medaka_dir}/consensus.fasta" "${sample_consensus}" "${sample}"
        polishing_status="medaka"
    else
        checkpoint "${sample}: Medaka polishing skipped; using retained VSEARCH draft consensuses"
        rename_headers_with_sample "${retained_fasta}" "${sample_consensus}" "${sample}"
        polishing_status="unpolished_vsearch_draft"
    fi

    consensus_count="$(count_fasta_records "${sample_consensus}")"
    cat "${sample_consensus}" >> "${consensus_fasta}"

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "${sample}" \
        "${raw_reads}" \
        "${filtered_reads}" \
        "${derep_count}" \
        "${draft_count}" \
        "${retained_count}" \
        "${consensus_count}" \
        "${polishing_status}" >> "${stats_tsv}"
done

checkpoint "OTU table read-to-consensus mapping/counting started"
write_otu_table "${otu_table}"
checkpoint "OTU table read-to-consensus mapping/counting done"

checkpoint "Compressing Nanopore consensus results archive"
tar -czf "${results_archive}" "${outdir}" "${consensus_fasta}" "${otu_table}" "${stats_tsv}"
checkpoint "Nanopore consensus results archive ready"

echo
echo "Nanopore consensus finished."
echo "Consensus FASTA: ${consensus_fasta}"
echo "OTU table: ${otu_table}"
echo "Stats table: ${stats_tsv}"
echo "Archive: ${results_archive}"
