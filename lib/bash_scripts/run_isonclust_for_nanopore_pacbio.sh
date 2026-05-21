#!/usr/bin/env bash

set -euo pipefail

platform="nanopore"
min_length=""
max_length=""
maxee_rate=""
min_cluster_size="5"
primer_file=""
primer_error_rate="0.20"
primer_trimming="yes"
racon_iterations="3"
spoa_match=""
spoa_mismatch=""
spoa_gap_open=""
spoa_gap_extend=""

checkpoint() {
    echo
    echo "== checkpoint == $*"
}

usage() {
    echo "usage: run_isonclust_for_nanopore_pacbio.sh -i dir -y reads_pattern [-p primers.fasta] -t threads -P nanopore|pacbio -q maxee_rate -m min_len -M max_len -E primer_error_rate -T yes|no -R racon_iterations -s min_cluster_size -A spoa_match -N spoa_mismatch -B spoa_gap_open -C spoa_gap_extend -o representatives.fasta -O otu_table.tsv -S stats.tsv -a archive.tar.gz"
}

while getopts i:y:p:t:m:M:q:E:T:P:R:s:A:N:B:C:o:O:S:a: flag
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
        A) spoa_match="${OPTARG}";;
        N) spoa_mismatch="${OPTARG}";;
        B) spoa_gap_open="${OPTARG}";;
        C) spoa_gap_extend="${OPTARG}";;
        o) consensus_fasta="${OPTARG}";;
        O) otu_table="${OPTARG}";;
        S) stats_tsv="${OPTARG}";;
        a) results_archive="${OPTARG}";;
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

platform="$(printf '%s\n' "${platform}" | tr '[:upper:]' '[:lower:]')"
case "${platform}" in
    nanopore|ont)
        platform="nanopore"
        isonclust_mode="ont"
        minimap_preset="map-ont"
        default_maxee_rate="0.05"
        isonclust_k_label="13"
        isonclust_w_label="21"
        default_spoa_match="5"
        default_spoa_mismatch="-4"
        default_spoa_gap_open="-5"
        default_spoa_gap_extend="-1"
        ;;
    pacbio|hifi|ccs)
        platform="pacbio"
        isonclust_mode="pacbio"
        minimap_preset="map-hifi"
        default_maxee_rate="0.01"
        isonclust_k_label="15"
        isonclust_w_label="51"
        default_spoa_match="1"
        default_spoa_mismatch="-8"
        default_spoa_gap_open="-6"
        default_spoa_gap_extend="-2"
        ;;
    *)
        echo "Invalid sequencing platform: ${platform}. Expected nanopore or pacbio."
        exit 1
        ;;
esac

maxee_rate="${maxee_rate:-${default_maxee_rate}}"
spoa_match="${spoa_match:-${default_spoa_match}}"
spoa_mismatch="${spoa_mismatch:-${default_spoa_mismatch}}"
spoa_gap_open="${spoa_gap_open:-${default_spoa_gap_open}}"
spoa_gap_extend="${spoa_gap_extend:-${default_spoa_gap_extend}}"

primer_trimming="$(printf '%s\n' "${primer_trimming}" | tr '[:upper:]' '[:lower:]')"
case "${primer_trimming}" in
    yes|y|true|1|on)
        primer_trimming="yes"
        ;;
    no|n|false|0|off)
        primer_trimming="no"
        ;;
    *)
        echo "Invalid primer trimming option: ${primer_trimming}. Expected yes or no."
        exit 1
        ;;
esac

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
read_files=( ${reads_pattern} )
shopt -u nullglob

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

required_tools=(minimap2 isONclust3)
if [ "${platform}" = "nanopore" ]; then
    required_tools+=(racon)
else
    spoa_bin="${SPOA_BIN:-$(command -v spoa || true)}"
    if [ -z "${spoa_bin}" ] || [ ! -x "${spoa_bin}" ]; then
        spoa_bin="/app/lib/ASHURE/spoa/build/bin/spoa"
    fi

    if [ -z "${spoa_bin}" ] || [ ! -x "${spoa_bin}" ]; then
        echo "SPOA was not found. Expected spoa in PATH or /app/lib/ASHURE/spoa/build/bin/spoa."
        echo "Run get_dependencies_slim_v1.0.0.sh and rebuild the image so ASHURE/SPOA is available."
        exit 1
    fi
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

cutadapt_bin="$(command -v cutadapt || true)"
if [ -n "${primer_file}" ] && [ "${primer_trimming}" = "yes" ] && [ -z "${cutadapt_bin}" ]; then
    echo "Primer trimming is enabled and a primer FASTA was provided, but cutadapt was not found."
    echo "Rebuild the image with cutadapt in the Nanopore/PacBio environment, or disable primer trimming."
    exit 1
fi

outdir="isonclust_nanopore_pacbio"
rm -rf "${outdir}" "${consensus_fasta}" "${otu_table}" "${stats_tsv}" "${results_archive}"
mkdir -p "${outdir}"/{primer_oriented,primer_trimmed,quality_filtered,length_filtered,chimera_filtered,drafts,spoa,mappings,racon,per_cluster,otu_counts,pooled,isonclust3}

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

    primer_f_rc="$(reverse_complement "${primer_f}")"
    primer_r_rc="$(reverse_complement "${primer_r}")"
}

cutadapt_supports_revcomp() {
    [ -n "${cutadapt_bin}" ] || return 1
    "${cutadapt_bin}" --help 2>/dev/null | grep -q -- '--revcomp'
}

cutadapt_supports_action_none() {
    [ -n "${cutadapt_bin}" ] || return 1
    "${cutadapt_bin}" --help 2>/dev/null | grep -q -- '--action'
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
        --threads "${threads}"
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

trim_primers() {
    local input="$1"
    local output="$2"
    local label="$3"
    local allow_revcomp="${4:-yes}"
    local log_file="${outdir}/primer_trimmed/${label}.cutadapt.log"
    local status
    local -a cutadapt_options

    cutadapt_options=(
        -e "${primer_error_rate}"
        --cores "${threads}"
        -g "${primer_f}"
        -a "${primer_r_rc}"
        -o "${output}"
    )

    echo "Trimming primers with cutadapt: ${label}"
    echo "Forward primer: ${primer_f}"
    echo "Reverse primer: ${primer_r}"
    echo "Reverse primer reverse-complement used for trimming: ${primer_r_rc}"
    echo "Primer max error rate: ${primer_error_rate}"
    echo "cutadapt mode: independent primer trimming, keeping records without primer matches"
    echo "cutadapt reverse-complement orientation during trimming: ${allow_revcomp}"
    echo "cutadapt executable: ${cutadapt_bin}"
    echo "cutadapt log: ${log_file}"

    set +e
    if [ "${allow_revcomp}" = "yes" ] && cutadapt_supports_revcomp; then
        "${cutadapt_bin}" --revcomp "${cutadapt_options[@]}" "${input}" > "${log_file}" 2>&1
        status=$?
    else
        if [ "${allow_revcomp}" = "yes" ]; then
            echo "cutadapt --revcomp is not available; trimming only records already in forward orientation." | tee "${log_file}"
        else
            echo "Sequences were already oriented before trimming; cutadapt --revcomp disabled for this trimming call." | tee "${log_file}"
        fi
        "${cutadapt_bin}" "${cutadapt_options[@]}" "${input}" >> "${log_file}" 2>&1
        status=$?
    fi
    set -e

    if [ "${status}" -ne 0 ]; then
        echo
        echo "cutadapt failed for ${label} with exit code ${status}."
        echo "--- cutadapt log ---"
        cat "${log_file}" || true
        echo "--- end cutadapt log ---"
        exit "${status}"
    fi

    echo "cutadapt finished for ${label}."
    echo "--- cutadapt summary ---"
    grep -E "^(Total reads processed|Reads with adapters|Reads written|Total basepairs processed|Quality-trimmed|Total written|Pairs written)" "${log_file}" || tail -n 20 "${log_file}" || true
    echo "--- end cutadapt summary ---"
}

write_msi_style_orientation_adapters() {
    local output="$1"

    {
        printf '>forward:F-RCR\n%s...%s\n' "${primer_f}" "${primer_r_rc}"
        printf '>reverse:R-RCF\n%s...%s\n' "${primer_r}" "${primer_f_rc}"
    } > "${output}"
}

orient_labeled_fasta_by_primers() {
    local input="$1"
    local output="$2"

    awk -v primer_f="${primer_f}" -v primer_r="${primer_r}" -v primer_f_rc="${primer_f_rc}" -v primer_r_rc="${primer_r_rc}" '
        function comp(base) {
            base = toupper(base)
            if (base == "A") return "T"
            if (base == "C") return "G"
            if (base == "G") return "C"
            if (base == "T") return "A"
            if (base == "R") return "Y"
            if (base == "Y") return "R"
            if (base == "K") return "M"
            if (base == "M") return "K"
            if (base == "S") return "S"
            if (base == "W") return "W"
            if (base == "B") return "V"
            if (base == "D") return "H"
            if (base == "H") return "D"
            if (base == "V") return "B"
            return "N"
        }
        function revcomp(seq,   idx,out) {
            out = ""
            for (idx = length(seq); idx >= 1; idx--)
                out = out comp(substr(seq, idx, 1))
            return out
        }
        function base_matches(code, base) {
            code = toupper(code)
            base = toupper(base)
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
            seq = toupper(seq)
            primer = toupper(primer)
            if (length(primer) == 0 || length(seq) < length(primer))
                return 0
            for (idx = 1; idx <= length(seq) - length(primer) + 1; idx++) {
                ok = 1
                for (jdx = 1; jdx <= length(primer); jdx++) {
                    if (!base_matches(substr(primer, jdx, 1), substr(seq, idx + jdx - 1, 1))) {
                        ok = 0
                        break
                    }
                }
                if (ok)
                    return 1
            }
            return 0
        }
        function forward_score(seq) {
            return has_iupac_match(seq, primer_f) + has_iupac_match(seq, primer_r_rc)
        }
        function reverse_score(seq) {
            return has_iupac_match(seq, primer_r) + has_iupac_match(seq, primer_f_rc)
        }
        function annotate_header(value) {
            return header (header ~ /;$/ ? value : ";" value)
        }
        function flush_record(   score_fwd,score_rev) {
            if (header == "")
                return

            if (header ~ /adapter=reverse:/ || header ~ /adapter=reverse;/ || header ~ /adapter=reverse$/) {
                print annotate_header("reoriented=reverse_complement;orientation_source=cutadapt")
                print revcomp(seq)
                reoriented++
                cutadapt_reverse++
            } else if (header ~ /adapter=forward:/ || header ~ /adapter=forward;/ || header ~ /adapter=forward$/) {
                print annotate_header("reoriented=forward;orientation_source=cutadapt")
                print seq
                cutadapt_forward++
            } else {
                score_fwd = forward_score(seq)
                score_rev = reverse_score(seq)
                if (score_rev > score_fwd) {
                    print annotate_header("reoriented=reverse_complement;orientation_source=iupac_fallback")
                    print revcomp(seq)
                    reoriented++
                    fallback_reverse++
                } else {
                    print annotate_header("reoriented=forward;orientation_source=iupac_fallback")
                    print seq
                    fallback_forward++
                }
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
            print "FASTA records oriented: " (total + 0) > "/dev/stderr"
            print "Records reverse-complemented: " (reoriented + 0) > "/dev/stderr"
            print "Cutadapt forward-orientation labels: " (cutadapt_forward + 0) > "/dev/stderr"
            print "Cutadapt reverse-orientation labels: " (cutadapt_reverse + 0) > "/dev/stderr"
            print "Fallback forward-orientation calls: " (fallback_forward + 0) > "/dev/stderr"
            print "Fallback reverse-orientation calls: " (fallback_reverse + 0) > "/dev/stderr"
        }
    ' "${input}" > "${output}"
}

select_isonclust3_representative_as_fasta() {
    local input_fastq="$1"
    local output_fasta="$2"
    local label="$3"
    local read_count="$4"

    awk -v label="${label}" -v read_count="${read_count}" '
        NR % 4 == 1 {
            read_id = $0
            sub(/^@/, "", read_id)
            sub(/[[:space:]].*$/, "", read_id)
            next
        }
        NR % 4 == 2 {
            print ">" label ";seed_read=" read_id ";seed_source=isonclust3_representative;seed_orientation=unknown;size=" read_count ";"
            print toupper($0)
            print "Selected isONclust3 representative for " label ": " read_id > "/dev/stderr"
            exit
        }
    ' "${input_fastq}" > "${output_fasta}"
}

orient_fasta_by_primers() {
    local input="$1"
    local output="$2"
    local label="$3"
    local log_file="${outdir}/primer_oriented/${label}.orientation.log"
    local adapters_file="${outdir}/primer_oriented/${label}.orientation_adapters.fasta"
    local labeled_fasta="${outdir}/primer_oriented/${label}.cutadapt_labeled.fasta"
    local status

    echo "Orienting FASTA records with primers: ${label}"
    echo "Primer FASTA convention: first sequence is forward primer; second sequence is reverse primer."
    echo "Forward primer: ${primer_f}"
    echo "Reverse primer: ${primer_r}"
    echo "Forward primer reverse-complement expected on reverse-oriented records: ${primer_f_rc}"
    echo "Reverse primer reverse-complement expected at the 3' end: ${primer_r_rc}"
    echo "Primer max error rate: ${primer_error_rate}"
    echo "orientation log: ${log_file}"

    write_msi_style_orientation_adapters "${adapters_file}"

    if cutadapt_supports_action_none; then
        {
            echo "cutadapt orientation mode: MSI-style linked primer labels with --action=none"
            echo "cutadapt executable: ${cutadapt_bin}"
            echo "orientation adapters: ${adapters_file}"
            cat "${adapters_file}"
        } > "${log_file}"

        set +e
        "${cutadapt_bin}" \
            --fasta \
            --action=none \
            -e "${primer_error_rate}" \
            --cores "${threads}" \
            -g "file:${adapters_file}" \
            -y ";adapter={name};" \
            -o "${labeled_fasta}" \
            "${input}" >> "${log_file}" 2>&1
        status=$?
        set -e

        if [ "${status}" -ne 0 ]; then
            echo
            echo "cutadapt orientation failed for ${label} with exit code ${status}."
            echo "--- cutadapt orientation log ---"
            cat "${log_file}" || true
            echo "--- end cutadapt orientation log ---"
            exit "${status}"
        fi

        orient_labeled_fasta_by_primers "${labeled_fasta}" "${output}" 2>> "${log_file}"
    else
        {
            echo "cutadapt --action=none is not available."
            echo "Using exact IUPAC-aware MSI-style primer-orientation fallback."
            echo "The fallback does not apply primer_error_rate mismatches."
        } > "${log_file}"

        orient_labeled_fasta_by_primers "${input}" "${output}" 2>> "${log_file}"
    fi

    if [ ! -s "${output}" ]; then
        echo "Primer orientation finished without creating a non-empty output for ${label}."
        echo "--- orientation log ---"
        cat "${log_file}" || true
        echo "--- end orientation log ---"
        exit 1
    fi

    echo "Primer orientation finished for ${label}."
    echo "--- orientation summary ---"
    grep -E "^(Total reads processed|Reads with adapters|Reads written|FASTA records oriented|Records reverse-complemented|Cutadapt forward-orientation labels|Cutadapt reverse-orientation labels|Fallback forward-orientation calls|Fallback reverse-orientation calls)" "${log_file}" || tail -n 20 "${log_file}" || true
    echo "--- end orientation summary ---"
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

fastq_to_fasta() {
    local input="$1"
    local output="$2"

    awk '
        NR % 4 == 1 {
            header = $0
            sub(/^@/, ">", header)
            print header
            next
        }
        NR % 4 == 2 { print }
    ' "${input}" > "${output}"
}

extract_fastq_by_ids() {
    local input_fastq="$1"
    local ids_file="$2"
    local output_fastq="$3"

    awk '
        NR == FNR {
            keep[$1] = 1
            next
        }
        FNR % 4 == 1 {
            id = $0
            sub(/^@/, "", id)
            sub(/[[:space:]].*$/, "", id)
            keep_record = (id in keep)
        }
        keep_record { print }
    ' "${ids_file}" "${input_fastq}" > "${output_fastq}"
}

run_uchime_fasta() {
    local input_fasta="$1"
    local output_fasta="$2"
    local label="$3"
    local allow_empty="${4:-no}"
    local records

    records="$(count_fasta_records "${input_fasta}")"
    if [ "${records}" -lt 2 ]; then
        echo "${label}: fewer than two FASTA records; skipping de novo chimera filtering."
        cp "${input_fasta}" "${output_fasta}"
        return
    fi

    checkpoint "${label}: VSEARCH de novo chimera filtering started"
    run_vsearch \
        --uchime_denovo "${input_fasta}" \
        --nonchimeras "${output_fasta}" \
        --threads "${threads}"
    checkpoint "${label}: VSEARCH de novo chimera filtering done"

    if [ ! -s "${output_fasta}" ]; then
        echo "No non-chimeric records were retained for ${label}."
        if [ "${allow_empty}" = "yes" ]; then
            : > "${output_fasta}"
            return 1
        fi
        exit 1
    fi
}

chimera_filter_fastq() {
    local input_fastq="$1"
    local output_fastq="$2"
    local label="$3"
    local allow_empty="${4:-no}"
    local input_fasta="${outdir}/chimera_filtered/${label}.input.fasta"
    local nonchimera_fasta="${outdir}/chimera_filtered/${label}.nonchimeras.fasta"
    local ids_file="${outdir}/chimera_filtered/${label}.nonchimera_ids.txt"

    fastq_to_fasta "${input_fastq}" "${input_fasta}"
    if ! run_uchime_fasta "${input_fasta}" "${nonchimera_fasta}" "${label}" "${allow_empty}"; then
        : > "${output_fastq}"
        return 1
    fi

    grep '^>' "${nonchimera_fasta}" | sed 's/^>//; s/[[:space:]].*$//' > "${ids_file}"
    extract_fastq_by_ids "${input_fastq}" "${ids_file}" "${output_fastq}"

    if [ ! -s "${output_fastq}" ]; then
        echo "No FASTQ reads remained after chimera filtering for ${label}."
        if [ "${allow_empty}" = "yes" ]; then
            : > "${output_fastq}"
            return 1
        fi
        exit 1
    fi
}

append_fastq_with_sample_prefix() {
    local input="$1"
    local output="$2"
    local sample="$3"

    awk -v sample="${sample}" '
        NR % 4 == 1 {
            sub(/^@/, "@" sample "_")
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

    checkpoint "${label}: isONclust3 ${isonclust_mode} clustering started"
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
        echo "Rationale: isONclust3 writes cluster FASTQs from its sorted read order; this is the module-visible isONclust3 representative."
    } > "${seed_log}"

    select_isonclust3_representative_as_fasta "${input_fastq}" "${output_fasta}" "${label}" "${read_count}" 2>> "${seed_log}"

    cat "${seed_log}"

    if [ ! -s "${output_fasta}" ]; then
        echo "Could not create Nanopore Racon seed draft for ${label} from ${input_fastq}."
        exit 1
    fi
}

run_spoa_consensus() {
    local cluster_fastq="$1"
    local output_fasta="$2"
    local label="$3"
    local log_file="${outdir}/spoa/${label}.spoa.log"
    local status

    echo "SPOA command: ${spoa_bin} -m ${spoa_match} -n ${spoa_mismatch} -g ${spoa_gap_open} -e ${spoa_gap_extend} ${cluster_fastq}"

    set +e
    "${spoa_bin}" \
        -m "${spoa_match}" \
        -n "${spoa_mismatch}" \
        -g "${spoa_gap_open}" \
        -e "${spoa_gap_extend}" \
        "${cluster_fastq}" > "${output_fasta}" 2> "${log_file}"
    status=$?
    set -e

    if [ -s "${log_file}" ]; then
        cat "${log_file}"
    fi

    if [ "${status}" -ne 0 ]; then
        echo "SPOA failed for ${label} with exit code ${status}."
        exit "${status}"
    fi

    if [ ! -s "${output_fasta}" ]; then
        echo "SPOA finished without creating a non-empty output for ${label}."
        exit 1
    fi
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
    local spoa_fasta
    local centroid_fasta
    local polished_fasta

    : > "${output_fasta}"
    run_isonclust3_clustering "${label}" "${reads}"

    for cluster_fastq in "${isonclust3_cluster_fastqs[@]}"; do
        cluster_index=$((cluster_index + 1))
        draft_count_local=$((draft_count_local + 1))
        cluster_read_count="$(count_fastq_reads "${cluster_fastq}")"

        if [ "${cluster_read_count}" -lt "${min_cluster_size}" ]; then
            continue
        fi

        retained_count_local=$((retained_count_local + 1))
        cluster_label="${label}_cluster_${cluster_index}"
        polished_fasta="${outdir}/per_cluster/${cluster_label}.consensus.fasta"

        if [ "${platform}" = "nanopore" ]; then
            centroid_fasta="${outdir}/drafts/${cluster_label}.racon_seed.fasta"
            checkpoint "${cluster_label}: Nanopore Racon seed selection started"
            select_nanopore_racon_seed "${cluster_fastq}" "${centroid_fasta}" "${cluster_label}" "${cluster_read_count}"
            checkpoint "${cluster_label}: Nanopore Racon seed selection done"

            checkpoint "${cluster_label}: Racon polishing loop started"
            run_racon_iterations "${cluster_label}" "${cluster_fastq}" "${centroid_fasta}" "${polished_fasta}"
            checkpoint "${cluster_label}: Racon polishing loop done"
            cat "${polished_fasta}" >> "${output_fasta}"
        else
            spoa_fasta="${outdir}/drafts/${cluster_label}.spoa.fasta"
            checkpoint "${cluster_label}: SPOA consensus started"
            run_spoa_consensus "${cluster_fastq}" "${spoa_fasta}" "${cluster_label}"
            checkpoint "${cluster_label}: SPOA consensus done"
            cat "${spoa_fasta}" >> "${output_fasta}"
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

normalize_representative_ids() {
    local input="$1"
    local output="$2"
    local map_file="$3"

    : > "${map_file}"

    awk -v map_file="${map_file}" '
        /^>/ {
            old = $0
            sub(/^>/, "", old)
            sub(/[[:space:]].*$/, "", old)
            count += 1
            new_id = "OTU" count
            print old "\t" new_id >> map_file
            print ">" new_id
            next
        }
        { print }
    ' "${input}" > "${output}"
}

write_otu_table() {
    local table="$1"
    local otu_ids_file="${outdir}/otu_counts/otu_ids.txt"
    local sample_order_file="${outdir}/otu_counts/sample_order.txt"
    local raw_table="${outdir}/otu_counts/all_candidate_otu_table.tsv"
    local assigned_map="${outdir}/otu_counts/assigned_representative_id_map.tsv"
    local zero_ids="${outdir}/otu_counts/zero_assigned_candidate_otus.txt"
    local filtered_fasta="${outdir}/otu_counts/assigned_representatives.fasta"
    local mapping_file
    local counts_file
    local otu_id
    local sample
    local count
    local total
    local new_index
    local new_id
    local -a row_counts

    grep '^>' "${consensus_fasta}" | sed 's/^>//; s/[[:space:]].*$//' > "${otu_ids_file}"
    printf '%s\n' "${sample_names[@]}" > "${sample_order_file}"

    if [ ! -s "${otu_ids_file}" ]; then
        echo "No representative sequences were available for OTU table creation."
        exit 1
    fi

    for idx in "${!sample_names[@]}"; do
        sample="${sample_names[$idx]}"
        mapping_file="${outdir}/otu_counts/${sample}.reads_to_consensus.paf"
        counts_file="${outdir}/otu_counts/${sample}.counts.tsv"

        if [ ! -s "${sample_filtered_fastqs[$idx]}" ]; then
            checkpoint "${sample}: final-consensus mapping skipped because no reads survived filtering"
            : > "${mapping_file}"
            : > "${counts_file}"
            sample_final_reads[$idx]="0"
            continue
        fi

        checkpoint "${sample}: minimap2 final-consensus mapping for OTU counts started"
        run_minimap2 -x "${minimap_preset}" -t "${threads}" "${consensus_fasta}" "${sample_filtered_fastqs[$idx]}" > "${mapping_file}"
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

        total="$(awk '{sum += $2} END {print sum + 0}' "${counts_file}")"
        sample_final_reads[$idx]="${total}"
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
    } > "${raw_table}"

    : > "${assigned_map}"
    : > "${zero_ids}"

    {
        printf "OTU"
        for sample in "${sample_names[@]}"; do
            printf "\t%s" "${sample}"
        done
        printf "\n"

        new_index=0
        while IFS= read -r otu_id; do
            total=0
            row_counts=()

            for sample in "${sample_names[@]}"; do
                counts_file="${outdir}/otu_counts/${sample}.counts.tsv"
                count="$(awk -v otu="${otu_id}" '$1 == otu { print $2; found = 1 } END { if (!found) print 0 }' "${counts_file}")"
                row_counts+=("${count}")
                total=$((total + count))
            done

            if [ "${total}" -eq 0 ]; then
                printf "%s\n" "${otu_id}" >> "${zero_ids}"
                continue
            fi

            new_index=$((new_index + 1))
            new_id="OTU${new_index}"
            printf "%s\t%s\n" "${otu_id}" "${new_id}" >> "${assigned_map}"

            printf "%s" "${new_id}"
            for count in "${row_counts[@]}"; do
                printf "\t%s" "${count}"
            done
            printf "\n"
        done < "${otu_ids_file}"
    } > "${table}"

    if [ ! -s "${assigned_map}" ]; then
        echo "No representatives had reads assigned during final OTU counting."
        echo "All candidate representatives and mappings are kept in ${outdir}/otu_counts for debugging."
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
            sub(/[[:space:]].*$/, "", old)
            keep = old in id_map
            if (keep)
                print ">" id_map[old]
            next
        }
        keep { print }
    ' "${consensus_fasta}" > "${filtered_fasta}"

    mv "${filtered_fasta}" "${consensus_fasta}"

    if [ -s "${zero_ids}" ]; then
        echo "Dropped candidate OTUs with zero final read assignments:"
        sed 's/^/  /' "${zero_ids}"
    fi
}

write_stats_table() {
    local final_otus="$1"

    printf "sample\tplatform\traw_reads\tquality_filtered_reads\tlength_filtered_reads\tchimera_filtered_reads\tfinal_assigned_reads\tclustering_method\tminimap2_preset\tisONclust3_mode\tisONclust3_implied_k\tisONclust3_implied_w\tdraft_clusters\tretained_clusters\tfinal_otus\tracon_iterations\n" > "${stats_tsv}"

    for idx in "${!sample_names[@]}"; do
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "${sample_names[$idx]}" \
            "${platform}" \
            "${sample_raw_reads[$idx]}" \
            "${sample_quality_reads[$idx]}" \
            "${sample_length_reads[$idx]}" \
            "${sample_chimera_reads[$idx]}" \
            "${sample_final_reads[$idx]:-0}" \
            "isONclust3" \
            "${minimap_preset}" \
            "${isonclust_mode}" \
            "${isonclust_k_label}" \
            "${isonclust_w_label}" \
            "${cluster_draft_count}" \
            "${cluster_retained_count}" \
            "${final_otus}" \
            "$([ "${platform}" = "nanopore" ] && printf '%s' "${racon_iterations}" || printf '0')" >> "${stats_tsv}"
    done
}

validate_representatives_and_otu_table() {
    local fasta="$1"
    local table="$2"
    local fasta_ids="${outdir}/otu_counts/final_fasta_ids.txt"
    local table_ids="${outdir}/otu_counts/final_table_ids.txt"

    grep '^>' "${fasta}" | sed 's/^>//; s/[[:space:]].*$//' > "${fasta_ids}"
    awk 'NR > 1 { print $1 }' "${table}" > "${table_ids}"

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
    local chimera_reads="$6"

    sample_names+=("${sample}")
    sample_filtered_fastqs+=("${filtered_fastq}")
    sample_raw_reads+=("${raw_reads}")
    sample_quality_reads+=("${quality_reads}")
    sample_length_reads+=("${length_reads}")
    sample_chimera_reads+=("${chimera_reads}")
    sample_final_reads+=("0")
}

prepare_sample_reads() {
    local read_file="$1"
    local sample
    local raw_reads
    local quality_fastq
    local quality_reads
    local length_fastq
    local length_reads
    local primer_trimmed_fastq
    local chimera_fastq
    local chimera_reads
    local selected_fastq
    local selected_reads

    sample="$(sample_name_from_file "${read_file}")"
    quality_fastq="${outdir}/quality_filtered/${sample}.quality.fastq"
    length_fastq="${outdir}/length_filtered/${sample}.length.fastq"
    primer_trimmed_fastq="${outdir}/primer_trimmed/${sample}.primer_trimmed.fastq"
    chimera_fastq="${outdir}/chimera_filtered/${sample}.nonchimeras.fastq"

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

    if [ "${platform}" = "pacbio" ]; then
        if [ -n "${primer_file}" ] && [ "${primer_trimming}" = "yes" ]; then
            checkpoint "${sample}: raw HiFi primer trimming started"
            trim_primers "${length_fastq}" "${primer_trimmed_fastq}" "${sample}.raw_hifi_reads"
            checkpoint "${sample}: raw HiFi primer trimming done"
        else
            cp "${length_fastq}" "${primer_trimmed_fastq}"
        fi

        if ! chimera_filter_fastq "${primer_trimmed_fastq}" "${chimera_fastq}" "${sample}.hifi_reads" "yes"; then
            echo "No reads remained after chimera filtering for sample ${sample}; retaining sample with zero OTU counts."
            register_sample_for_otu_table "${sample}" "${chimera_fastq}" "${raw_reads}" "${quality_reads}" "${length_reads}" "0"
            return
        fi

        chimera_reads="$(count_fastq_reads "${chimera_fastq}")"
        if [ "${chimera_reads}" -eq 0 ]; then
            echo "No reads remained after chimera filtering for sample ${sample}; retaining sample with zero OTU counts."
            register_sample_for_otu_table "${sample}" "${chimera_fastq}" "${raw_reads}" "${quality_reads}" "${length_reads}" "0"
            return
        fi

        selected_fastq="${chimera_fastq}"
        selected_reads="${chimera_reads}"
    else
        selected_fastq="${length_fastq}"
        selected_reads="${length_reads}"
    fi

    register_sample_for_otu_table "${sample}" "${selected_fastq}" "${raw_reads}" "${quality_reads}" "${length_reads}" "${selected_reads}"
}

checkpoint "isONclust-for-Nanopore-PacBio input validation done"
echo "Input FASTQ files:"
printf '  %s\n' "${read_files[@]}"
echo "Sequencing platform: ${platform}"
echo "VSEARCH: ${vsearch_bin}"
echo "minimap2: $(command -v minimap2)"
echo "minimap2 preset: ${minimap_preset}"
echo "isONclust3: $(command -v isONclust3)"
echo "isONclust3 mode: ${isonclust_mode}"
echo "isONclust3 implied k: ${isonclust_k_label}"
echo "isONclust3 implied w: ${isonclust_w_label}"
echo "isONclust3 k/w overrides: not passed; this isONclust3 CLI accepts --mode only"
echo "Quality filter max expected error rate: ${maxee_rate}"
echo "Minimum read length: ${min_length:-none}"
echo "Maximum read length: ${max_length:-none}"
echo "Minimum reads per cluster: ${min_cluster_size}"
echo "Primer trimming: ${primer_trimming}"
if [ "${platform}" = "nanopore" ]; then
    echo "Nanopore initial draft: first isONclust3 cluster read used as the Racon seed"
    echo "Racon: $(command -v racon)"
    echo "Racon iterations: ${racon_iterations}"
else
    echo "SPOA: ${spoa_bin}"
    echo "SPOA scores: match=${spoa_match}, mismatch=${spoa_mismatch}, gap_open=${spoa_gap_open}, gap_extend=${spoa_gap_extend}"
fi
if [ -n "${primer_file}" ]; then
    load_primers "${primer_file}"
    echo "Primers FASTA: ${primer_file}"
    echo "Primer FASTA convention: first sequence is forward primer; second sequence is reverse primer"
    echo "Forward primer loaded from first FASTA record: ${primer_f}"
    echo "Reverse primer loaded from second FASTA record: ${primer_r}"
    echo "Primer max error rate: ${primer_error_rate}"
    if [ "${primer_trimming}" = "yes" ]; then
        echo "Final representative post-processing: orient by primers, then trim forward and reverse primers"
    else
        echo "Final representative post-processing: orient by primers; primer trimming disabled"
    fi
else
    echo "Primers FASTA: none"
fi

sample_names=()
sample_filtered_fastqs=()
sample_raw_reads=()
sample_quality_reads=()
sample_length_reads=()
sample_chimera_reads=()
sample_final_reads=()

pooled_fastq="${outdir}/pooled/pooled.${platform}.fastq"
: > "${pooled_fastq}"

for read_file in "${read_files[@]}"; do
    prepare_sample_reads "${read_file}"
    idx=$((${#sample_names[@]} - 1))
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

process_cluster_set "pooled" "${pooled_fastq}" "${preliminary_representatives}"

postprocessed_representatives="${preliminary_representatives}"
if [ -n "${primer_file}" ]; then
    oriented_representatives="${outdir}/primer_oriented/preliminary_representatives.oriented.fasta"
    primer_trimmed_representatives="${outdir}/primer_trimmed/preliminary_representatives.primer_trimmed.fasta"

    checkpoint "Post-consensus primer orientation started"
    orient_fasta_by_primers "${preliminary_representatives}" "${oriented_representatives}" "${platform}_representatives"
    checkpoint "Post-consensus primer orientation done"

    if [ "${primer_trimming}" = "yes" ]; then
        checkpoint "Post-consensus primer trimming started"
        trim_primers "${oriented_representatives}" "${primer_trimmed_representatives}" "${platform}_representatives" "no"
        checkpoint "Post-consensus primer trimming done"
        postprocessed_representatives="${primer_trimmed_representatives}"
    else
        echo "Primer trimming disabled; keeping oriented representative sequences untrimmed."
        postprocessed_representatives="${oriented_representatives}"
    fi
fi

representatives_for_normalization="${postprocessed_representatives}"
if [ "${platform}" = "nanopore" ]; then
    length_filtered_representatives="${outdir}/length_filtered/preliminary_representatives.length_filtered.fasta"
    checkpoint "Nanopore representative length filtering started"
    filter_fasta_by_length "${postprocessed_representatives}" "${length_filtered_representatives}" "nanopore_polished_consensus"
    checkpoint "Nanopore representative length filtering done"

    nonchimera_representatives="${outdir}/chimera_filtered/preliminary_representatives.nonchimeras.fasta"
    run_uchime_fasta "${length_filtered_representatives}" "${nonchimera_representatives}" "nanopore_polished_consensus"
    representatives_for_normalization="${nonchimera_representatives}"
fi

checkpoint "Representative FASTA ID normalization started"
normalize_representative_ids "${representatives_for_normalization}" "${consensus_fasta}" "${outdir}/otu_counts/representative_id_map.tsv"
checkpoint "Representative FASTA ID normalization done"

checkpoint "OTU table read-to-consensus mapping/counting started"
write_otu_table "${otu_table}"
checkpoint "OTU table read-to-consensus mapping/counting done"

final_otu_count="$(count_fasta_records "${consensus_fasta}")"

checkpoint "Run summary statistics writing started"
write_stats_table "${final_otu_count}"
checkpoint "Run summary statistics writing done"

checkpoint "Representative FASTA and OTU table ID validation started"
validate_representatives_and_otu_table "${consensus_fasta}" "${otu_table}"
checkpoint "Representative FASTA and OTU table ID validation done"

checkpoint "Compressing isONclust-for-Nanopore-PacBio results archive"
tar -czf "${results_archive}" "${outdir}" "${consensus_fasta}" "${otu_table}" "${stats_tsv}"
checkpoint "isONclust-for-Nanopore-PacBio results archive ready"

echo
echo "isONclust-for-Nanopore-PacBio finished."
echo "OTU table: ${otu_table}"
echo "OTU representative sequences: ${consensus_fasta}"
echo "Run summary statistics: ${stats_tsv}"
echo "Archive: ${results_archive}"
