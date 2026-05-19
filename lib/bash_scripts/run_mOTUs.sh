#!/usr/bin/env bash

set -euo pipefail

mode="single"
reads_pattern=""
fwd_pattern=""
rev_pattern=""
marker_genes="3"
alignment_length="75"
counting_mode="INSERT_SCALED"
fastp_trim="yes"
fastp_report_archive="mOTUs.fastp_reports.tar.gz"

checkpoint() {
    echo
    echo "== checkpoint == $*"
}

while getopts i:s:1:2:t:m:g:l:y:f:o:O:a:q: flag
do
    case "${flag}" in
        i) dir="${OPTARG}";;
        s) reads_pattern="${OPTARG}";;
        1) fwd_pattern="${OPTARG}";;
        2) rev_pattern="${OPTARG}";;
        t) threads="${OPTARG}";;
        m) mode="${OPTARG}";;
        g) marker_genes="${OPTARG}";;
        l) alignment_length="${OPTARG}";;
        y) counting_mode="${OPTARG}";;
        f) fastp_trim="${OPTARG}";;
        o) profile_matrix="${OPTARG}";;
        O) relative_matrix="${OPTARG}";;
        a) results_archive="${OPTARG}";;
        q) fastp_report_archive="${OPTARG}";;
        \?) echo "usage: run_mOTUs.sh -i dir [-s reads|-1 fwd -2 rev] -t threads -m single|paired -g marker_genes -l alignment_length -y counting_mode -f yes|no -o profile_matrix -O relative_matrix -a archive [-q fastp_report_archive]"; exit 1;;
    esac
done

required_vars=(dir threads profile_matrix relative_matrix results_archive)
for var_name in "${required_vars[@]}"; do
    if [ -z "${!var_name:-}" ]; then
        echo "Missing required option: ${var_name}"
        exit 1
    fi
done

cd "${dir}"

motus_db="${MOTUS_DB_PATH:-/app/lib/mOTUs/db/db_mOTU}"
echo "mOTUs database: ${motus_db}"

if [ ! -d "${motus_db}" ] || ! find "${motus_db}" -mindepth 1 -print -quit | grep -q .; then
    echo "mOTUs database is missing or empty."
    echo "Expected the db_mOTU directory at ${motus_db}"
    exit 1
fi

has_complete_bwa_index() {
    local bwt
    local prefix

    shopt -s nullglob
    for bwt in "${motus_db}"/*.bwt; do
        prefix="${bwt%.bwt}"
        if [ -f "${prefix}.amb" ] && [ -f "${prefix}.ann" ] && [ -f "${prefix}.pac" ] && [ -f "${prefix}.sa" ]; then
            return 0
        fi
    done

    return 1
}

if ! has_complete_bwa_index; then
    echo "mOTUs database appears incomplete: no complete BWA index was found in ${motus_db}"
    echo "Expected one index prefix with .bwt, .amb, .ann, .pac, and .sa files."
    echo "Remove the partial database and download it again:"
    echo "  rm -rf lib/mOTUs/db/db_mOTU"
    echo "  bash download_motus_db.sh"
    exit 1
fi
checkpoint "mOTUs database validation done"

if ! command -v motus >/dev/null 2>&1; then
    echo "motus is not available in PATH."
    echo "Rebuild the image with the mOTUs conda environment."
    exit 1
fi

motus_bin="$(command -v motus)"
motus_bin_dir="$(dirname "${motus_bin}")"
export PATH="${motus_bin_dir}:${PATH}"

motus_python="${motus_bin_dir}/python"
if [ ! -x "${motus_python}" ]; then
    motus_python="python"
fi

for dependency in bwa samtools vsearch; do
    if ! command -v "${dependency}" >/dev/null 2>&1; then
        echo "${dependency} is not available in PATH, but mOTUs needs it for read alignment."
        echo "Rebuild the image, or hot-fix the running container with:"
        echo "  conda install -n motus -y -c conda-forge -c bioconda 'bwa=0.7.19' samtools vsearch"
        exit 1
    fi
done

if ! "${motus_python}" - <<'PY'
import importlib.util
import sys
sys.exit(0 if importlib.util.find_spec("fetchMGs") or importlib.util.find_spec("fetchmgs") else 1)
PY
then
    echo "The fetchMGs/fetchmgs Python package is missing from the mOTUs environment."
    echo "The SLIM Dockerfile now installs motus-tool==4.0.4 with the official mOTUs helper dependencies."
    echo "Rebuild the image, or hot-fix the running container with:"
    echo "  conda install -n motus -y -c conda-forge -c bioconda fetchmgs"
    exit 1
fi

checkpoint "mOTUs compatibility patch check started"
"${motus_python}" - <<'PY'
import importlib.util
import pathlib
import re
import sys

spec = importlib.util.find_spec("motus.motus")
if spec is None or spec.origin is None:
    sys.exit("Unable to locate motus.motus for the mOTUs SAM stream compatibility patch")

path = pathlib.Path(spec.origin)
text = path.read_text()
old_cmd_re = re.compile(
    r"command:\s*str\s*=\s*f(['\"])bwa mem -a -t \{threads\} "
    r"\{MOTUS_DB\.get_bwa_index\(\)\} \{readsfile\}\1"
)
new_cmd = "command: str = f'bwa mem -a -t {threads} {MOTUS_DB.get_bwa_index()} {readsfile} | samtools view -b -'"
old_stream = "pysam.AlignmentFile(process.stdout, 'r')"
new_stream = "pysam.AlignmentFile(process.stdout, 'rb')"
changed = False

text, n_cmd = old_cmd_re.subn(new_cmd, text)
if n_cmd:
    changed = True
elif "samtools view -b -" not in text:
    print("Warning: mOTUs BWA-to-BAM command patch target was not found.", file=sys.stderr)

if old_stream in text:
    text = text.replace(old_stream, new_stream)
    changed = True
elif new_stream not in text:
    print("Warning: mOTUs BAM stream patch target was not found.", file=sys.stderr)

if changed:
    path.write_text(text)
    print("Applied mOTUs 4.0.4 BWA-to-BAM stream compatibility patch.")

text = path.read_text()
for line in text.splitlines():
    if "command:" in line and "bwa mem" in line:
        print("mOTUs map_tax command:", line.strip())
        break

if "samtools view -b -" not in text:
    sys.exit("mOTUs map_tax command is still not patched to produce BAM output")
PY
checkpoint "mOTUs compatibility patch check done"

motus_package_dir="$(
"${motus_python}" - <<'PY'
import importlib.util
import pathlib
import sys

spec = importlib.util.find_spec("motus")
if spec is None:
    sys.exit("Unable to locate the installed motus Python package")

if spec.submodule_search_locations:
    print(pathlib.Path(next(iter(spec.submodule_search_locations))).resolve())
elif spec.origin:
    print(pathlib.Path(spec.origin).resolve().parent)
else:
    sys.exit("Unable to locate the installed motus Python package")
PY
)"

motus_expected_db="${motus_package_dir}/db_mOTU"
if [ -L "${motus_expected_db}" ]; then
    rm -f "${motus_expected_db}"
elif [ -e "${motus_expected_db}" ]; then
    expected_real="$(realpath "${motus_expected_db}")"
    mounted_real="$(realpath "${motus_db}")"

    if [ "${expected_real}" != "${mounted_real}" ]; then
        rm -rf "${motus_expected_db}"
    fi
fi

if [ ! -e "${motus_expected_db}" ]; then
    ln -s "${motus_db}" "${motus_expected_db}"
fi

echo "mOTUs package database path: ${motus_expected_db}"
echo "mOTUs database index files:"
find -L "${motus_expected_db}" -type f \( -name "*.bwt" -o -name "*.amb" -o -name "*.ann" -o -name "*.pac" -o -name "*.sa" \) -print | sed 's/^/  /'
checkpoint "mOTUs package database link ready"

motus_bwa_index="${motus_expected_db}/mOTUsv4.0.db.fna.gz"
if [ ! -f "${motus_bwa_index}" ]; then
    echo "mOTUs BWA index FASTA is missing: ${motus_bwa_index}"
    exit 1
fi

outdir="mOTUs"
rm -rf "${outdir}"
mkdir -p "${outdir}"

fastp_report_dir="${outdir}/fastp_reports"
fastp_trim_dir="${outdir}/fastp_trimmed"

if [ "${fastp_trim}" = "yes" ]; then
    if ! command -v fastp >/dev/null 2>&1; then
        echo "fastp trimming was requested, but fastp is not available in PATH."
        echo "Rebuild the image with fastp available in the mOTUs or Kraken2/Bracken environment."
        exit 1
    fi

    mkdir -p "${fastp_report_dir}" "${fastp_trim_dir}"
else
    mkdir -p "${fastp_report_dir}"
    echo "fastp trimming was disabled for this mOTUs run." > "${fastp_report_dir}/fastp_skipped.txt"
fi

is_fastq_file() {
    local lower
    lower="$(printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]')"

    case "${lower}" in
        *.fastq|*.fastq.gz|*.fq|*.fq.gz) return 0 ;;
        *) return 1 ;;
    esac
}

strip_sequence_extension() {
    local sample="$1"

    sample="${sample%.gz}"
    sample="${sample%.fastq}"
    sample="${sample%.fq}"
    sample="${sample%.fasta}"
    sample="${sample%.fa}"

    printf '%s\n' "${sample}"
}

strip_pair_suffix() {
    local sample="$1"

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
    sample="${sample%_forward}"
    sample="${sample%_reverse}"

    printf '%s\n' "${sample}"
}

sample_name_from_file() {
    local sample
    sample="$(basename "$1")"
    sample="$(strip_sequence_extension "${sample}")"
    printf '%s\n' "${sample}"
}

sample_name_from_pair() {
    local fwd
    local rev
    local fwd_stripped
    local rev_stripped

    fwd="$(sample_name_from_file "$1")"
    rev="$(sample_name_from_file "$2")"
    fwd_stripped="$(strip_pair_suffix "${fwd}")"
    rev_stripped="$(strip_pair_suffix "${rev}")"

    if [ "${fwd_stripped}" = "${rev_stripped}" ]; then
        printf '%s\n' "${fwd_stripped}"
    else
        printf '%s\n' "${fwd}"
    fi
}

first_sequence_arg() {
    local expect_sequence="no"

    for arg in "$@"; do
        case "${arg}" in
            -f|-r|-s)
                expect_sequence="yes"
                ;;
            -*)
                expect_sequence="no"
                ;;
            *)
                if [ "${expect_sequence}" = "yes" ]; then
                    printf '%s\n' "${arg}"
                    return 0
                fi
                ;;
        esac
    done

    return 1
}

make_sequence_subset() {
    local input="$1"
    local output="$2"
    local lower

    lower="$(printf '%s\n' "${input}" | tr '[:upper:]' '[:lower:]')"
    if [[ "${lower}" == *.gz ]]; then
        gzip -dc "${input}" | sed -n '1,4000p' > "${output}"
    else
        sed -n '1,4000p' "${input}" > "${output}"
    fi
}

preflight_motus_alignment() {
    local sample="$1"
    shift

    local read_file
    local subset_file
    local preflight_bam
    local preflight_sam
    local bwa_log
    local samtools_log
    local bwa_status

    read_file="$(first_sequence_arg "$@")" || {
        echo "Unable to find a sequence file in mOTUs arguments:"
        printf '  %s\n' "$@"
        exit 1
    }

    subset_file="${outdir}/${sample}.mOTUs.preflight.fastq"
    preflight_sam="${outdir}/${sample}.mOTUs.preflight.sam"
    preflight_bam="${outdir}/${sample}.mOTUs.preflight.bam"
    bwa_log="${outdir}/${sample}.bwa.stderr.log"
    samtools_log="${outdir}/${sample}.samtools.stderr.log"

    make_sequence_subset "${read_file}" "${subset_file}"

    checkpoint "${sample}: mOTUs BWA/samtools preflight started"
    echo "Testing mOTUs BWA/samtools alignment on a small read subset:"
    echo "  bwa mem -a -t ${threads} ${motus_bwa_index} ${subset_file}"

    set +e
    bwa mem -a -t "${threads}" "${motus_bwa_index}" "${subset_file}" > "${preflight_sam}" 2> "${bwa_log}"
    bwa_status=$?
    set -e

    if [ "${bwa_status}" -ne 0 ] || ! grep -q '^@SQ' "${preflight_sam}"; then
        echo "mOTUs BWA preflight failed or produced no SAM header."
        echo "bwa exit code: ${bwa_status}"
        if [ "${bwa_status}" -eq 137 ]; then
            echo
            echo "BWA was killed by the operating system, almost certainly because the container ran out of RAM."
            echo "The mOTUs v4 database is large; BWA must load a multi-GB index before it can align reads."
            echo "Increase the Docker/Podman VM memory, then rerun this module."
            echo "Suggested Podman commands on macOS:"
            echo "  podman machine stop"
            echo "  podman machine set --memory 24576"
            echo "  podman machine start"
            echo "For Docker Desktop, increase Resources > Memory to at least 16 GB, preferably 24 GB."
            echo
        fi
        echo "BWA executable: $(command -v bwa)"
        bwa 2>&1 | head -n 3 || true
        echo "Available memory inside container:"
        free -h || true
        echo "Reference prefix:"
        ls -lh "${motus_bwa_index}" "${motus_bwa_index}".* 2>/dev/null || true
        echo "Read subset:"
        wc -l "${subset_file}" || true
        sed -n '1,8p' "${subset_file}" || true
        echo "--- bwa stderr ---"
        cat "${bwa_log}" || true
        echo "--- bwa stdout head ---"
        sed -n '1,20p' "${preflight_sam}" || true
        exit 1
    fi

    echo "  samtools view -b ${preflight_sam}"
    if ! samtools view -b "${preflight_sam}" > "${preflight_bam}" 2> "${samtools_log}"; then
        echo "mOTUs BWA/samtools preflight failed."
        echo "--- bwa stderr ---"
        cat "${bwa_log}" || true
        echo "--- samtools stderr ---"
        cat "${samtools_log}" || true
        exit 1
    fi

    if ! samtools quickcheck "${preflight_bam}" >/dev/null 2>&1; then
        echo "mOTUs BWA/samtools preflight produced an invalid BAM file."
        echo "--- bwa stderr ---"
        cat "${bwa_log}" || true
        echo "--- samtools stderr ---"
        cat "${samtools_log}" || true
        exit 1
    fi

    rm -f "${subset_file}" "${preflight_sam}" "${preflight_bam}"
    checkpoint "${sample}: mOTUs BWA/samtools preflight done"
}

run_motus_profile() {
    local sample="$1"
    shift

    local profile="${outdir}/${sample}.mOTUs.profile.tsv"

    echo
    echo "Processing sample: ${sample}"
    echo "mOTUs input files:"
    printf '  %s\n' "$@"

    preflight_motus_alignment "${sample}" "$@"

    checkpoint "${sample}: mOTUs profile started"
    motus profile \
        "$@" \
        -n "${sample}" \
        -o "${profile}" \
        -t "${threads}" \
        -g "${marker_genes}" \
        -l "${alignment_length}" \
        -y "${counting_mode}"
    checkpoint "${sample}: mOTUs profile done"

    profile_files+=("${profile}")

    if [ -f "${profile}.relab" ]; then
        relab_files+=("${profile}.relab")
    fi
}

merge_profiles() {
    local output_file="$1"
    shift

    local files=("$@")

    if [ "${#files[@]}" -eq 0 ]; then
        echo "No mOTUs profiles were produced."
        exit 1
    fi

    if [ "${#files[@]}" -eq 1 ]; then
        cp "${files[0]}" "${output_file}"
    else
        motus merge -i "${files[@]}" -o "${output_file}"
    fi
}

shopt -s nullglob

profile_files=()
relab_files=()

if [ "${mode}" = "paired" ]; then
    fwd_pattern="${fwd_pattern//€/*}"
    rev_pattern="${rev_pattern//€/*}"
    fwd_files=( ${fwd_pattern} )
    rev_files=( ${rev_pattern} )

    if [ "${#fwd_files[@]}" -eq 0 ]; then
        echo "No forward sequence files matched: ${fwd_pattern}"
        exit 1
    fi

    if [ "${#rev_files[@]}" -eq 0 ]; then
        echo "No reverse sequence files matched: ${rev_pattern}"
        exit 1
    fi

    if [ "${#fwd_files[@]}" -ne "${#rev_files[@]}" ]; then
        echo "Different numbers of forward and reverse reads:"
        echo "Forward: ${#fwd_files[@]}"
        echo "Reverse: ${#rev_files[@]}"
        exit 1
    fi

    echo "Forward files:"
    printf '  %s\n' "${fwd_files[@]}"
    echo "Reverse files:"
    printf '  %s\n' "${rev_files[@]}"

    for idx in "${!fwd_files[@]}"; do
        sample="$(sample_name_from_pair "${fwd_files[$idx]}" "${rev_files[$idx]}")"
        motus_fwd="${fwd_files[$idx]}"
        motus_rev="${rev_files[$idx]}"

        if [ "${fastp_trim}" = "yes" ]; then
            if is_fastq_file "${motus_fwd}" && is_fastq_file "${motus_rev}"; then
                trimmed_fwd="${fastp_trim_dir}/${sample}.R1.fastp.fastq"
                trimmed_rev="${fastp_trim_dir}/${sample}.R2.fastp.fastq"

                checkpoint "${sample}: fastp trimming started"
                fastp \
                    -i "${motus_fwd}" \
                    -I "${motus_rev}" \
                    -o "${trimmed_fwd}" \
                    -O "${trimmed_rev}" \
                    --detect_adapter_for_pe \
                    --thread "${threads}" \
                    --html "${fastp_report_dir}/${sample}.fastp.html" \
                    --json "${fastp_report_dir}/${sample}.fastp.json"
                checkpoint "${sample}: fastp trimming done"

                motus_fwd="${trimmed_fwd}"
                motus_rev="${trimmed_rev}"
            else
                echo "Skipping fastp for sample ${sample}: paired inputs are not FASTQ files."
            fi
        fi

        run_motus_profile "${sample}" -f "${motus_fwd}" -r "${motus_rev}"
    done
else
    reads_pattern="${reads_pattern//€/*}"
    read_files=( ${reads_pattern} )

    if [ "${#read_files[@]}" -eq 0 ]; then
        echo "No sequence files matched: ${reads_pattern}"
        echo "Available sequence files in ${dir}:"
        find . -maxdepth 1 -type f \( -name "*.fastq" -o -name "*.fastq.gz" -o -name "*.fq" -o -name "*.fq.gz" -o -name "*.fasta" -o -name "*.fasta.gz" -o -name "*.fa" -o -name "*.fa.gz" \) -printf "  %f\n" | sort
        exit 1
    fi

    echo "Read files:"
    printf '  %s\n' "${read_files[@]}"

    for file in "${read_files[@]}"; do
        sample="$(sample_name_from_file "${file}")"
        motus_file="${file}"

        if [ "${fastp_trim}" = "yes" ]; then
            if is_fastq_file "${motus_file}"; then
                trimmed_file="${fastp_trim_dir}/${sample}.fastp.fastq"

                checkpoint "${sample}: fastp trimming started"
                fastp \
                    -i "${motus_file}" \
                    -o "${trimmed_file}" \
                    --thread "${threads}" \
                    --html "${fastp_report_dir}/${sample}.fastp.html" \
                    --json "${fastp_report_dir}/${sample}.fastp.json"
                checkpoint "${sample}: fastp trimming done"

                motus_file="${trimmed_file}"
            else
                echo "Skipping fastp for sample ${sample}: input is not a FASTQ file."
            fi
        fi

        run_motus_profile "${sample}" -s "${motus_file}"
    done
fi

checkpoint "mOTUs profile merge started"
merge_profiles "${profile_matrix}" "${profile_files[@]}"
checkpoint "mOTUs profile merge done"

if [ "${#relab_files[@]}" -gt 0 ]; then
    checkpoint "mOTUs relative-abundance profile merge started"
    merge_profiles "${relative_matrix}" "${relab_files[@]}"
    checkpoint "mOTUs relative-abundance profile merge done"
else
    echo "mOTUs did not produce .relab files; copying the merged profile to ${relative_matrix}."
    cp "${profile_matrix}" "${relative_matrix}"
fi

cp "${profile_matrix}" "${outdir}/${profile_matrix}"
cp "${relative_matrix}" "${outdir}/${relative_matrix}"
rm -rf "${fastp_trim_dir}"
checkpoint "Compressing mOTUs fastp reports"
tar -czf "${fastp_report_archive}" "${fastp_report_dir}"
checkpoint "Compressing mOTUs results archive"
tar -czf "${results_archive}" "${outdir}"
checkpoint "mOTUs archives ready"

echo
echo "mOTUs finished."
echo "Merged profile: ${profile_matrix}"
echo "Merged relative profile: ${relative_matrix}"
echo "fastp reports archive: ${fastp_report_archive}"
echo "Results archive: ${results_archive}"
