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

patch_msi_for_slim() {
    local name="msi"
    local missing

    missing="$(require_cmds python3 || true)"
    if [ -n "${missing}" ]; then
        mark_fail "${name}" "missing required command(s): ${missing//$'\n'/, }"
        return 1
    fi

    if [ ! -f "msi/scripts/msi" ] || [ ! -f "msi/scripts/msi_install.sh" ]; then
        mark_fail "${name}" "expected MSI scripts missing before SLIM patch"
        return 1
    fi

    python3 - <<'PY'
from pathlib import Path
import re
import sys


def remove_function(text, name):
    return re.sub(rf"\nfunction {name} \{{\n.*?\n\}}\n", "\n", text, flags=re.S)


msi = Path("msi/scripts/msi")
text = msi.read_text()
text = text.replace('SKIP_BLAST="N"\n', "")
text = text.replace(
    "## minimum number of reads that a cluster must have to  pass the classification step (blastnig)\n",
    "## minimum number of reads that a cluster must have.\n",
)
text = text.replace("TAXONOMY_DATA_DIR=$MSI_DIR/db\n\n", "")
text = text.replace("#BLAST_CMD=blastn\nBLAST_CMD=metabinkit_blast\n", "")
text = re.sub(
    r"# case sensitive!!\n########\n## blast\n.*?MBK_VALID_PARAMS=\"[^\"]*\"\n\n",
    "",
    text,
    flags=re.S,
)
text = text.replace(
    'COMMANDS_NEEDED="$FASTQ_INFO_CMD $FASTQ_QC_CMD $BLAST_CMD $CLUSTER_ADD_SIZE"',
    'COMMANDS_NEEDED="$FASTQ_INFO_CMD $FASTQ_QC_CMD $CLUSTER_ADD_SIZE"',
)
text = re.sub(r"#taxdb\.tar\.gz.*?#######################################################################################", "#######################################################################################", text, flags=re.S)
for line in (
    " -b blast_database - path to the blast database\n",
    " -B blast_min_id   - value passed to blast (minimum % id - value between 0 and 100)\n",
    " -E blast_evalue   - value passed to blast (minimum e-value - value < 1)\n",
    " -S                 - stop execution before running blast\n",
):
    text = text.replace(line, "")
for function_name in ("get_blast_options", "get_metabinkit_options", "run_blast", "run_metabin"):
    text = remove_function(text, function_name)
text = text.replace(
    'while getopts "I:B:T:E:C:c:n:i:m:M:e:q:o:b:t:hdrSV"  Option; do',
    'while getopts "I:T:C:c:n:i:m:M:e:q:o:t:hdrV"  Option; do',
)
for line in (
    "\tB ) blast_min_id=$OPTARG;;\n",
    "\tE ) EVALUE=$OPTARG;;\n",
    "\tb ) blast_refdb=$OPTARG;;\n",
    '\tS ) SKIP_BLAST="Y";;\n',
):
    text = text.replace(line, "")
text = text.replace(
    "##\n## metabinkit parameters: mbk_paramname (short or long)\n## -paramname $mbk_paramname will be passed to mbk\n## blast_params: blast_paramname (short long)\n## \n",
    "##\n",
)
text = text.replace("## update some variables\nmbk_db=$TAXONOMY_DATA_DIR\n\n", "")
text = re.sub(
    r"## not mandatory\nif \[ \"\$SKIP_BLAST\" != \"Y\" \].*?\n\n\n",
    "",
    text,
    flags=re.S,
)
text = text.replace(
    "touch $CENTROIDS.blast $CENTROIDS.tsv $CENTROIDS-cdhit.clstr.sorted.tree",
    "touch $CENTROIDS $CENTROIDS-cdhit.clstr.sorted.tree",
)
text = re.sub(
    r"    #####################################################\n    ## blast\n.*?\n\}\n\n\n####################################################\n# Versions",
    "    pinfo \"Centroid generation complete\"\n}\n\n\n####################################################\n# Versions",
    text,
    flags=re.S,
)
text = text.replace(
    "out_file=$OUT_FOLDER/results.tsv.gz\nout_file2=$OUT_FOLDER/binres.tsv.gz\nout_file3=$OUT_FOLDER/bin.tsv.gz\nout_file_fasta=${out_file//.tsv.gz/.fasta.gz}",
    "out_file_fasta=$OUT_FOLDER/results.fasta.gz",
)
text = re.sub(
    r"\nif \[ \$SKIP_BLAST == \"Y\" \]; then\n.*?pinfo \"Generated \$out_file3\"\n",
    "\n",
    text,
    flags=re.S,
)
if re.search(r"metabinkit|run_blast|blastn|blast_refdb|TAXONOMY_DATA_DIR|SKIP_BLAST", text):
    sys.stderr.write("MSI runtime script still contains taxonomy/BLAST code after patch\n")
    sys.exit(1)
msi.write_text(text)

installer = Path("msi/scripts/msi_install.sh")
text = installer.read_text()
text = re.sub(r'^ALL_TOOLS=.*$', 'ALL_TOOLS="fastq_utils fastqc cutadapt isONclust minimap2 racon cd-hit R_packages msi"', text, flags=re.M)
text = re.sub(r'^ALL_SOFT=.*$', 'ALL_SOFT="$ALL_TOOLS"', text, flags=re.M)
text = re.sub(r"\nmetabinkit_VERSION=.*?\nmetabinkit_URL=.*?\n", "\n", text, flags=re.S)
text = re.sub(r"\nfunction install_blast_db_slow \{.*?\nfunction install_fastq_utils", "\nfunction install_fastq_utils", text, flags=re.S)
text = re.sub(r"\nfunction install_metabinkit \{.*?\n\}\n\n", "\n", text, flags=re.S)
text = re.sub(
    r'^minimap2_URL=.*$',
    'minimap2_URL="https://github.com/lh3/minimap2/archive/refs/tags/v$minimap2_VERSION.tar.gz"',
    text,
    flags=re.M,
)
native_minimap2 = r'''function install_minimap2 {
    pinfo "Installing minimap2..."
    pushd $TEMP_FOLDER
    rm -f tmp.tar.gz
    wget -c $minimap2_URL -O tmp.tar.gz
    tar -xzvf tmp.tar.gz --no-same-owner
    pushd minimap2-${minimap2_VERSION}
    case "$(uname -m)" in
        aarch64|arm64) make arm_neon=1 aarch64=1 ;;
        *) make ;;
    esac
    cp minimap2 $INSTALL_BIN
    if [ -f k8 ]; then cp k8 $INSTALL_BIN; fi
    if [ -f paftools.js ]; then
        cp paftools.js $INSTALL_BIN
    elif [ -f misc/paftools.js ]; then
        cp misc/paftools.js $INSTALL_BIN
    fi
    popd
    rm -rf minimap2-${minimap2_VERSION} tmp.tar.gz
    popd
    pinfo "Installing minimap2...done."
}
'''
text = re.sub(r"function install_minimap2 \{.*?\n\}\n\nfunction install_racon", native_minimap2 + "\nfunction install_racon", text, flags=re.S)
text = text.replace("    git clone https://github.com/adriantich/fastq_utils.git", "    # git clone https://github.com/adriantich/fastq_utils.git")
text = text.replace("    pushd fastq_utils", '    pushd "$PATH2SCRIPT/../fastq_utils"')
text = text.replace("    rm -rf fastq_utils tmp.tar.gz", "    rm -f tmp.tar.gz")
text = text.replace("    #git clone https://github.com/ksahlin/isONclust.git", "    ## git clone https://github.com/ksahlin/isONclust.git")
needle = "    pushd $PATH2SCRIPT/..\n"
guard = """    rm -f \\
        $INSTALL_BIN/msi \\
        $INSTALL_BIN/msi_incremental.sh \\
        $INSTALL_BIN/msi_res2taxatable \\
        $INSTALL_BIN/msi_tidyup_results \\
        $INSTALL_BIN/msi_tidyup_table
"""
check = """    if grep -Eq "metabinkit|run_blast|blastn|blast_refdb|TAXONOMY_DATA_DIR|SKIP_BLAST" $INSTALL_BIN/msi; then
        echo "ERROR: Installed MSI still contains taxonomy/BLAST code." >&2
        exit 1
    fi
"""
if "$INSTALL_BIN/msi_incremental.sh" not in text:
    text = text.replace(needle, needle + guard, 1)
if "Installed MSI still contains taxonomy/BLAST code" not in text:
    text = text.replace("    cp scripts/* $INSTALL_BIN\n", "    cp scripts/* $INSTALL_BIN\n" + check, 1)
text = re.sub(
    r"if \[ -e \$MSI_DIR/metabinkit_env\.sh \]; then\n\s+source \$MSI_DIR/metabinkit_env\.sh\nfi\n",
    "",
    text,
)
text = re.sub(r"\s*conda install -n \$envir_name -c bioconda  -c conda-forge metabinkit=\$metabinkit_VERSION -y\n", "\n", text)
if re.search(r"^ALL_.*(metabinkit|blast_db)|function install_metabinkit|metabinkit_VERSION|metabinkit_URL", text, flags=re.M):
    sys.stderr.write("MSI installer still installs taxonomy/BLAST components after patch\n")
    sys.exit(1)
installer.write_text(text)
PY

    if [ "$?" -ne 0 ]; then
        mark_fail "${name}" "failed to apply SLIM MSI taxonomy/BLAST patch"
        return 1
    fi

    if [ -f "msi/scripts/msi_clustr_add_size.pl" ]; then
        sed_in_place 's/ nmembers / \$nmembers /g' msi/scripts/msi_clustr_add_size.pl
    fi

    rm -f msi/scripts/msi_tidyup_results msi/scripts/msi_tidyup_table msi/scripts/msi_incremental.sh msi/scripts/msi_res2*
    rm -f msi/scripts/msi_cluster2reads msi/scripts/msi_clustr2map.pl msi/scripts/msi_display_report
    rm -rf msi/template msi/tests
    cat > msi/README.md <<'EOF'
# MSI for SLIM

This bundled MSI copy is trimmed for SLIM. It keeps the read filtering,
clustering, polishing, primer trimming, centroid FASTA export, and run
statistics steps used by the SLIM MSI module.

SLIM does not use MSI database download or downstream sequence labelling
features, so those optional upstream components are intentionally omitted
from this bundled copy.
EOF

    if grep -Eq "metabinkit|run_blast|blastn|blast_refdb|TAXONOMY_DATA_DIR|SKIP_BLAST" msi/scripts/msi; then
        mark_fail "${name}" "MSI runtime script still contains taxonomy/BLAST code after SLIM patch"
        return 1
    fi
}

prepare_msi() {
    local name="msi"
    local missing

    if [ -f "msi/scripts/msi_install.sh" ] && [ -d "msi/fastq_utils" ] && [ -d "msi/seqtk" ]; then
        if patch_msi_for_slim; then
            mark_ok "${name}"
            return 0
        fi
        return 1
    fi

    missing="$(require_cmds git sed python3 || true)"
    if [ -n "${missing}" ]; then
        mark_fail "${name}" "missing required command(s): ${missing//$'\n'/, }"
        return 1
    fi

    rm -rf msi
    if ! git clone https://github.com/adriantich/msi.git msi; then
        mark_fail "${name}" "failed to clone upstream MSI"
        return 1
    fi
    if ! (
        set -e
        cd msi
        git clone https://github.com/adriantich/fastq_utils.git
        git clone https://github.com/lh3/seqtk.git
    ); then
        mark_fail "${name}" "failed to clone MSI helper repositories"
        return 1
    fi

    if ! patch_msi_for_slim; then
        return 1
    fi

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
