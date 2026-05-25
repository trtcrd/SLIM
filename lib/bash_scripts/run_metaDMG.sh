#!/usr/bin/env bash

set -euo pipefail

run_mode="1"
min_length="35"
print_length="5"
min_ani="-1"
max_ani=""
best_as="0"
showfits="0"
nbootstrap="0"
library_type="ds"
acc2tax=""
reference_fasta=""

checkpoint() {
    echo
    echo "== checkpoint == $*"
}

while getopts i:b:t:r:l:p:A:B:S:n:L:C:R:o:s:a: flag
do
    case "${flag}" in
        i) dir="${OPTARG}";;
        b) bam_pattern="${OPTARG}";;
        t) threads="${OPTARG}";;
        r) run_mode="${OPTARG}";;
        l) min_length="${OPTARG}";;
        p) print_length="${OPTARG}";;
        A) min_ani="${OPTARG}";;
        B) max_ani="${OPTARG}";;
        S) showfits="${OPTARG}";;
        n) nbootstrap="${OPTARG}";;
        L) library_type="${OPTARG}";;
        C) acc2tax="${OPTARG}";;
        R) reference_fasta="${OPTARG}";;
        o) output_prefix="${OPTARG}";;
        s) summary="${OPTARG}";;
        a) archive="${OPTARG}";;
        \?) echo "usage: run_metaDMG.sh -i dir -b bam_pattern -t threads -r run_mode -l min_length -p print_length -A min_ani -B max_ani -S showfits -n nbootstrap -L ds|ss [-C acc2tax] [-R reference] -o output_prefix -s summary -a archive"; exit 1;;
    esac
done

required_vars=(dir bam_pattern threads output_prefix summary archive)
for var_name in "${required_vars[@]}"; do
    if [ -z "${!var_name:-}" ]; then
        echo "Missing required option: ${var_name}"
        exit 1
    fi
done

cd "${dir}"

if command -v metaDMG-cpp >/dev/null 2>&1; then
    metadmg_cmd="metaDMG-cpp"
elif command -v metaDMG >/dev/null 2>&1; then
    metadmg_cmd="metaDMG"
else
    echo "metaDMG-cpp was not found in PATH."
    exit 1
fi

bam_pattern="${bam_pattern//€/*}"
shopt -s nullglob
bam_files=( ${bam_pattern} )

if [ "${#bam_files[@]}" -eq 0 ]; then
    echo "No BAM/SAM/CRAM files matched: ${bam_pattern}"
    exit 1
fi

if [ "${run_mode}" = "2" ] && [ -z "${acc2tax}" ]; then
    echo "run_mode 2 requires an acc2tax file."
    exit 1
fi

outdir="metaDMG"
rm -rf "${outdir}"
mkdir -p "${outdir}"

printf "sample\tbdamage\tfit\n" > "${summary}"

sample_name_from_bam() {
    local sample
    sample="$(basename "$1")"
    sample="${sample%.gz}"
    sample="${sample%.cram}"
    sample="${sample%.bam}"
    sample="${sample%.sam}"
    printf '%s\n' "${sample}"
}

for bam in "${bam_files[@]}"; do
    sample="$(sample_name_from_bam "${bam}")"
    prefix="${outdir}/${sample}.${output_prefix}"
    getdamage_args=(getdamage "${bam}" -n "${threads}" -l "${min_length}" -p "${print_length}" -r "${run_mode}" -o "${prefix}" -i)

    if [ -n "${reference_fasta}" ]; then
        getdamage_args+=(-f "${reference_fasta}")
    fi

    if [ "${min_ani}" != "-1" ] && [ -n "${min_ani}" ]; then
        getdamage_args+=(--min_ani "${min_ani}")
    fi

    if [ -n "${max_ani}" ]; then
        getdamage_args+=(--max_ani "${max_ani}")
    fi

    if [ "${best_as}" = "1" ]; then
        getdamage_args+=(--best_as 1)
    fi

    if [ "${run_mode}" = "2" ]; then
        getdamage_args+=(--acc2tax "${acc2tax}")
    fi

    checkpoint "${sample}: metaDMG getdamage started"
    "${metadmg_cmd}" "${getdamage_args[@]}"
    checkpoint "${sample}: metaDMG getdamage done"

    bdamage="${prefix}.bdamage.gz"
    if [ ! -f "${bdamage}" ]; then
        echo "Expected metaDMG output was not found: ${bdamage}"
        exit 1
    fi

    dfit_args=(dfit "${bdamage}" --threads "${threads}" --showfits "${showfits}" --nbootstrap "${nbootstrap}" --lib "${library_type}" --out "${prefix}.dfit")

    if [ "${run_mode}" = "1" ]; then
        dfit_args+=(--bam "${bam}")
    fi

    checkpoint "${sample}: metaDMG dfit started"
    "${metadmg_cmd}" "${dfit_args[@]}"
    checkpoint "${sample}: metaDMG dfit done"

    printf "%s\t%s\t%s\n" "${sample}" "${bdamage}" "${prefix}.dfit" >> "${summary}"
done

cp "${summary}" "${outdir}/${summary}"
checkpoint "Compressing metaDMG results archive"
tar --use-compress-program=pigz -cf "${archive}" "${outdir}" "${summary}"
checkpoint "metaDMG results archive ready"

echo
echo "metaDMG finished."
echo "Summary: ${summary}"
echo "Archive: ${archive}"
