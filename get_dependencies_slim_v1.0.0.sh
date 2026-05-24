#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${ROOT_DIR}/lib"

mkdir -p "${LIB_DIR}"
cd "${LIB_DIR}" || exit 1

OK_ITEMS=()
FAILED_ITEMS=()

mark_ok() {
    OK_ITEMS+=("$1")
    echo "[OK] $1"
}

mark_fail() {
    FAILED_ITEMS+=("$1 -- $2")
    echo "[FAILED] $1 -- $2" >&2
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

require_cmds() {
    local missing=()
    local cmd

    for cmd in "$@"; do
        if ! have_cmd "${cmd}"; then
            missing+=("${cmd}")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        printf '%s\n' "${missing[@]}"
        return 1
    fi

    return 0
}

sed_in_place() {
    local expression="$1"
    local file="$2"

    if sed --version >/dev/null 2>&1; then
        sed -i "${expression}" "${file}"
    else
        sed -i '' "${expression}" "${file}"
    fi
}

verify_file() {
    local name="$1"
    local file="$2"

    if [ -f "${file}" ]; then
        mark_ok "${name}"
        return 0
    fi

    mark_fail "${name}" "expected file missing: lib/${file}"
    return 1
}

download_tar_gz() {
    local name="$1"
    local dir="$2"
    local url="$3"
    local archive="$4"
    local extracted="$5"
    local verify="$6"
    local missing

    if [ -f "${dir}/${verify}" ]; then
        mark_ok "${name}"
        return 0
    fi

    missing="$(require_cmds curl tar || true)"
    if [ -n "${missing}" ]; then
        mark_fail "${name}" "missing required command(s): ${missing//$'\n'/, }"
        return 1
    fi

    rm -rf "${dir}"
    mkdir -p "${dir}"
    (
        set -e
        cd "${dir}"
        curl -fL -o "${archive}" "${url}"
        tar -xzf "${archive}"
        mv "${extracted}"/* .
    )

    verify_file "${name}" "${dir}/${verify}"
}

download_zip() {
    local name="$1"
    local dir="$2"
    local url="$3"
    local archive="$4"
    local extracted="$5"
    local verify="$6"
    local missing

    if [ -f "${dir}/${verify}" ]; then
        mark_ok "${name}"
        return 0
    fi

    missing="$(require_cmds curl unzip || true)"
    if [ -n "${missing}" ]; then
        mark_fail "${name}" "missing required command(s): ${missing//$'\n'/, }"
        return 1
    fi

    rm -rf "${dir}"
    mkdir -p "${dir}"
    (
        set -e
        cd "${dir}"
        curl -fL -o "${archive}" "${url}"
        unzip -q "${archive}"
        mv "${extracted}"/* .
    )

    verify_file "${name}" "${dir}/${verify}"
}

clone_repo() {
    local name="$1"
    local dir="$2"
    local url="$3"
    local verify="$4"
    local missing

    if [ -f "${dir}/${verify}" ] || [ -d "${dir}/${verify}" ]; then
        mark_ok "${name}"
        return 0
    fi

    missing="$(require_cmds git || true)"
    if [ -n "${missing}" ]; then
        mark_fail "${name}" "missing required command(s): ${missing//$'\n'/, }"
        return 1
    fi

    rm -rf "${dir}"
    git clone "${url}" "${dir}"

    if [ -f "${dir}/${verify}" ] || [ -d "${dir}/${verify}" ]; then
        mark_ok "${name}"
    else
        mark_fail "${name}" "expected file missing after clone: lib/${dir}/${verify}"
    fi
}

prepare_singlem_db_dir() {
    mkdir -p singleM/db

    if find singleM/db -maxdepth 1 \( -name "*.smpkg" -o -name "*.smpkg.zb" \) | grep -q .; then
        mark_ok "SingleM database directory"
    else
        mark_ok "SingleM database directory prepared; database will be downloaded by start_slim.sh after image build"
    fi
}

prepare_kraken2_db_dir() {
    mkdir -p kraken2/db

    if find kraken2/db -mindepth 2 -maxdepth 2 -name "hash.k2d" | grep -q .; then
        mark_ok "Kraken2 database directory"
    else
        mark_ok "Kraken2 database directory prepared; run ./download_kraken2_db.sh pluspf_16 before using the Kraken2-Bracken module"
    fi
}

prepare_motus_db_dir() {
    mkdir -p mOTUs/db

    if [ -d "mOTUs/db/db_mOTU" ] && { [ ! -r "mOTUs/db/db_mOTU" ] || [ ! -x "mOTUs/db/db_mOTU" ]; }; then
        mark_ok "mOTUs database directory present, but permissions need repair; run ./download_motus_db.sh or ./start_slim_v1.0.0.sh after image build"
    elif [ -d "mOTUs/db/db_mOTU" ] && find "mOTUs/db/db_mOTU" -type f -name "*.bwt" 2>/dev/null | grep -q .; then
        mark_ok "mOTUs database directory"
    else
        mark_ok "mOTUs database directory prepared; database will be downloaded by start_slim.sh after image build"
    fi
}

install_miniforge_installer() {
    local name="Miniforge installer"
    local missing

    if [ -f "miniforge3/Miniforge3-Linux-x86_64.sh" ] && [ -f "miniforge3/Miniforge3-Linux-aarch64.sh" ]; then
        mark_ok "${name}"
        return 0
    fi

    missing="$(require_cmds curl || true)"
    if [ -n "${missing}" ]; then
        mark_fail "${name}" "missing required command(s): ${missing//$'\n'/, }"
        return 1
    fi

    mkdir -p miniforge3

    for installer in Miniforge3-Linux-x86_64.sh Miniforge3-Linux-aarch64.sh; do
        if [ ! -f "miniforge3/${installer}" ]; then
            (
                set -e
                cd miniforge3
                curl -fLO "https://github.com/conda-forge/miniforge/releases/latest/download/${installer}"
            )
        fi
    done

    if [ -f "miniforge3/Miniforge3-Linux-x86_64.sh" ] && [ -f "miniforge3/Miniforge3-Linux-aarch64.sh" ]; then
        mark_ok "${name}"
    else
        mark_fail "${name}" "expected x86_64 and aarch64 installers missing under lib/miniforge3"
    fi
}

prepare_casper() {
    local name="Casper"
    local missing

    if [ -f "casper/casper_v0.8.2/Makefile" ]; then
        mark_ok "${name}"
        return 0
    fi

    missing="$(require_cmds curl tar || true)"
    if [ -n "${missing}" ]; then
        mark_fail "${name}" "missing required command(s): ${missing//$'\n'/, }"
        return 1
    fi

    mkdir -p casper
    (
        set -e
        cd casper
        if [ -f casper_v0.8.2.tar.xz ]; then
            tar -xf casper_v0.8.2.tar.xz
        else
            if ! curl -fL -o casper_v0.8.2.tar.xz https://raw.githubusercontent.com/trtcrd/SLIM/master/lib/casper/casper_v0.8.2.tar.xz; then
                rm -f casper_v0.8.2.tar.xz
            fi
            if [ -f casper_v0.8.2.tar.xz ]; then
                tar -xf casper_v0.8.2.tar.xz
            else
                curl -fL -o casper_v0.8.2.tar.gz http://best.snu.ac.kr/casper/program/casper_v0.8.2.tar.gz
                tar -xzf casper_v0.8.2.tar.gz
            fi
        fi
    )

    verify_file "${name}" "casper/casper_v0.8.2/Makefile"
}

prepare_msi() {
    local name="msi"
    local missing

    if [ -f "msi/scripts/msi_install.sh" ] && [ -d "msi/fastq_utils" ] && [ -d "msi/seqtk" ]; then
        mark_ok "${name}"
        return 0
    fi

    missing="$(require_cmds git sed || true)"
    if [ -n "${missing}" ]; then
        mark_fail "${name}" "missing required command(s): ${missing//$'\n'/, }"
        return 1
    fi

    rm -rf msi
    git clone https://github.com/adriantich/msi.git msi
    (
        set -e
        cd msi
        git clone https://github.com/adriantich/fastq_utils.git
        sed_in_place 's/git clone/\# git clone/g' scripts/msi_install.sh
        sed_in_place 's#pushd fastq_utils#pushd "$PATH2SCRIPT/../fastq_utils"#g' scripts/msi_install.sh
        sed_in_place 's#rm -rf fastq_utils tmp.tar.gz#rm -f tmp.tar.gz#g' scripts/msi_install.sh
        sed_in_place 's/ nmembers / \$nmembers /g' scripts/msi_clustr_add_size.pl
        sed_in_place 's/^ALL_TOOLS=.*/ALL_TOOLS="fastq_utils fastqc cutadapt isONclust minimap2 racon cd-hit R_packages msi"/g' scripts/msi_install.sh
        sed_in_place 's/^ALL_SOFT=.*/ALL_SOFT="$ALL_TOOLS"/g' scripts/msi_install.sh
        rm -f scripts/msi_tidyup_results scripts/msi_tidyup_table scripts/msi_incremental.sh scripts/msi_res2*
        rm -f scripts/msi_cluster2reads scripts/msi_clustr2map.pl scripts/msi_display_report
        rm -rf template tests
        cat > README.md <<'EOF'
# MSI for SLIM

This bundled MSI copy is trimmed for SLIM. It keeps the read filtering,
clustering, polishing, primer trimming, centroid FASTA export, and run
statistics steps used by the SLIM MSI module.

SLIM does not use MSI database download or downstream sequence labelling
features, so those optional upstream components are intentionally omitted
from this bundled copy.
EOF
        git clone https://github.com/lh3/seqtk.git
    )

    if [ -f "msi/scripts/msi_install.sh" ] && [ -d "msi/fastq_utils" ] && [ -d "msi/seqtk" ]; then
        mark_ok "${name}"
    else
        mark_fail "${name}" "expected MSI files missing after clone"
    fi
}

prepare_ashure() {
    local name="ASHURE"
    local missing

    if [ -f "ASHURE/src/ashure.py" ] && [ -d "ASHURE/spoa" ]; then
        mark_ok "${name}"
        return 0
    fi

    missing="$(require_cmds curl tar || true)"
    if [ -n "${missing}" ]; then
        mark_fail "${name}" "missing required command(s): ${missing//$'\n'/, }"
        return 1
    fi

    rm -rf ASHURE
    mkdir -p ASHURE
    (
        set -e
        cd ASHURE
        curl -fL -o v1.0.0.tar.gz https://github.com/BBaloglu/ASHURE/archive/refs/tags/v1.0.0.tar.gz
        tar -xzf v1.0.0.tar.gz
        mv ASHURE-1.0.0/* .
        curl -fL -o spoa-4.1.0.tar.gz https://github.com/rvaser/spoa/archive/refs/tags/4.1.0.tar.gz
        tar -xzf spoa-4.1.0.tar.gz
        mv spoa-4.1.0 spoa
    )

    if [ -f "ASHURE/src/ashure.py" ] && [ -d "ASHURE/spoa" ]; then
        mark_ok "${name}"
    else
        mark_fail "${name}" "expected ASHURE files missing after download"
    fi
}

download_tar_gz \
    "jQuery Autocomplete" \
    "jquery-autocomplete" \
    "https://github.com/devbridge/jQuery-Autocomplete/archive/v1.4.7.tar.gz" \
    "v1.4.7.tar.gz" \
    "jQuery-Autocomplete-1.4.7" \
    "dist/jquery.autocomplete.js"

download_tar_gz \
    "PapaParse" \
    "papa" \
    "https://github.com/mholt/PapaParse/archive/4.4.0.tar.gz" \
    "4.4.0.tar.gz" \
    "PapaParse-4.4.0" \
    "papaparse.js"

download_zip \
    "DTD" \
    "DTD" \
    "https://github.com/yoann-dufresne/DoubleTagDemultiplexer/archive/f687329ac846193605af97ef2b3f65d1bf5bce04.zip" \
    "f687329ac846193605af97ef2b3f65d1bf5bce04.zip" \
    "DoubleTagDemultiplexer-f687329ac846193605af97ef2b3f65d1bf5bce04" \
    "edit.cpp"

download_tar_gz \
    "VSEARCH" \
    "vsearch" \
    "https://github.com/torognes/vsearch/archive/v2.31.0.tar.gz" \
    "v2.31.0.tar.gz" \
    "vsearch-2.31.0" \
    "src/vsearch.cc"

prepare_casper

download_tar_gz \
    "SWARM3" \
    "swarm3" \
    "https://github.com/torognes/swarm/archive/v3.1.6.tar.gz" \
    "v3.1.6.tar.gz" \
    "swarm-3.1.6" \
    "src/Makefile"

clone_repo \
    "lulu" \
    "lulu" \
    "https://github.com/tobiasgf/lulu" \
    "DESCRIPTION"

download_tar_gz \
    "DADA2" \
    "dada2" \
    "https://github.com/benjjneb/dada2/archive/refs/tags/v1.26.tar.gz" \
    "v1.26.tar.gz" \
    "dada2-1.26" \
    "DESCRIPTION"

download_tar_gz \
    "DECIPHER" \
    "DECIPHER" \
    "https://www.bioconductor.org/packages/3.11/bioc/src/contrib/Archive/DECIPHER/DECIPHER_2.16.0.tar.gz" \
    "DECIPHER_2.16.0.tar.gz" \
    "DECIPHER" \
    "DESCRIPTION"

prepare_msi
prepare_ashure
install_miniforge_installer
prepare_singlem_db_dir
prepare_kraken2_db_dir
prepare_motus_db_dir

echo
echo "========== Dependency summary =========="
echo
echo "Ready:"
if [ "${#OK_ITEMS[@]}" -eq 0 ]; then
    echo "  none"
else
    for item in "${OK_ITEMS[@]}"; do
        echo "  - ${item}"
    done
fi

echo
echo "Not ready:"
if [ "${#FAILED_ITEMS[@]}" -eq 0 ]; then
    echo "  none"
else
    for item in "${FAILED_ITEMS[@]}"; do
        echo "  - ${item}"
    done
fi

echo
if [ "${#FAILED_ITEMS[@]}" -gt 0 ]; then
    echo "SLIM is NOT ready to build. Install/fix the items above and rerun this script."
    echo "Common Ubuntu/Debian host tools: sudo apt-get install -y curl unzip tar git sed"
    exit 1
fi

echo "SLIM dependencies are ready for building."
