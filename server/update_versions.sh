#!/usr/bin/env bash

set -u
set -o pipefail

VERSIONS_FILE="${1:-/app/versions.tsv}"

if [ ! -f "${VERSIONS_FILE}" ]; then
    echo "versions.tsv not found at ${VERSIONS_FILE}; skipping version refresh." >&2
    exit 0
fi

first_version()
{
    tr -d '\r' | grep -Eo '[0-9]+([._+-][0-9A-Za-z]+)+' | head -n 1 || true
}

clean_version()
{
    tr '\t\r\n' '   ' | sed -E 's/^ +| +$//g; s/ +/ /g'
}

command_version()
{
    "$@" 2>&1 | first_version
}

conda_pkg_version()
{
    local env_name="$1"
    local pkg_name="$2"

    conda list -n "${env_name}" 2>/dev/null | awk -v pkg="${pkg_name}" '
        BEGIN { pkg=tolower(pkg) }
        /^[[:space:]]*#/ { next }
        tolower($1) == pkg { print $2; exit }
    '
}

python_module_version()
{
    local env_name="$1"
    local module_name="$2"

    if [ "${env_name}" = "system" ]; then
        python3 - "${module_name}" 2>/dev/null <<'PY'
import importlib
import sys

module = importlib.import_module(sys.argv[1])
print(getattr(module, "__version__", ""))
PY
    else
        conda run -n "${env_name}" python - "${module_name}" 2>/dev/null <<'PY'
import importlib
import sys

module = importlib.import_module(sys.argv[1])
print(getattr(module, "__version__", ""))
PY
    fi
}

git_source_version()
{
    local source_dir="$1"
    local prefix="${2:-git}"

    if git -C "${source_dir}" rev-parse --short HEAD >/dev/null 2>&1; then
        printf '%s-%s\n' "${prefix}" "$(git -C "${source_dir}" rev-parse --short HEAD)"
    fi
}

description_version()
{
	local description_file="$1"

	awk -F ': *' '$1 == "Version" { print $2; exit }' "${description_file}" 2>/dev/null
}

shell_var_version()
{
    local source_file="$1"
    local variable_name="$2"

    awk -F '=' -v variable="${variable_name}" '
        $1 == variable {
            gsub(/["'\''[:space:]]/, "", $2)
            print $2
            exit
        }
    ' "${source_file}" 2>/dev/null
}

c_define_version()
{
    local source_file="$1"
    local variable_name="$2"

    awk -v variable="${variable_name}" '
        $1 == "#define" && $2 == variable {
            gsub(/"/, "", $3)
            print $3
            exit
        }
    ' "${source_file}" 2>/dev/null
}

source_first_version()
{
    local source_file="$1"
    local pattern="$2"

    grep -E "${pattern}" "${source_file}" 2>/dev/null | first_version
}

crate_version()
{
    local crate_name="$1"
    local crates_file="$2"

	awk -v crate="${crate_name}" '
        BEGIN { crate=tolower(crate) }
        tolower($0) ~ "\"" crate " " {
            gsub("\"", "", $0)
            split($0, fields, " ")
            print fields[2]
            exit
        }
    ' "${crates_file}" 2>/dev/null
}

update_version()
{
    local name="$1"
    local version="$2"
    local tmp_file

    version="$(printf '%s' "${version}" | clean_version)"
    if [ -z "${version}" ]; then
        echo "No version detected for ${name}; leaving current entry unchanged." >&2
        return 0
    fi

    tmp_file="$(mktemp)"
    awk -F '\t' -v OFS='\t' -v name="${name}" -v version="${version}" '
        $1 == name && $2 == "build-time" { $2 = version }
        { print }
    ' "${VERSIONS_FILE}" > "${tmp_file}" && mv "${tmp_file}" "${VERSIONS_FILE}"
}

version_or_conda_pkg()
{
    local env_name="$1"
    local binary_name="$2"
    local pkg_name="${3:-${binary_name}}"
    shift 3 || true

    local version
    version="$(conda run -n "${env_name}" "${binary_name}" "$@" 2>&1 | first_version)"
    if [ -z "${version}" ]; then
        version="$(conda_pkg_version "${env_name}" "${pkg_name}")"
    fi
	printf '%s\n' "${version}"
}

first_nonempty()
{
    local value

    for value in "$@"; do
        if [ -n "${value}" ]; then
            printf '%s\n' "${value}"
            return 0
        fi
    done
}

update_version "lulu" "$(description_version /app/lib/lulu/DESCRIPTION)"
update_version "fastp" "$(version_or_conda_pkg kraken2 fastp fastp --version)"
update_version "MSI" "$(shell_var_version /app/lib/msi/scripts/msi_install.sh MSI_VERSION)"
update_version "fastq_utils" "$(c_define_version /app/lib/msi/fastq_utils/src/fastq.h VERSION)"
update_version "seqtk" "$(source_first_version /app/lib/msi/seqtk/seqtk.c 'Version:')"
update_version "Kraken2" "$(version_or_conda_pkg kraken2 kraken2 kraken2 --version)"
update_version "Bracken" "$(conda_pkg_version kraken2 bracken)"
update_version "fetchMGs" "$(first_nonempty "$(conda_pkg_version motus fetchmg)" "$(conda_pkg_version motus fetchmgs)")"
update_version "minimap2" "$(version_or_conda_pkg isonclust3 minimap2 minimap2 --version)"
update_version "yacrd" "$(version_or_conda_pkg isonclust3 yacrd yacrd --version)"
update_version "isONclust3" "$(first_nonempty "$(version_or_conda_pkg isonclust3 isONclust3 isonclust3 --version)" "$(crate_version isONclust3 /root/miniforge3/envs/isonclust3/.crates.toml)")"
update_version "cutadapt" "$(version_or_conda_pkg isonclust3 cutadapt cutadapt --version)"
update_version "metaDMG" "$(conda_pkg_version ancientdna metadmg)"
update_version "NCBI Datasets CLI" "$(conda_pkg_version ancientdna ncbi-datasets-cli)"
update_version "BWA" "$(conda run -n ancientdna bwa 2>&1 | awk '/Version:/ { print $2; exit }')"
update_version "SAMtools" "$(version_or_conda_pkg ancientdna samtools samtools --version)"

update_version "Node.js" "$(command_version node --version)"
update_version "npm" "$(command_version npm --version)"
update_version "R" "$(command_version R --version)"
update_version "Biopython" "$(python_module_version system Bio)"
update_version "Miniforge" "conda-$(command_version conda --version)"
update_version "mamba" "$(command_version mamba --version)"
update_version "polars-lts-cpu" "$(python_module_version singlem polars)"
update_version "polars[rtcompat]" "$(python_module_version motus polars)"

echo "Refreshed build-time entries in ${VERSIONS_FILE}."
