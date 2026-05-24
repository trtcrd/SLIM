# How to Write a New Module II: ASHURE Concept and Installation

This page shows how the ASHURE module was added to SLIM. It focuses on the design and installation choices. The companion page, [ASHURE module scripts](/man/sections/How-to-write-a-new-module-IIb.md), covers the client, server, and bash wrappers.

## Concept

ASHURE is a multi-step long-read amplicon pipeline. It can run from a configuration file, but SLIM should not require users to write that file manually. The module therefore exposes only the fields needed for a common run and lets the wrapper script generate the ASHURE configuration.

## User-Facing Design

### Inputs

* Input FASTQ files.
* Primer FASTA file.

### Parameters

* Minimum and maximum read length.
* Minimum cluster size.
* Cluster merge threshold.
* Number of sweep partitions.
* Sequence subsample size.
* Number of clustering iterations.

### Outputs

* Consensus sequences.
* Trimmed consensus sequences.
* Cluster-center sequences.

This keeps the interface small while still covering the major ASHURE controls exposed by the SLIM wrapper.

## Dependency Download

ASHURE and its supporting code are prepared by `get_dependencies_slim_v1.0.0.sh`. The dependency script should:

1. Create or refresh `lib/ASHURE`.
2. Download the pinned ASHURE release.
3. Download/build supporting code such as SPOA when needed.
4. Leave the dependency folder in a state the Dockerfile can copy directly.

Use pinned versions whenever possible. That makes image builds more reproducible and helps avoid surprise breakage when upstream projects change.

## Container Installation

The Dockerfile then copies `lib/ASHURE` into the image and installs the runtime environment. Current SLIM builds use Miniforge/mamba rather than classic Anaconda/conda wherever possible because solving environments is faster and avoids Anaconda licensing constraints.

The ASHURE installation pattern is:

1. Create a dedicated environment.
2. Install compiled dependencies.
3. Install Python dependencies.
4. Build bundled tools such as SPOA.
5. Run small help/version commands to fail early if the installation is broken.

The server module should activate or call this environment only when the ASHURE module runs.

## Verifying the Build

Build/start the container:

```bash
bash start_slim_v1.0.0.sh
```

Then enter the running container:

```bash
podman exec -it slim /bin/bash
```

Use `docker exec -it slim /bin/bash` if SLIM was started with `--docker`.

Inside the container, verify that ASHURE can print its help:

```bash
source activate ashure
python3 /app/lib/ASHURE/src/ashure.py -h
```

Also test the specific ASHURE subcommands used by the wrapper. A dependency should be fixed in the Dockerfile or dependency script before the module is considered ready.

## Practical Advice

* Keep the web interface simpler than the command-line tool.
* Put complex command construction in a bash or Python wrapper when it improves readability.
* Write every command to the SLIM log before running it.
* Prefer small test datasets during development.
* Document pinned versions and why unusual dependency workarounds are needed.
