#!/usr/bin/env bash

set -euo pipefail

# Primer-trimming-free workflow: no cutadapt primer trimming and no chimera filtering.
# Cluster reads are oriented to the first isONclust3 seed, then optionally flipped as
# a whole cluster using primer-majority votes.

platform="nanopore"
min_length=""
max_length=""
maxee_rate=""
min_cluster_size="5"
primer_file=""
primer_error_rate="0.20"
primer_trimming="yes"
racon_iterations="3"
yacrd_filtering="no"
yacrd_min_coverage=""
yacrd_min_read_coverage="0.4"
isonclust_k=""
isonclust_w=""
run_mode="all"
single_read_file=""
sample_count=""
metadata_file_arg=""

checkpoint() {
    echo
    echo "== checkpoint == $*"
}

usage() {
    echo "usage: run_isonclust3.sh -i dir -y reads_pattern [-p primers.fasta] -t threads -P nanopore|pacbio -q maxee_rate -m min_len -M max_len -R racon_iterations -s min_cluster_size [-k kmer_size -w window_size] -o representatives.fasta -O otu_table.tsv -S stats.tsv -a archive.tar.gz [-X all|prepare|cluster -F read_file -D metadata_file -K sample_count]"
    echo "legacy options -E, -T, -Y, -c and -n are accepted for backward compatibility but primer trimming and chimera filtering are not performed."
}

while getopts i:y:p:t:m:M:q:E:T:P:R:s:Y:c:n:k:w:o:O:S:a:X:F:D:K: flag
do
    case "${flag}" in
        i) dir="${OPTARG}";;
        y) reads_pattern="${OPTARG}";;
        p) primer_file="${OPTARG}";;
        t) threads="${OPTARG}";;
        m) min_length="${OPTARG}";;
        M) max_length="${OPTARG}";;
        q) maxee_rate="${OPTARG}";;
        E) primer_error_rate="${OPTARG}";;
        T) primer_trimming="${OPTARG}";;
        P) platform="${OPTARG}";;
        R) racon_iterations="${OPTARG}";;
        s) min_cluster_size="${OPTARG}";;
        Y) yacrd_filtering="${OPTARG}";;
        c) yacrd_min_coverage="${OPTARG}";;
        n) yacrd_min_read_coverage="${OPTARG}";;
        k) isonclust_k="${OPTARG}";;
        w) isonclust_w="${OPTARG}";;
        o) consensus_fasta="${OPTARG}";;
        O) otu_table="${OPTARG}";;
        S) stats_tsv="${OPTARG}";;
        a) results_archive="${OPTARG}";;
        X) run_mode="${OPTARG}";;
        F) single_read_file="${OPTARG}";;
        D) metadata_file_arg="${OPTARG}";;
        K) sample_count="${OPTARG}";;
        \?) usage; exit 1;;
    esac
done

required_vars=(dir reads_pattern threads consensus_fasta otu_table stats_tsv results_archive)
for var_name in "${required_vars[@]}"; do
    if [ -z "${!var_name:-}" ]; then
        echo "Missing required option: ${var_name}"
        usage
        exit 1
    fi
done

if ! [[ "${threads}" =~ ^[0-9]+$ ]] || [ "${threads}" -lt 1 ]; then
    echo "Threads must be a positive integer."
    exit 1
fi

run_mode="$(printf '%s\n' "${run_mode}" | tr '[:upper:]' '[:lower:]')"
case "${run_mode}" in
    all|prepare|cluster)
        ;;
    *)
        echo "Invalid run mode: ${run_mode}. Expected all, prepare, or cluster."
        exit 1
        ;;
esac

if [ "${run_mode}" = "prepare" ]; then
    if [ -z "${single_read_file}" ]; then
        echo "Prepare mode requires -F read_file."
        exit 1
    fi
    if [ -z "${metadata_file_arg}" ]; then
        echo "Prepare mode requires -D metadata_file."
        exit 1
    fi
fi

if [ "${run_mode}" = "cluster" ]; then
    if [ -z "${sample_count}" ] || ! [[ "${sample_count}" =~ ^[0-9]+$ ]] || [ "${sample_count}" -lt 1 ]; then
        echo "Cluster mode requires -K sample_count as a positive integer."
        exit 1
    fi
fi

platform="$(printf '%s\n' "${platform}" | tr '[:upper:]' '[:lower:]')"
case "${platform}" in
    nanopore|ont)
        platform="nanopore"
        isonclust_mode="ont"
        isonclust_mode_label="ont"
        minimap_preset="map-ont"
        default_maxee_rate="0.05"
        isonclust_k_label="13"
        isonclust_w_label="21"
        ;;
    pacbio|hifi|ccs)
        platform="pacbio"
        isonclust_mode="pacbio"
        isonclust_mode_label="pacbio"
        minimap_preset="map-hifi"
        default_maxee_rate="0.01"
        isonclust_k_label="15"
        isonclust_w_label="51"
        ;;
    *)
        echo "Invalid sequencing platform: ${platform}. Expected nanopore or pacbio."
        exit 1
        ;;
esac

isonclust_custom_params="no"
if [ -n "${isonclust_k}" ] || [ -n "${isonclust_w}" ]; then
    if [ -z "${isonclust_k}" ] || [ -z "${isonclust_w}" ]; then
        echo "Custom isONclust3 minimizer settings require both -k kmer_size and -w window_size."
        exit 1
    fi
    if ! [[ "${isonclust_k}" =~ ^[0-9]+$ ]] || [ "${isonclust_k}" -lt 1 ]; then
        echo "Custom isONclust3 k-mer size (-k) must be a positive integer."
        exit 1
    fi
    if [ "${isonclust_k}" -gt 32 ]; then
        echo "Custom isONclust3 k-mer size (-k) must be less than or equal to 32."
        exit 1
    fi
    if ! [[ "${isonclust_w}" =~ ^[0-9]+$ ]] || [ "${isonclust_w}" -lt 1 ]; then
        echo "Custom isONclust3 window size (-w) must be a positive integer."
        exit 1
    fi
    if [ "${isonclust_w}" -lt "${isonclust_k}" ]; then
        echo "Custom isONclust3 window size (-w) must be greater than or equal to -k."
        exit 1
    fi
    if [ $((10#${isonclust_w} % 2)) -eq 0 ]; then
        echo "Custom isONclust3 window size (-w) must be odd."
        exit 1
    fi
    isonclust_custom_params="yes"
    isonclust_k_label="${isonclust_k}"
    isonclust_w_label="${isonclust_w}"
fi

maxee_rate="${maxee_rate:-${default_maxee_rate}}"
legacy_primer_trimming_requested="${primer_trimming}"
legacy_yacrd_filtering_requested="${yacrd_filtering}"
primer_trimming="no"
yacrd_filtering="no"

if ! [[ "${racon_iterations}" =~ ^[0-9]+$ ]]; then
    echo "Racon iterations must be an integer between 1 and 4."
    exit 1
fi

if [ "${racon_iterations}" -lt 1 ] || [ "${racon_iterations}" -gt 4 ]; then
    echo "Racon iterations must be between 1 and 4."
    exit 1
fi

cd "${dir}"

reads_pattern="${reads_pattern//€/*}"

shopt -s nullglob
if [ "${run_mode}" = "prepare" ]; then
    read_files=( "${single_read_file}" )
else
    read_files=( ${reads_pattern} )
fi
shopt -u nullglob

if [ "${#read_files[@]}" -eq 0 ]; then
    echo "No FASTQ files matched: ${reads_pattern}"
    echo "Available FASTQ files in ${dir}:"
    find . -maxdepth 1 -type f \( -name "*.fastq" -o -name "*.fastq.gz" -o -name "*.fq" -o -name "*.fq.gz" \) -printf "  %f\n" | sort
    exit 1
fi

for read_file in "${read_files[@]}"; do
    if [ ! -f "${read_file}" ]; then
        echo "Input FASTQ file does not exist: ${read_file}"
        exit 1
    fi
done

vsearch_bin="${VSEARCH_BIN:-/app/lib/vsearch/bin/vsearch}"
if [ ! -x "${vsearch_bin}" ]; then
    vsearch_bin="$(command -v vsearch || true)"
fi

if [ -z "${vsearch_bin}" ] || [ ! -x "${vsearch_bin}" ]; then
    echo "VSEARCH was not found. Expected /app/lib/vsearch/bin/vsearch or vsearch in PATH."
    exit 1
fi

required_tools=(minimap2 isONclust3)
if [ "${platform}" = "nanopore" ]; then
    required_tools+=(racon)
fi

for tool in "${required_tools[@]}"; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "${tool} was not found in PATH."
        echo "Rebuild the image with the Nanopore/PacBio conda environment."
        exit 1
    fi
done

if [ -n "${primer_file}" ] && [ ! -f "${primer_file}" ]; then
    echo "Primer FASTA file was provided but does not exist: ${primer_file}"
    exit 1
fi

outdir="isonclust3_results"
if [ "${run_mode}" = "all" ]; then
    rm -rf "${outdir}" "${consensus_fasta}" "${otu_table}" "${stats_tsv}" "${results_archive}"
elif [ "${run_mode}" = "cluster" ]; then
    rm -f "${consensus_fasta}" "${otu_table}" "${stats_tsv}" "${results_archive}"
fi
mkdir -p "${outdir}"/{quality_filtered,length_filtered,oriented_reads,primer_orientation,drafts,mappings,racon,per_cluster,otu_counts,pooled,isonclust3,sample_metadata}

preliminary_representatives="${outdir}/preliminary_representatives.fasta"
: > "${preliminary_representatives}"

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

    if [ ! -s "${file}" ]; then
        printf '0\n'
        return
    fi

    if [[ "${file}" == *.gz ]]; then
        pigz -cd "${file}" | awk 'END {print int(NR / 4)}'
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

    primer_f_rc="$(reverse_complement "${primer_f}")"
    primer_r_rc="$(reverse_complement "${primer_r}")"
}

run_vsearch() {
    "${vsearch_bin}" --quiet "$@"
}

run_minimap2() {
    minimap2 -v 1 --secondary=no "$@"
}

run_fastq_filter() {
    local input="$1"
    local output="$2"
    local label="$3"
    local stage="$4"
    local -a options

    options=(
        --fastq_filter "${input}"
        --fastq_qmin 0
        --fastq_qmax 93
        --fastqout "${output}"
    )

    if [ "${stage}" = "quality" ] && [ -n "${maxee_rate}" ] && [ "${maxee_rate}" != "0" ] && [ "${maxee_rate}" != "0.0" ]; then
        options+=(--fastq_maxee_rate "${maxee_rate}")
    fi

    if [ "${stage}" = "length" ]; then
        if [ -n "${min_length}" ]; then
            options+=(--fastq_minlen "${min_length}")
        fi
        if [ -n "${max_length}" ]; then
            options+=(--fastq_maxlen "${max_length}")
        fi
    fi

    checkpoint "${label}: VSEARCH ${stage} filtering started"
    run_vsearch "${options[@]}"
    checkpoint "${label}: VSEARCH ${stage} filtering done"
}

select_isonclust3_representative_as_fasta() {
    local input_fastq="$1"
    local output_fasta="$2"
    local label="$3"
    local read_count="$4"

    awk -v label="${label}" '
        NR % 4 == 1 {
            read_id = $0
            sub(/^@/, "", read_id)
            sub(/[[:space:]].*$/, "", read_id)
            next
        }
        NR % 4 == 2 {
            print ">" label
            print toupper($0)
            print "Selected isONclust3 representative for " label ": " read_id > "/dev/stderr"
            exit
        }
    ' "${input_fastq}" > "${output_fasta}"
}

filter_fasta_by_length() {
    local input_fasta="$1"
    local output_fasta="$2"
    local label="$3"

    if [ -z "${min_length}" ] && [ -z "${max_length}" ]; then
        cp "${input_fasta}" "${output_fasta}"
        return
    fi

    awk -v min_len="${min_length:-0}" -v max_len="${max_length:-0}" '
        function flush_record(   seq_len) {
            if (header == "")
                return
            seq_len = length(seq)
            if ((min_len == 0 || seq_len >= min_len) && (max_len == 0 || seq_len <= max_len)) {
                print header
                print seq
                kept++
            } else {
                dropped++
            }
            total++
        }
        /^>/ {
            flush_record()
            header = $0
            seq = ""
            next
        }
        {
            gsub(/[[:space:]]/, "")
            seq = seq toupper($0)
        }
        END {
            flush_record()
            print "FASTA records length-filtered: " (total + 0) > "/dev/stderr"
            print "FASTA records retained by length: " (kept + 0) > "/dev/stderr"
            print "FASTA records dropped by length: " (dropped + 0) > "/dev/stderr"
        }
    ' "${input_fasta}" > "${output_fasta}" 2> "${outdir}/length_filtered/${label}.fasta_length_filter.log"

    cat "${outdir}/length_filtered/${label}.fasta_length_filter.log"

    if [ ! -s "${output_fasta}" ]; then
        echo "No representative sequences remained after length filtering for ${label}."
        echo "Minimum length: ${min_length:-none}"
        echo "Maximum length: ${max_length:-none}"
        exit 1
    fi
}

append_fastq_with_sample_prefix() {
    local input="$1"
    local output="$2"
    local sample="$3"

    awk -v sample="${sample}" '
        NR % 4 == 1 {
            sub(/^@/, "@" sample "__SLIM_SAMPLE__")
            print
            next
        }
        { print }
    ' "${input}" >> "${output}"
}

run_isonclust3_clustering() {
    local label="$1"
    local reads="$2"
    local cluster_out="${outdir}/isonclust3/${label}"
    local fastq_dir
    local -a options

    rm -rf "${cluster_out}"
    mkdir -p "${cluster_out}"

    options=(
        --fastq "${reads}"
        --mode "${isonclust_mode}"
        --outfolder "${cluster_out}"
    )

    if [ "${isonclust_custom_params}" = "yes" ]; then
        options+=(-k "${isonclust_k}" -w "${isonclust_w}")
    fi

    checkpoint "${label}: isONclust3 ${isonclust_mode_label} clustering started"
    echo "isONclust3 command: isONclust3 ${options[*]}"
    isONclust3 "${options[@]}"
    checkpoint "${label}: isONclust3 clustering done"

    fastq_dir="$(find "${cluster_out}" -type d -name fastq_files -print | head -n 1)"
    if [ -z "${fastq_dir}" ] || [ ! -d "${fastq_dir}" ]; then
        echo "isONclust3 did not create a fastq_files directory for ${label}."
        exit 1
    fi

    shopt -s nullglob
    isonclust3_cluster_fastqs=( "${fastq_dir}"/*.fastq "${fastq_dir}"/*.fq )
    shopt -u nullglob

    if [ "${#isonclust3_cluster_fastqs[@]}" -eq 0 ]; then
        echo "isONclust3 did not create cluster FASTQ files for ${label}."
        exit 1
    fi
}

select_nanopore_racon_seed() {
    local input_fastq="$1"
    local output_fasta="$2"
    local label="$3"
    local read_count="$4"
    local seed_log="${outdir}/drafts/${label}.seed_selection.log"

    {
        echo "Selecting Nanopore Racon seed for ${label}"
        echo "Cluster FASTQ: ${input_fastq}"
        echo "Cluster read count: ${read_count}"
        echo "Seed policy: use the first read emitted in the isONclust3 per-cluster FASTQ."
        echo "Rationale: quality and length filtering were already applied before pooling and clustering."
    } > "${seed_log}"

    select_isonclust3_representative_as_fasta "${input_fastq}" "${output_fasta}" "${label}" "${read_count}" 2>> "${seed_log}"

    cat "${seed_log}"

    if [ ! -s "${output_fasta}" ]; then
        echo "Could not create Nanopore Racon seed draft for ${label} from ${input_fastq}."
        exit 1
    fi
}

orient_cluster_reads_to_seed() {
    local label="$1"
    local reads="$2"
    local seed_fasta="$3"
    local output_fastq="$4"
    local orient_paf="${outdir}/oriented_reads/${label}.to_seed_orientation.paf"
    local orient_log="${outdir}/oriented_reads/${label}.orientation.log"

    checkpoint "${label}: minimap2 read-to-seed orientation mapping started"
    echo "minimap2 orientation command: minimap2 -v 1 --secondary=no -x ${minimap_preset} -t ${threads} ${seed_fasta} ${reads}"
    run_minimap2 -x "${minimap_preset}" -t "${threads}" "${seed_fasta}" "${reads}" > "${orient_paf}"
    checkpoint "${label}: minimap2 read-to-seed orientation mapping done"

    awk -v paf="${orient_paf}" '
        BEGIN {
            while ((getline line < paf) > 0) {
                split(line, f, "\t")
                read_id = f[1]
                strand = f[5]
                matches = f[10] + 0
                mapq = f[12] + 0
                if (!(read_id in best_matches) || matches > best_matches[read_id] || (matches == best_matches[read_id] && mapq > best_mapq[read_id])) {
                    best_matches[read_id] = matches
                    best_mapq[read_id] = mapq
                    best_strand[read_id] = strand
                }
            }
            close(paf)
        }
        function revcomp(seq,    idx, base, out) {
            out = ""
            for (idx = length(seq); idx >= 1; idx--) {
                base = substr(seq, idx, 1)
                if (base == "A") base = "T"
                else if (base == "a") base = "t"
                else if (base == "C") base = "G"
                else if (base == "c") base = "g"
                else if (base == "G") base = "C"
                else if (base == "g") base = "c"
                else if (base == "T") base = "A"
                else if (base == "t") base = "a"
                else if (base == "U") base = "A"
                else if (base == "u") base = "a"
                else if (base == "R") base = "Y"
                else if (base == "r") base = "y"
                else if (base == "Y") base = "R"
                else if (base == "y") base = "r"
                else if (base == "K") base = "M"
                else if (base == "k") base = "m"
                else if (base == "M") base = "K"
                else if (base == "m") base = "k"
                else if (base == "S") base = "S"
                else if (base == "s") base = "s"
                else if (base == "W") base = "W"
                else if (base == "w") base = "w"
                else if (base == "B") base = "V"
                else if (base == "b") base = "v"
                else if (base == "D") base = "H"
                else if (base == "d") base = "h"
                else if (base == "H") base = "D"
                else if (base == "h") base = "d"
                else if (base == "V") base = "B"
                else if (base == "v") base = "b"
                out = out base
            }
            return out
        }
        function reverse_string(value,    idx, out) {
            out = ""
            for (idx = length(value); idx >= 1; idx--)
                out = out substr(value, idx, 1)
            return out
        }
        NR % 4 == 1 {
            header = $0
            read_id = header
            sub(/^@/, "", read_id)
            sub(/[[:space:]].*$/, "", read_id)
            next
        }
        NR % 4 == 2 { seq = $0; next }
        NR % 4 == 3 { plus = $0; next }
        NR % 4 == 0 {
            qual = $0
            strand = best_strand[read_id]
            if (strand == "-") {
                print header ";oriented_to_seed=reverse_complement"
                print revcomp(seq)
                print plus
                print reverse_string(qual)
                reversed++
            } else {
                if (strand == "+") {
                    print header ";oriented_to_seed=forward"
                    forward++
                } else {
                    print header ";oriented_to_seed=unmapped_kept"
                    unmapped++
                }
                print seq
                print plus
                print qual
            }
            total++
        }
        END {
            print "FASTQ records oriented to seed: " (total + 0) > "/dev/stderr"
            print "Forward-strand records kept: " (forward + 0) > "/dev/stderr"
            print "Reverse-strand records reverse-complemented: " (reversed + 0) > "/dev/stderr"
            print "Unmapped records kept unchanged: " (unmapped + 0) > "/dev/stderr"
        }
    ' "${reads}" > "${output_fastq}" 2> "${orient_log}"

    cat "${orient_log}"

    if [ ! -s "${output_fastq}" ]; then
        echo "Read orientation did not create a non-empty FASTQ for ${label}."
        exit 1
    fi
}

reverse_complement_fastq_file() {
    local input_fastq="$1"
    local output_fastq="$2"
    local reason="$3"

    awk -v reason="${reason}" '
        function revcomp(seq,    idx, base, out) {
            out = ""
            for (idx = length(seq); idx >= 1; idx--) {
                base = substr(seq, idx, 1)
                if (base == "A") base = "T"; else if (base == "a") base = "t"
                else if (base == "C") base = "G"; else if (base == "c") base = "g"
                else if (base == "G") base = "C"; else if (base == "g") base = "c"
                else if (base == "T") base = "A"; else if (base == "t") base = "a"
                else if (base == "U") base = "A"; else if (base == "u") base = "a"
                else if (base == "R") base = "Y"; else if (base == "r") base = "y"
                else if (base == "Y") base = "R"; else if (base == "y") base = "r"
                else if (base == "K") base = "M"; else if (base == "k") base = "m"
                else if (base == "M") base = "K"; else if (base == "m") base = "k"
                else if (base == "S") base = "S"; else if (base == "s") base = "s"
                else if (base == "W") base = "W"; else if (base == "w") base = "w"
                else if (base == "B") base = "V"; else if (base == "b") base = "v"
                else if (base == "D") base = "H"; else if (base == "d") base = "h"
                else if (base == "H") base = "D"; else if (base == "h") base = "d"
                else if (base == "V") base = "B"; else if (base == "v") base = "b"
                out = out base
            }
            return out
        }
        function reverse_string(value,    idx, out) {
            out = ""
            for (idx = length(value); idx >= 1; idx--)
                out = out substr(value, idx, 1)
            return out
        }
        NR % 4 == 1 { header = $0; next }
        NR % 4 == 2 { seq = $0; next }
        NR % 4 == 3 { plus = $0; next }
        NR % 4 == 0 {
            print header ";cluster_oriented=" reason
            print revcomp(seq)
            print plus
            print reverse_string($0)
            total++
        }
        END { print "FASTQ records reverse-complemented by primer majority: " (total + 0) > "/dev/stderr" }
    ' "${input_fastq}" > "${output_fastq}"
}

reverse_complement_fasta_file() {
    local input_fasta="$1"
    local output_fasta="$2"
    local reason="$3"

    awk -v reason="${reason}" '
        function comp(base) {
            if (base == "A") return "T"; if (base == "a") return "t"
            if (base == "C") return "G"; if (base == "c") return "g"
            if (base == "G") return "C"; if (base == "g") return "c"
            if (base == "T") return "A"; if (base == "t") return "a"
            if (base == "U") return "A"; if (base == "u") return "a"
            if (base == "R") return "Y"; if (base == "r") return "y"
            if (base == "Y") return "R"; if (base == "y") return "r"
            if (base == "K") return "M"; if (base == "k") return "m"
            if (base == "M") return "K"; if (base == "m") return "k"
            if (base == "S") return "S"; if (base == "s") return "s"
            if (base == "W") return "W"; if (base == "w") return "w"
            if (base == "B") return "V"; if (base == "b") return "v"
            if (base == "D") return "H"; if (base == "d") return "h"
            if (base == "H") return "D"; if (base == "h") return "d"
            if (base == "V") return "B"; if (base == "v") return "b"
            return base
        }
        function revcomp(seq,   idx,out) {
            out = ""
            for (idx = length(seq); idx >= 1; idx--)
                out = out comp(substr(seq, idx, 1))
            return out
        }
        function flush_record() {
            if (header != "") {
                print header ";cluster_oriented=" reason
                print revcomp(seq)
                total++
            }
        }
        /^>/ {
            flush_record()
            header = $0
            seq = ""
            next
        }
        {
            gsub(/[[:space:]]/, "")
            seq = seq $0
        }
        END {
            flush_record()
            print "FASTA records reverse-complemented by primer majority: " (total + 0) > "/dev/stderr"
        }
    ' "${input_fasta}" > "${output_fasta}"
}

orient_cluster_by_primer_majority() {
    local label="$1"
    local input_fastq="$2"
    local input_seed_fasta="$3"
    local output_fastq="$4"
    local output_seed_fasta="$5"
    local vote_file="${outdir}/primer_orientation/${label}.primer_majority_vote.tsv"
    local vote_log="${outdir}/primer_orientation/${label}.primer_majority_orientation.log"
    local decision

    if [ -z "${primer_file}" ]; then
        cp "${input_fastq}" "${output_fastq}"
        cp "${input_seed_fasta}" "${output_seed_fasta}"
        return
    fi

    checkpoint "${label}: primer-majority cluster orientation started"
    echo "Primer-majority orientation uses already seed-oriented reads." > "${vote_log}"
    echo "Forward evidence: forward primer in first third + reverse-primer reverse-complement in last third." >> "${vote_log}"
    echo "Reverse evidence: reverse primer in first third + forward-primer reverse-complement in last third." >> "${vote_log}"
    echo "Forward primer: ${primer_f}" >> "${vote_log}"
    echo "Reverse primer: ${primer_r}" >> "${vote_log}"
    echo "Forward primer reverse-complement: ${primer_f_rc}" >> "${vote_log}"
    echo "Reverse primer reverse-complement: ${primer_r_rc}" >> "${vote_log}"

    awk \
        -v primer_f="${primer_f}" \
        -v primer_r="${primer_r}" \
        -v primer_f_rc="${primer_f_rc}" \
        -v primer_r_rc="${primer_r_rc}" \
        'BEGIN { OFS = "\t" }
        function base_matches(code, base) {
            code = toupper(code); base = toupper(base)
            if (code == "A") return base == "A"
            if (code == "C") return base == "C"
            if (code == "G") return base == "G"
            if (code == "T") return base == "T"
            if (code == "R") return base == "A" || base == "G"
            if (code == "Y") return base == "C" || base == "T"
            if (code == "S") return base == "G" || base == "C"
            if (code == "W") return base == "A" || base == "T"
            if (code == "K") return base == "G" || base == "T"
            if (code == "M") return base == "A" || base == "C"
            if (code == "B") return base == "C" || base == "G" || base == "T"
            if (code == "D") return base == "A" || base == "G" || base == "T"
            if (code == "H") return base == "A" || base == "C" || base == "T"
            if (code == "V") return base == "A" || base == "C" || base == "G"
            if (code == "N") return base ~ /^[ACGTN]$/
            return base == code
        }
        function has_iupac_match(seq, primer,   idx,jdx,ok) {
            seq = toupper(seq); primer = toupper(primer)
            if (length(primer) == 0 || length(seq) < length(primer)) return 0
            for (idx = 1; idx <= length(seq) - length(primer) + 1; idx++) {
                ok = 1
                for (jdx = 1; jdx <= length(primer); jdx++) {
                    if (!base_matches(substr(primer, jdx, 1), substr(seq, idx + jdx - 1, 1))) { ok = 0; break }
                }
                if (ok) return 1
            }
            return 0
        }
        NR % 4 == 2 {
            seq = toupper($0)
            one_third = int(length(seq) / 3)
            if (one_third < 1) next
            first = substr(seq, 1, one_third)
            last = substr(seq, length(seq) - one_third + 1)
            f_first += has_iupac_match(first, primer_f)
            rr_last += has_iupac_match(last, primer_r_rc)
            r_first += has_iupac_match(first, primer_r)
            fr_last += has_iupac_match(last, primer_f_rc)
            total++
        }
        END {
            forward = f_first + rr_last
            reverse = r_first + fr_last
            decision = (reverse > forward) ? "reverse_complement" : "keep"
            print "metric", "count"
            print "reads_scored", total + 0
            print "forward_primer_first_third", f_first + 0
            print "reverse_primer_rc_last_third", rr_last + 0
            print "reverse_primer_first_third", r_first + 0
            print "forward_primer_rc_last_third", fr_last + 0
            print "forward_evidence", forward + 0
            print "reverse_evidence", reverse + 0
            print "decision", decision
        }' "${input_fastq}" > "${vote_file}"

    cat "${vote_file}" >> "${vote_log}"
    decision="$(awk -F'\t' '$1 == "decision" { print $2 }' "${vote_file}")"

    if [ -z "${decision}" ]; then
        echo "Primer-majority orientation did not produce a decision for ${label}."
        cat "${vote_log}" || true
        exit 1
    fi

    if [ "${decision}" = "reverse_complement" ]; then
        echo "Primer-majority decision for ${label}: reverse-complement whole cluster FASTQ and seed FASTA." | tee -a "${vote_log}"
        reverse_complement_fastq_file "${input_fastq}" "${output_fastq}" "primer_majority_reverse_complement" >> "${vote_log}" 2>&1
        reverse_complement_fasta_file "${input_seed_fasta}" "${output_seed_fasta}" "primer_majority_reverse_complement" >> "${vote_log}" 2>&1
    else
        echo "Primer-majority decision for ${label}: keep cluster orientation." | tee -a "${vote_log}"
        cp "${input_fastq}" "${output_fastq}"
        cp "${input_seed_fasta}" "${output_seed_fasta}"
    fi

    cat "${vote_log}"
    checkpoint "${label}: primer-majority cluster orientation done"
}

write_cluster_count_header() {
    local sample

    printf "candidate_otu\tsize" > "${cluster_counts_table}"
    for sample in "${sample_names[@]}"; do
        printf "\t%s" "${sample}" >> "${cluster_counts_table}"
    done
    printf "\n" >> "${cluster_counts_table}"
}

record_cluster_sample_counts() {
    local label="$1"
    local cluster_fastq="$2"
    local counts_file="${outdir}/otu_counts/${label}.header_sample_counts.tsv"
    local sample
    local count
    local total
    local unknown_count
    local idx

    awk '
        NR % 4 == 1 {
            sample = $0
            sub(/^@/, "", sample)
            if (sample !~ /__SLIM_SAMPLE__/) {
                counts["__UNKNOWN__"] += 1
            } else {
                sub(/__SLIM_SAMPLE__.*/, "", sample)
                counts[sample] += 1
            }
            total += 1
        }
        END {
            print "__TOTAL__\t" (total + 0)
            for (sample in counts)
                print sample "\t" counts[sample]
        }
    ' "${cluster_fastq}" > "${counts_file}"

    total="$(awk -F'\t' '$1 == "__TOTAL__" { print $2 + 0 }' "${counts_file}")"
    unknown_count="$(awk -F'\t' '$1 == "__UNKNOWN__" { print $2 + 0 }' "${counts_file}")"

    if [ "${total}" -eq 0 ]; then
        echo "Cannot count sample abundances for ${label}: cluster FASTQ has no reads."
        exit 1
    fi

    if [ "${unknown_count:-0}" -gt 0 ]; then
        echo "Cannot count sample abundances for ${label}: ${unknown_count} reads lack the __SLIM_SAMPLE__ header prefix."
        echo "Cluster FASTQ: ${cluster_fastq}"
        exit 1
    fi

    printf "%s\t%s" "${label}" "${total}" >> "${cluster_counts_table}"
    for idx in "${!sample_names[@]}"; do
        sample="${sample_names[$idx]}"
        count="$(awk -F'\t' -v sample="${sample}" '$1 == sample { print $2 + 0; found = 1 } END { if (!found) print 0 }' "${counts_file}")"
        sample_final_reads[$idx]=$((sample_final_reads[$idx] + count))
        printf "\t%s" "${count}" >> "${cluster_counts_table}"
    done
    printf "\n" >> "${cluster_counts_table}"
}

run_racon_iterations() {
    local label="$1"
    local reads="$2"
    local input_fasta="$3"
    local output_fasta="$4"
    local current_fasta="${input_fasta}"
    local next_fasta
    local paf_file
    local log_file
    local status

    for iteration in $(seq 1 "${racon_iterations}"); do
        paf_file="${outdir}/mappings/${label}.racon_iter${iteration}.paf"
        log_file="${outdir}/racon/${label}.iter${iteration}.log"
        next_fasta="${outdir}/racon/${label}.iter${iteration}.fasta"

        checkpoint "${label}: minimap2 mapping for Racon iteration ${iteration} started"
        echo "minimap2 command: minimap2 -v 1 --secondary=no -x ${minimap_preset} -t ${threads} ${current_fasta} ${reads}"
        run_minimap2 -x "${minimap_preset}" -t "${threads}" "${current_fasta}" "${reads}" > "${paf_file}"
        checkpoint "${label}: minimap2 mapping for Racon iteration ${iteration} done"

        echo "Racon command: racon -t ${threads} ${reads} ${paf_file} ${current_fasta}"

        set +e
        racon -t "${threads}" "${reads}" "${paf_file}" "${current_fasta}" > "${next_fasta}" 2> "${log_file}"
        status=$?
        set -e

        if [ -s "${log_file}" ]; then
            cat "${log_file}"
        fi

        if [ "${status}" -ne 0 ]; then
            echo "Racon failed for ${label} iteration ${iteration} with exit code ${status}."
            if [ "${status}" -eq 132 ]; then
                echo "Exit code 132 is an illegal CPU instruction from the Racon executable."
                echo "Rebuild the SLIM image with the source-built Racon Dockerfile layer, then rerun this module."
            fi
            exit "${status}"
        fi

        if [ ! -s "${next_fasta}" ]; then
            echo "Racon finished without creating a non-empty output for ${label} iteration ${iteration}."
            exit 1
        fi

        current_fasta="${next_fasta}"
    done

    cp "${current_fasta}" "${output_fasta}"
}

process_cluster_set() {
    local label="$1"
    local reads="$2"
    local output_fasta="$3"
    local cluster_fastq
    local cluster_read_count
    local cluster_index=0
    local draft_count_local=0
    local retained_count_local=0
    local cluster_label
    local centroid_fasta
    local polished_fasta
    local oriented_cluster_fastq
    local primer_oriented_cluster_fastq
    local oriented_centroid_fasta

    : > "${output_fasta}"
    run_isonclust3_clustering "${label}" "${reads}"

    for cluster_fastq in "${isonclust3_cluster_fastqs[@]}"; do
        cluster_index=$((cluster_index + 1))
        draft_count_local=$((draft_count_local + 1))
        cluster_read_count="$(count_fastq_reads "${cluster_fastq}")"

        if [ "${cluster_read_count}" -lt "${min_cluster_size}" ]; then
            continue
        fi

        cluster_label="${label}_cluster_${cluster_index}"
        polished_fasta="${outdir}/per_cluster/${cluster_label}.consensus.fasta"
        retained_count_local=$((retained_count_local + 1))

        if [ "${platform}" = "nanopore" ]; then
            centroid_fasta="${outdir}/drafts/${cluster_label}.racon_seed.fasta"
            checkpoint "${cluster_label}: Nanopore Racon seed selection started"
            select_nanopore_racon_seed "${cluster_fastq}" "${centroid_fasta}" "${cluster_label}" "${cluster_read_count}"
            checkpoint "${cluster_label}: Nanopore Racon seed selection done"

            oriented_cluster_fastq="${outdir}/oriented_reads/${cluster_label}.seed_oriented.fastq"
            checkpoint "${cluster_label}: cluster read orientation to seed started"
            orient_cluster_reads_to_seed "${cluster_label}" "${cluster_fastq}" "${centroid_fasta}" "${oriented_cluster_fastq}"
            checkpoint "${cluster_label}: cluster read orientation to seed done"

            primer_oriented_cluster_fastq="${outdir}/primer_orientation/${cluster_label}.primer_oriented.fastq"
            oriented_centroid_fasta="${outdir}/primer_orientation/${cluster_label}.primer_oriented_seed.fasta"
            orient_cluster_by_primer_majority "${cluster_label}" "${oriented_cluster_fastq}" "${centroid_fasta}" "${primer_oriented_cluster_fastq}" "${oriented_centroid_fasta}"

            record_cluster_sample_counts "${cluster_label}" "${primer_oriented_cluster_fastq}"

            if [ "${cluster_read_count}" -lt 2 ]; then
                checkpoint "${cluster_label}: Racon polishing skipped for singleton cluster"
                echo "Cluster ${cluster_label} contains one read; keeping the oriented isONclust3 representative seed as the OTU draft."
                cp "${oriented_centroid_fasta}" "${polished_fasta}"
            else
                checkpoint "${cluster_label}: Racon polishing loop started"
                run_racon_iterations "${cluster_label}" "${primer_oriented_cluster_fastq}" "${oriented_centroid_fasta}" "${polished_fasta}"
                checkpoint "${cluster_label}: Racon polishing loop done"
            fi
            cat "${polished_fasta}" >> "${output_fasta}"
        else
            centroid_fasta="${outdir}/drafts/${cluster_label}.isonclust3_representative.fasta"
            checkpoint "${cluster_label}: PacBio isONclust3 representative selection started"
            select_isonclust3_representative_as_fasta "${cluster_fastq}" "${centroid_fasta}" "${cluster_label}" "${cluster_read_count}"
            checkpoint "${cluster_label}: PacBio isONclust3 representative selection done"

            oriented_cluster_fastq="${outdir}/oriented_reads/${cluster_label}.seed_oriented.fastq"
            checkpoint "${cluster_label}: cluster read orientation to seed started"
            echo "7. Cluster reads are oriented to the seed with minimap2 PAF strand calls."
            orient_cluster_reads_to_seed "${cluster_label}" "${cluster_fastq}" "${centroid_fasta}" "${oriented_cluster_fastq}"
            checkpoint "${cluster_label}: cluster read orientation to seed done"

            primer_oriented_cluster_fastq="${outdir}/primer_orientation/${cluster_label}.primer_oriented.fastq"
            oriented_centroid_fasta="${outdir}/primer_orientation/${cluster_label}.primer_oriented_representative.fasta"
            orient_cluster_by_primer_majority "${cluster_label}" "${oriented_cluster_fastq}" "${centroid_fasta}" "${primer_oriented_cluster_fastq}" "${oriented_centroid_fasta}"

            record_cluster_sample_counts "${cluster_label}" "${primer_oriented_cluster_fastq}"

            cp "${oriented_centroid_fasta}" "${polished_fasta}"
            cat "${polished_fasta}" >> "${output_fasta}"
        fi
    done

    if [ "${retained_count_local}" -eq 0 ]; then
        echo "No clusters with at least ${min_cluster_size} reads were retained for ${label}."
        echo "Try lowering the minimum reads per cluster."
        exit 1
    fi

    cluster_draft_count="${draft_count_local}"
    cluster_retained_count="${retained_count_local}"
}

write_representatives_and_otu_table_from_cluster_counts() {
    local input_fasta="$1"
    local output_fasta="$2"
    local table="$3"
    local assigned_map="${outdir}/otu_counts/assigned_representative_id_map.tsv"
    local zero_ids="${outdir}/otu_counts/zero_count_candidate_otus.txt"
    local sample
    local candidate
    local total
    local new_index=0
    local new_id
    local row_id
    local row_counts_text
    local -a row_counts

    if [ ! -s "${input_fasta}" ]; then
        echo "No representative sequences were available for final FASTA creation."
        exit 1
    fi

    if [ ! -s "${cluster_counts_table}" ]; then
        echo "Cluster count table is missing or empty: ${cluster_counts_table}"
        exit 1
    fi

    : > "${assigned_map}"
    : > "${zero_ids}"

    {
        printf "OTU"
        for sample in "${sample_names[@]}"; do
            printf "\t%s" "${sample}"
        done
        printf "\n"

        while IFS=$'\t' read -r candidate total row_counts_text; do
            if [ "${candidate}" = "candidate_otu" ]; then
                continue
            fi

            if [ -z "${candidate}" ]; then
                continue
            fi

            if [ "${total}" -eq 0 ]; then
                printf "%s\n" "${candidate}" >> "${zero_ids}"
                continue
            fi

            IFS=$'\t' read -r -a row_counts <<< "${row_counts_text}"
            if [ "${#row_counts[@]}" -ne "${#sample_names[@]}" ]; then
                echo "Cluster count row for ${candidate} does not match the sample count."
                echo "Expected ${#sample_names[@]} sample columns but found ${#row_counts[@]}."
                exit 1
            fi

            new_index=$((new_index + 1))
            new_id="OTU${new_index}"
            row_id="${new_id}"
            printf "%s\t%s\t%s\n" "${candidate}" "${row_id}" "${total}" >> "${assigned_map}"

            printf "%s" "${row_id}"
            for count in "${row_counts[@]}"; do
                printf "\t%s" "${count}"
            done
            printf "\n"
        done < "${cluster_counts_table}"
    } > "${table}"

    if [ ! -s "${assigned_map}" ]; then
        echo "No retained clusters had read counts for final OTU creation."
        exit 1
    fi

    awk -v map_file="${assigned_map}" '
        BEGIN {
            while ((getline line < map_file) > 0) {
                split(line, fields, "\t")
                if (fields[1] != "" && fields[2] != "")
                    id_map[fields[1]] = fields[2]
            }
        }
        /^>/ {
            old = $0
            sub(/^>/, "", old)
            label = old
            sub(/[[:space:];].*$/, "", label)
            keep = label in id_map
            if (keep)
                print ">" id_map[label]
            next
        }
        keep { print }
    ' "${input_fasta}" > "${output_fasta}"

    if [ ! -s "${output_fasta}" ]; then
        echo "Final representative FASTA is empty after applying cluster-count IDs."
        exit 1
    fi

    if [ -s "${zero_ids}" ]; then
        echo "Dropped candidate OTUs with zero cluster read counts:"
        sed 's/^/  /' "${zero_ids}"
    fi
}

write_stats_table() {
    local final_otus="$1"

    printf "sample\tplatform\traw_reads\tquality_filtered_reads\tlength_filtered_reads\tpost_length_filter_reads\tfinal_assigned_reads\tclustering_method\tminimap2_preset\tisONclust3_mode\tisONclust3_k\tisONclust3_w\tdraft_clusters\tretained_clusters\tfinal_otus\tracon_iterations\n" > "${stats_tsv}"

    for idx in "${!sample_names[@]}"; do
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "${sample_names[$idx]}" \
            "${platform}" \
            "${sample_raw_reads[$idx]}" \
            "${sample_quality_reads[$idx]}" \
            "${sample_length_reads[$idx]}" \
            "${sample_post_length_reads[$idx]}" \
            "${sample_final_reads[$idx]:-0}" \
            "isONclust3" \
            "${minimap_preset}" \
            "${isonclust_mode_label}" \
            "${isonclust_k_label}" \
            "${isonclust_w_label}" \
            "${cluster_draft_count}" \
            "${cluster_retained_count}" \
            "${final_otus}" \
            "$([ "${platform}" = "nanopore" ] && printf '%s' "${racon_iterations}" || printf '0')" >> "${stats_tsv}"
    done
}

validate_plain_sequential_otu_ids() {
    local ids_file="$1"
    local label="$2"
    local invalid_ids="$3"

    if awk -v label="${label}" '
        {
            expected = "OTU" NR
            if ($0 != expected) {
                printf "%s\tline_%d\texpected_%s\tfound_%s\n", label, NR, expected, $0
                bad = 1
            }
        }
        END { exit bad ? 1 : 0 }
    ' "${ids_file}" > "${invalid_ids}"; then
        rm -f "${invalid_ids}"
    else
        echo "${label} IDs must be exactly OTU1 through OTUN, with no annotations or extra text."
        sed 's/^/  /' "${invalid_ids}"
        exit 1
    fi
}

validate_representatives_and_otu_table() {
    local fasta="$1"
    local table="$2"
    local fasta_ids="${outdir}/otu_counts/final_fasta_ids.txt"
    local table_ids="${outdir}/otu_counts/final_table_ids.txt"

    grep '^>' "${fasta}" | sed 's/^>//' > "${fasta_ids}"
    awk -F'\t' 'NR > 1 { print $1 }' "${table}" > "${table_ids}"

    validate_plain_sequential_otu_ids "${fasta_ids}" "Representative FASTA" "${outdir}/otu_counts/invalid_fasta_ids.txt"
    validate_plain_sequential_otu_ids "${table_ids}" "OTU table" "${outdir}/otu_counts/invalid_table_ids.txt"

    if ! cmp -s "${fasta_ids}" "${table_ids}"; then
        echo "Representative FASTA IDs and OTU table IDs do not match."
        echo "This should never happen; keeping ID lists in ${outdir}/otu_counts for debugging."
        diff -u "${fasta_ids}" "${table_ids}" || true
        exit 1
    fi

    if awk 'NR > 1 { total = 0; for (idx = 2; idx <= NF; idx++) total += $idx; if (total == 0) { print $1; bad = 1 } } END { exit bad ? 1 : 0 }' "${table}" > "${outdir}/otu_counts/zero_rows_after_filter.txt"; then
        rm -f "${outdir}/otu_counts/zero_rows_after_filter.txt"
    else
        echo "OTU table still contains rows with zero assigned reads."
        sed 's/^/  /' "${outdir}/otu_counts/zero_rows_after_filter.txt"
        exit 1
    fi
}

register_sample_for_otu_table() {
    local sample="$1"
    local filtered_fastq="$2"
    local raw_reads="$3"
    local quality_reads="$4"
    local length_reads="$5"
    local post_length_reads="$6"

    if [ -n "${sample_metadata_file:-}" ]; then
        printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
            "${sample}" \
            "${filtered_fastq}" \
            "${raw_reads}" \
            "${quality_reads}" \
            "${length_reads}" \
            "${post_length_reads}" > "${sample_metadata_file}"
        return
    fi

    sample_names+=("${sample}")
    sample_filtered_fastqs+=("${filtered_fastq}")
    sample_raw_reads+=("${raw_reads}")
    sample_quality_reads+=("${quality_reads}")
    sample_length_reads+=("${length_reads}")
    sample_post_length_reads+=("${post_length_reads}")
    sample_final_reads+=("0")
}

load_sample_metadata() {
    local metadata="$1"
    local sample
    local filtered_fastq
    local raw_reads
    local quality_reads
    local length_reads
    local post_length_reads

    if [ ! -s "${metadata}" ]; then
        echo "Sample preparation metadata missing or empty: ${metadata}"
        exit 1
    fi

    IFS=$'\t' read -r sample filtered_fastq raw_reads quality_reads length_reads post_length_reads < "${metadata}"
    register_sample_for_otu_table "${sample}" "${filtered_fastq}" "${raw_reads}" "${quality_reads}" "${length_reads}" "${post_length_reads}"
}

prepare_sample_reads() {
    local read_file="$1"
    local sample
    local raw_reads
    local quality_fastq
    local quality_reads
    local length_fastq
    local length_reads
    local selected_fastq
    local selected_reads

    sample="$(sample_name_from_file "${read_file}")"
    quality_fastq="${outdir}/quality_filtered/${sample}.quality.fastq"
    length_fastq="${outdir}/length_filtered/${sample}.length.fastq"

    echo
    echo "Processing sample: ${sample}"

    raw_reads="$(count_fastq_reads "${read_file}")"

    run_fastq_filter "${read_file}" "${quality_fastq}" "${sample}" "quality"
    quality_reads="$(count_fastq_reads "${quality_fastq}")"
    if [ "${quality_reads}" -eq 0 ]; then
        echo "No reads survived quality filtering for sample ${sample}; retaining sample with zero OTU counts."
        : > "${quality_fastq}"
        register_sample_for_otu_table "${sample}" "${quality_fastq}" "${raw_reads}" "0" "0" "0"
        return
    fi

    run_fastq_filter "${quality_fastq}" "${length_fastq}" "${sample}" "length"
    length_reads="$(count_fastq_reads "${length_fastq}")"
    if [ "${length_reads}" -eq 0 ]; then
        echo "No reads survived length filtering for sample ${sample}; retaining sample with zero OTU counts."
        : > "${length_fastq}"
        register_sample_for_otu_table "${sample}" "${length_fastq}" "${raw_reads}" "${quality_reads}" "0" "0"
        return
    fi

    selected_fastq="${length_fastq}"
    selected_reads="${length_reads}"

    register_sample_for_otu_table "${sample}" "${selected_fastq}" "${raw_reads}" "${quality_reads}" "${length_reads}" "${selected_reads}"
}

prepare_sample_reads_worker() {
    local read_file="$1"
    local metadata_file="$2"
    local worker_threads="$3"

    threads="${worker_threads}"
    sample_metadata_file="${metadata_file}"
    prepare_sample_reads "${read_file}"
}

wait_for_sample_batch() {
    local status
    local failed=0
    local pid

    set +e
    for pid in "${sample_preparation_pids[@]}"; do
        wait "${pid}"
        status=$?
        if [ "${status}" -ne 0 ]; then
            failed=1
        fi
    done
    set -e

    sample_preparation_pids=()
    return "${failed}"
}

run_sample_preparation_jobs() {
    local sample_count="${#read_files[@]}"
    local max_parallel_jobs="${threads}"
    local worker_threads
    local idx
    local read_file
    local metadata_file
    local log_file
    local failed=0

    if [ "${max_parallel_jobs}" -gt "${sample_count}" ]; then
        max_parallel_jobs="${sample_count}"
    fi
    if [ "${max_parallel_jobs}" -gt 8 ]; then
        max_parallel_jobs=8
    fi
    if [ "${max_parallel_jobs}" -lt 1 ]; then
        max_parallel_jobs=1
    fi

    worker_threads=1

    echo "Sample preparation parallel jobs: ${max_parallel_jobs}"
    echo "VSEARCH filtering jobs are batched by sample, capped at 8 concurrent jobs or available cores."
    echo "Threads per sample preparation job: ${worker_threads}"
    echo "Sample preparation includes per-sample quality filtering and length filtering. No primer trimming or chimera filtering is performed."

    sample_preparation_pids=()
    sample_metadata_files=()
    sample_log_files=()

    for idx in "${!read_files[@]}"; do
        read_file="${read_files[$idx]}"
        metadata_file="${outdir}/sample_metadata/sample_${idx}.metadata.tsv"
        log_file="${outdir}/sample_metadata/sample_${idx}.log"
        sample_metadata_files+=("${metadata_file}")
        sample_log_files+=("${log_file}")

        (
            prepare_sample_reads_worker "${read_file}" "${metadata_file}" "${worker_threads}"
        ) > "${log_file}" 2>&1 &
        sample_preparation_pids+=("$!")

        if [ "${#sample_preparation_pids[@]}" -ge "${max_parallel_jobs}" ]; then
            if ! wait_for_sample_batch; then
                failed=1
            fi
        fi
    done

    if [ "${#sample_preparation_pids[@]}" -gt 0 ]; then
        if ! wait_for_sample_batch; then
            failed=1
        fi
    fi

    for log_file in "${sample_log_files[@]}"; do
        if [ -s "${log_file}" ]; then
            cat "${log_file}"
        fi
    done

    if [ "${failed}" -ne 0 ]; then
        echo "At least one sample failed during parallel preparation."
        echo "Per-sample logs are kept in ${outdir}/sample_metadata."
        exit 1
    fi
}

checkpoint "isONclust3 input validation done"
echo "Input FASTQ files:"
printf '  %s\n' "${read_files[@]}"
echo "Sequencing platform: ${platform}"
echo "VSEARCH: ${vsearch_bin}"
echo "minimap2: $(command -v minimap2)"
echo "minimap2 preset: ${minimap_preset}"
echo "isONclust3: $(command -v isONclust3)"
echo "isONclust3 mode: ${isonclust_mode_label}"
echo "isONclust3 k: ${isonclust_k_label}"
echo "isONclust3 w: ${isonclust_w_label}"
if [ "${isonclust_custom_params}" = "yes" ]; then
    echo "isONclust3 k/w overrides: enabled; using --mode ${isonclust_mode} with -k ${isonclust_k} -w ${isonclust_w}"
else
    echo "isONclust3 k/w overrides: disabled; using --mode ${isonclust_mode}"
fi
echo "Quality filter max expected error rate: ${maxee_rate}"
echo "Minimum read length: ${min_length:-none}"
echo "Maximum read length: ${max_length:-none}"
echo "Minimum reads per cluster: ${min_cluster_size}"
echo "Primer trimming: disabled/removed"
echo "Chimera filtering: disabled/removed"
if [ "${legacy_primer_trimming_requested}" != "yes" ] || [ "${legacy_yacrd_filtering_requested}" != "no" ] || [ -n "${yacrd_min_coverage}" ] || [ -n "${yacrd_min_read_coverage}" ]; then
    echo "Legacy primer-trimming/YACRD options were provided and ignored by this workflow."
fi
if [ "${platform}" = "nanopore" ]; then
    echo "Nanopore initial draft: first isONclust3 cluster read used as the Racon seed after quality/length filtering"
    echo "Racon: $(command -v racon)"
    echo "Racon iterations: ${racon_iterations}"
else
    echo "PacBio representative policy: first isONclust3 cluster read is oriented by the cluster-orientation steps and used as the OTU representative; no SPOA consensus is run"
fi
if [ -n "${primer_file}" ]; then
    load_primers "${primer_file}"
    echo "Primers FASTA for cluster-majority orientation: ${primer_file}"
    echo "Primer FASTA convention: first sequence is forward primer; second sequence is reverse primer"
    echo "Forward primer loaded from first FASTA record: ${primer_f}"
    echo "Reverse primer loaded from second FASTA record: ${primer_r}"
    echo "Primer use: exact IUPAC-aware cluster-majority orientation voting only"
    echo "Primer max error rate legacy value ignored: ${primer_error_rate}"
else
    echo "Primers FASTA: none; primer-majority orientation disabled"
fi

if [ "${run_mode}" = "prepare" ]; then
    checkpoint "isONclust3 sample preparation started"
    prepare_sample_reads_worker "${single_read_file}" "${metadata_file_arg}" "${threads}"
    checkpoint "isONclust3 sample preparation done"
    exit 0
fi

sample_names=()
sample_filtered_fastqs=()
sample_raw_reads=()
sample_quality_reads=()
sample_length_reads=()
sample_post_length_reads=()
sample_final_reads=()

pooled_fastq="${outdir}/pooled/pooled.${platform}.fastq"
: > "${pooled_fastq}"

sample_metadata_files=()
if [ "${run_mode}" = "all" ]; then
    run_sample_preparation_jobs
else
    for idx in $(seq 0 $((sample_count - 1))); do
        sample_metadata_files+=("${outdir}/sample_metadata/sample_${idx}.metadata.tsv")
    done
fi

for idx in "${!sample_metadata_files[@]}"; do
    load_sample_metadata "${sample_metadata_files[$idx]}"
    append_fastq_with_sample_prefix "${sample_filtered_fastqs[$idx]}" "${pooled_fastq}" "${sample_names[$idx]}"
done

if [ "${#sample_names[@]}" -eq 0 ]; then
    echo "No samples were prepared for clustering."
    exit 1
fi

if [ "$(count_fastq_reads "${pooled_fastq}")" -eq 0 ]; then
    echo "No reads from any sample survived filtering; cannot build OTU representatives."
    exit 1
fi

cluster_counts_table="${outdir}/otu_counts/cluster_sample_counts.tsv"
write_cluster_count_header

process_cluster_set "pooled" "${pooled_fastq}" "${preliminary_representatives}"

checkpoint "Representative FASTA and OTU table writing from cluster counts started"
write_representatives_and_otu_table_from_cluster_counts "${preliminary_representatives}" "${consensus_fasta}" "${otu_table}"
checkpoint "Representative FASTA and OTU table writing from cluster counts done"

final_otu_count="$(count_fasta_records "${consensus_fasta}")"

checkpoint "Run summary statistics writing started"
write_stats_table "${final_otu_count}"
checkpoint "Run summary statistics writing done"

checkpoint "Representative FASTA and OTU table ID validation started"
validate_representatives_and_otu_table "${consensus_fasta}" "${otu_table}"
checkpoint "Representative FASTA and OTU table ID validation done"

checkpoint "Compressing isONclust3 results archive"
tar --use-compress-program=pigz -cf "${results_archive}" "${outdir}" "${consensus_fasta}" "${otu_table}" "${stats_tsv}"
checkpoint "isONclust3 results archive ready"

echo
echo "isONclust3 finished."
echo "OTU table: ${otu_table}"
echo "OTU representative sequences: ${consensus_fasta}"
echo "Run summary statistics: ${stats_tsv}"
echo "Archive: ${results_archive}"
