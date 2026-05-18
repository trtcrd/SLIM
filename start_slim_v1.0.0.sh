#!/usr/bin/env bash

set -u

IMAGE_NAME="slim"
CONTAINER_NAME="slim"
DEFAULT_PORT="8080:80"
MAIL_ENV_FILE="slim_mail.env"

Help()
{
    echo "start_slim.sh destroys the current running SLIM webserver and replaces it with a new one."
    echo
    echo "Syntax: start_slim.sh [-h] [-d] [-P port]"
    echo "options:"
    echo "-h --help       Print this help."
    echo "-d --docker     Use docker instead of podman."
    echo "-P --port       <host:container> port mapping. Default: 8080:80"
    echo
}

engine="podman"
port="${DEFAULT_PORT}"

while getopts "hdP:" flag
do
    case "${flag}" in
        h) Help; exit 0 ;;
        d) engine="docker" ;;
        P) port="${OPTARG}" ;;
        \?) Help; exit 1 ;;
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

ensure_kraken2_db_dir()
{
    KRAKEN2_DB_HOST="$(pwd)/lib/kraken2/db"
    mkdir -p "${KRAKEN2_DB_HOST}"
    export KRAKEN2_DB_HOST

    if find "${KRAKEN2_DB_HOST}" -mindepth 2 -maxdepth 2 -name "hash.k2d" | grep -q .; then
        echo "Kraken2 database directory: ${KRAKEN2_DB_HOST}"
    else
        echo "No Kraken2 database found in ${KRAKEN2_DB_HOST}"
        echo "Kraken2-Bracken will be available after manually downloading a database, e.g.:"
        echo "  ./download_kraken2_db.sh pluspf_16"
    fi
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
if [ "${engine}" = "podman" ]; then
    if ! "${engine}" build --jobs 4 -t "${IMAGE_NAME}" .; then
        echo "Error: SLIM image build failed. Database download and container start were skipped."
        exit 1
    fi
else
    if ! DOCKER_BUILDKIT=1 "${engine}" build --progress=plain -t "${IMAGE_NAME}" .; then
        echo "Error: SLIM image build failed. Database download and container start were skipped."
        exit 1
    fi
fi

ensure_singlem_db "${engine}" "${IMAGE_NAME}"
ensure_kraken2_db_dir
build_mail_env_args

echo "Starting SLIM."
"${engine}" run \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    -p "${port}" \
    -v "${SINGLEM_DB_HOST}:/app/lib/singleM/db:ro" \
    -v "${KRAKEN2_DB_HOST}:/app/lib/kraken2/db:ro" \
    -e "SINGLEM_METAPACKAGE_PATH=${SINGLEM_METAPACKAGE_CONTAINER}" \
    -e "KRAKEN2_DB_ROOT=/app/lib/kraken2/db" \
    "${MAIL_ENV_ARGS[@]}" \
    -d "${IMAGE_NAME}"

echo "SLIM is running at http://localhost:${port%%:*}"
