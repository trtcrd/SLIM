#!/usr/bin/env bash

set -u

IMAGE_NAME="slim"
CONTAINER_NAME="slim"
DEFAULT_PORT="8080:80"
MAIL_ENV_FILE="slim_mail.env"
SCRIPT_START_TIME="$(date +%s)"

Help()
{
    echo "start_slim.sh destroys the current running SLIM webserver and replaces it with a new one."
    echo
    echo "Syntax: start_slim.sh [-h] [-d] [-P port] [-S] [-K kraken2_db]"
    echo "options:"
    echo "-h --help                 Print this help."
    echo "-d --docker               Use docker instead of podman."
    echo "-P --port                 <host:container> port mapping. Default: 8080:80"
    echo "-S --shotgun-databases    Enable shotgun modules and download/mount Kraken2, mOTUs, and SingleM databases."
    echo "-K --kraken-db            Kraken2 database to download when -S is used. Default: pluspf_16"
    echo
}

format_duration()
{
    local total_seconds="$1"
    local hours
    local minutes
    local seconds

    hours=$((total_seconds / 3600))
    minutes=$(((total_seconds % 3600) / 60))
    seconds=$((total_seconds % 60))

    if [ "${hours}" -gt 0 ]; then
        printf "%dh %02dm %02ds" "${hours}" "${minutes}" "${seconds}"
    elif [ "${minutes}" -gt 0 ]; then
        printf "%dm %02ds" "${minutes}" "${seconds}"
    else
        printf "%ds" "${seconds}"
    fi
}

engine="podman"
port="${DEFAULT_PORT}"
enable_shotgun_databases="no"
kraken2_database="pluspf_16"

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            Help
            exit 0
            ;;
        -d|--docker)
            engine="docker"
            shift
            ;;
        -P|--port)
            if [ "$#" -lt 2 ]; then
                echo "Error: -P/--port requires a <host:container> value."
                Help
                exit 1
            fi
            port="$2"
            shift 2
            ;;
        --port=*)
            port="${1#*=}"
            shift
            ;;
        -P*)
            port="${1#-P}"
            shift
            ;;
        -S|--shotgun-databases|--with-shotgun-databases)
            enable_shotgun_databases="yes"
            shift
            ;;
        -K|--kraken-db)
            if [ "$#" -lt 2 ]; then
                echo "Error: -K/--kraken-db requires a database name."
                Help
                exit 1
            fi
            kraken2_database="$2"
            shift 2
            ;;
        --kraken-db=*)
            kraken2_database="${1#*=}"
            shift
            ;;
        -K*)
            kraken2_database="${1#-K}"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            Help
            exit 1
            ;;
    esac
done

if ! command -v "${engine}" >/dev/null 2>&1; then
    echo "Error: ${engine} is not installed or not in PATH."
    exit 1
fi

if [[ "${port}" != *":"* ]]; then
    echo "Error: port option must follow the syntax <host:container>, e.g. 8080:80"
    exit 1
fi

echo "Running with ${engine}"
echo "Using port ${port}"
if [ "${enable_shotgun_databases}" = "yes" ]; then
    echo "Shotgun databases/modules: enabled"
    echo "Kraken2 database: ${kraken2_database}"
else
    echo "Shotgun databases/modules: disabled"
fi

is_slim_container()
{
    local image="$1"
    local name="$2"

    if [ "${name}" = "${CONTAINER_NAME}" ] || \
       [ "${image}" = "${IMAGE_NAME}" ] || \
       [ "${image}" = "${IMAGE_NAME}:latest" ] || \
       [ "${image}" = "localhost/${IMAGE_NAME}:latest" ]; then
        return 0
    fi

    return 1
}

stop_existing_slim_containers()
{
    local engine="$1"
    local found_running="N"
    local answer
    local id
    local image
    local name

    while IFS='|' read -r id image name; do
        if [ -n "${id}" ] && is_slim_container "${image}" "${name}"; then
            found_running="Y"
            echo "Found running SLIM container: ${id} (${name}, image: ${image})"
        fi
    done < <("${engine}" ps --format "{{.ID}}|{{.Image}}|{{.Names}}")

    if [ "${found_running}" = "Y" ]; then
        echo "Do you want to stop and replace running SLIM container(s)? [y/N]"
        read -r answer

        if [ "${answer}" != "y" ]; then
            exit 0
        fi

        while IFS='|' read -r id image name; do
            if [ -n "${id}" ] && is_slim_container "${image}" "${name}"; then
                "${engine}" stop "${id}"
            fi
        done < <("${engine}" ps --format "{{.ID}}|{{.Image}}|{{.Names}}")
    else
        echo "No running SLIM container found."
    fi

    while IFS='|' read -r id image name; do
        if [ -n "${id}" ] && is_slim_container "${image}" "${name}"; then
            echo "Removing previous SLIM container: ${id} (${name})"
            "${engine}" rm -v "${id}"
        fi
    done < <("${engine}" ps -a --format "{{.ID}}|{{.Image}}|{{.Names}}")
}

cleanup_old_containers_and_images()
{
    local engine="$1"
    local id

    echo "Removing stopped/created/paused containers."

    if [ "${engine}" = "podman" ]; then
        while read -r id; do
            if [ -n "${id}" ]; then
                "${engine}" rm -v "${id}"
            fi
        done < <("${engine}" ps --filter status=paused --filter status=exited --filter status=created -aq)
    else
        while read -r id; do
            if [ -n "${id}" ]; then
                "${engine}" rm -v "${id}"
            fi
        done < <("${engine}" ps --filter status=dead --filter status=exited --filter status=created -aq)
    fi

    echo "Removing dangling images."
    while read -r id; do
        if [ -n "${id}" ]; then
            "${engine}" rmi -f "${id}"
        fi
    done < <("${engine}" images -f "dangling=true" -q)
}

ensure_singlem_db()
{
    local engine="$1"
    local image="$2"
    local singlem_db_host
    local singlem_pkg

    singlem_db_host="$(pwd)/lib/singleM/db"
    mkdir -p "${singlem_db_host}"

    if find "${singlem_db_host}" -maxdepth 1 \( -name "*.smpkg" -o -name "*.smpkg.zb" \) | grep -q .; then
        echo "SingleM database already present in ${singlem_db_host}"
    else
        echo "Downloading SingleM database into ${singlem_db_host}"
        echo "This is large and may take a while."

        "${engine}" run --rm \
            -v "${singlem_db_host}:/db" \
            "${image}" \
            singlem data --output-directory /db
    fi

    singlem_pkg="$(find "${singlem_db_host}" -maxdepth 1 \( -name "*.smpkg" -o -name "*.smpkg.zb" \) | sort | tail -n 1)"

    if [ -z "${singlem_pkg}" ]; then
        echo "Error: SingleM database was not found after download."
        exit 1
    fi

    SINGLEM_DB_HOST="${singlem_db_host}"
    SINGLEM_METAPACKAGE_CONTAINER="/app/lib/singleM/db/$(basename "${singlem_pkg}")"

    export SINGLEM_DB_HOST
    export SINGLEM_METAPACKAGE_CONTAINER

    echo "SingleM metapackage: ${SINGLEM_METAPACKAGE_CONTAINER}"
}

ensure_kraken2_db()
{
    local choice="$1"

    KRAKEN2_DB_HOST="$(pwd)/lib/kraken2/db"
    mkdir -p "${KRAKEN2_DB_HOST}"
    export KRAKEN2_DB_HOST

    if [ -f "${KRAKEN2_DB_HOST}/${choice}/hash.k2d" ] && \
       [ -f "${KRAKEN2_DB_HOST}/${choice}/opts.k2d" ] && \
       [ -f "${KRAKEN2_DB_HOST}/${choice}/taxo.k2d" ]; then
        echo "Kraken2 database already present: ${KRAKEN2_DB_HOST}/${choice}"
    else
        echo "Downloading Kraken2 database '${choice}'."
        ./download_kraken2_db.sh "${choice}"
    fi

    if [ ! -f "${KRAKEN2_DB_HOST}/${choice}/hash.k2d" ] || \
       [ ! -f "${KRAKEN2_DB_HOST}/${choice}/opts.k2d" ] || \
       [ ! -f "${KRAKEN2_DB_HOST}/${choice}/taxo.k2d" ]; then
        echo "Error: Kraken2 database '${choice}' is missing or incomplete after download."
        exit 1
    fi

    echo "Kraken2 database directory: ${KRAKEN2_DB_HOST}"
}

ensure_motus_db()
{
    local engine="$1"
    local image="$2"
    local motus_db_host
    local host_uid
    local host_gid

    motus_db_ready()
    {
        local db_dir="$1"
        local bwt
        local prefix

        [ -d "${db_dir}" ] || return 1

        for bwt in "${db_dir}"/*.bwt; do
            [ -e "${bwt}" ] || continue
            prefix="${bwt%.bwt}"
            if [ -f "${prefix}.amb" ] && [ -f "${prefix}.ann" ] && [ -f "${prefix}.pac" ] && [ -f "${prefix}.sa" ]; then
                return 0
            fi
        done

        return 1
    }

    repair_existing_motus_db_permissions()
    {
        if [ ! -d "${motus_db_host}/db_mOTU" ]; then
            return
        fi

        if [ -r "${motus_db_host}/db_mOTU" ] && [ -x "${motus_db_host}/db_mOTU" ]; then
            return
        fi

        echo "Repairing mOTUs database permissions in ${motus_db_host}/db_mOTU"
        "${engine}" run --rm \
            -e HOST_UID="${host_uid}" \
            -e HOST_GID="${host_gid}" \
            -v "${motus_db_host}:/db" \
            "${image}" \
            bash -lc 'chown -R "${HOST_UID}:${HOST_GID}" /db/db_mOTU 2>/dev/null || true; chmod -R u+rwX,go+rX /db/db_mOTU 2>/dev/null || true'
    }

    motus_db_host="$(pwd)/lib/mOTUs/db"
    host_uid="$(id -u)"
    host_gid="$(id -g)"
    mkdir -p "${motus_db_host}"
    repair_existing_motus_db_permissions

    if motus_db_ready "${motus_db_host}/db_mOTU"; then
        echo "mOTUs database already present in ${motus_db_host}/db_mOTU"
    else
        if [ -d "${motus_db_host}/db_mOTU" ]; then
            echo "Removing incomplete mOTUs database in ${motus_db_host}/db_mOTU"
            rm -rf "${motus_db_host}/db_mOTU"
        fi

        echo "Downloading mOTUs marker-gene database into ${motus_db_host}"
        echo "This can take a while."

        "${engine}" run --rm \
            -e HOST_UID="${host_uid}" \
            -e HOST_GID="${host_gid}" \
            -v "${motus_db_host}:/db" \
            "${image}" \
            bash -lc '
                set -euo pipefail
                fix_db_permissions() {
                    if [ -d /db/db_mOTU ]; then
                        chown -R "${HOST_UID}:${HOST_GID}" /db/db_mOTU 2>/dev/null || true
                        chmod -R u+rwX,go+rX /db/db_mOTU 2>/dev/null || true
                    fi
                }

                db_ready() {
                    local bwt
                    local prefix
                    [ -d /db/db_mOTU ] || return 1
                    for bwt in /db/db_mOTU/*.bwt; do
                        [ -e "${bwt}" ] || continue
                        prefix="${bwt%.bwt}"
                        [ -f "${prefix}.amb" ] && [ -f "${prefix}.ann" ] && [ -f "${prefix}.pac" ] && [ -f "${prefix}.sa" ] && return 0
                    done
                    return 1
                }

                if db_ready; then
                    echo "mOTUs database already present in /db/db_mOTU"
                    fix_db_permissions
                    exit 0
                elif [ -d /db/db_mOTU ]; then
                    echo "Removing incomplete mOTUs database in /db/db_mOTU"
                    rm -rf /db/db_mOTU
                fi

                motus downloadMGDB

                db_dir="$(python - <<'"'"'PY'"'"'
import importlib.util
import pathlib
import sys

roots = []
spec = importlib.util.find_spec("motus")
if spec and spec.submodule_search_locations:
    roots.extend(pathlib.Path(p) for p in spec.submodule_search_locations)
elif spec and spec.origin:
    roots.append(pathlib.Path(spec.origin).resolve().parent)

roots.append(pathlib.Path("/root/miniforge3/envs/motus"))

candidates = []
for root in roots:
    if root.exists():
        candidates.extend(
            p for p in root.rglob("db_mOTU")
            if p.is_dir() and any(p.iterdir())
        )

if not candidates:
    sys.exit("Unable to locate db_mOTU after motus downloadMGDB")

print(candidates[0])
PY
)"

                rm -rf /db/db_mOTU
                cp -a "${db_dir}" /db/
                fix_db_permissions
            '
    fi

    if ! motus_db_ready "${motus_db_host}/db_mOTU"; then
        echo "Error: mOTUs database was not found after download."
        exit 1
    fi

    MOTUS_DB_HOST="${motus_db_host}"
    MOTUS_DB_CONTAINER="/app/lib/mOTUs/db/db_mOTU"

    export MOTUS_DB_HOST
    export MOTUS_DB_CONTAINER

    echo "mOTUs database: ${MOTUS_DB_CONTAINER}"
}

build_mail_env_args()
{
    MAIL_ENV_ARGS=()

    if [ -f "${MAIL_ENV_FILE}" ]; then
        MAIL_ENV_ARGS+=(--env-file "${MAIL_ENV_FILE}")
        echo "Mail configuration loaded from ${MAIL_ENV_FILE}"
        return
    fi

    for var_name in \
        SLIM_MAIL_USER \
        SLIM_MAIL_PASSWORD \
        SLIM_MAIL_FROM \
        SLIM_MAIL_HOST \
        SLIM_MAIL_PORT \
        SLIM_MAIL_SECURE \
        GMAIL_USER \
        GMAIL_APP_PASSWORD \
        GMAIL_PASS
    do
        if [ -n "${!var_name:-}" ]; then
            MAIL_ENV_ARGS+=(-e "${var_name}")
        fi
    done

    if [ "${#MAIL_ENV_ARGS[@]}" -gt 0 ]; then
        echo "Mail configuration loaded from shell environment."
    else
        echo "No mail configuration found. Email notifications will be disabled."
    fi
}

stop_existing_slim_containers "${engine}"
cleanup_old_containers_and_images "${engine}"

echo "Building SLIM image."
build_start_time="$(date +%s)"
if [ "${engine}" = "podman" ]; then
    if ! "${engine}" build --jobs 4 -t "${IMAGE_NAME}" .; then
        build_elapsed=$(( $(date +%s) - build_start_time ))
        echo "SLIM image build failed after $(format_duration "${build_elapsed}")."
        echo "Error: SLIM image build failed. Database download and container start were skipped."
        exit 1
    fi
else
    if ! DOCKER_BUILDKIT=1 "${engine}" build --progress=plain -t "${IMAGE_NAME}" .; then
        build_elapsed=$(( $(date +%s) - build_start_time ))
        echo "SLIM image build failed after $(format_duration "${build_elapsed}")."
        echo "Error: SLIM image build failed. Database download and container start were skipped."
        exit 1
    fi
fi
build_elapsed=$(( $(date +%s) - build_start_time ))
echo "SLIM image build finished in $(format_duration "${build_elapsed}")."

DATABASE_RUNTIME_ARGS=(-e "SLIM_ENABLE_SHOTGUN_DATABASES=0")
if [ "${enable_shotgun_databases}" = "yes" ]; then
    ensure_singlem_db "${engine}" "${IMAGE_NAME}"
    ensure_kraken2_db "${kraken2_database}"
    ensure_motus_db "${engine}" "${IMAGE_NAME}"

    DATABASE_RUNTIME_ARGS=(
        -v "${SINGLEM_DB_HOST}:/app/lib/singleM/db:ro"
        -v "${KRAKEN2_DB_HOST}:/app/lib/kraken2/db:ro"
        -v "${MOTUS_DB_HOST}:/app/lib/mOTUs/db:ro"
        -e "SINGLEM_METAPACKAGE_PATH=${SINGLEM_METAPACKAGE_CONTAINER}"
        -e "KRAKEN2_DB_ROOT=/app/lib/kraken2/db"
        -e "MOTUS_DB_PATH=${MOTUS_DB_CONTAINER}"
        -e "SLIM_ENABLE_SHOTGUN_DATABASES=1"
    )
else
    echo "Skipping shotgun database downloads and mounts."
    echo "Kraken2-Bracken, SingleM, mOTUs, and ancient-DNA modules will be hidden from the module list."
fi
build_mail_env_args

echo "Starting SLIM."
"${engine}" run \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    -p "${port}" \
    "${DATABASE_RUNTIME_ARGS[@]}" \
    "${MAIL_ENV_ARGS[@]}" \
    -d "${IMAGE_NAME}"

echo "SLIM is running at http://localhost:${port%%:*}"
script_elapsed=$(( $(date +%s) - SCRIPT_START_TIME ))
echo "start_slim finished in $(format_duration "${script_elapsed}")."
