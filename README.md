# SLIM

<p align="center">
  <img src="https://github.com/trtcrd/SLIM/blob/master/www/imgs/slim_logo.svg" alt="SLIM logo" width="250px"/>
</p>

SLIM is a browser-based workflow builder for DNA metabarcoding and selected shotgun-metagenomics analyses. It wraps command-line bioinformatics tools in a graphical web interface so users can upload files, chain modules, run analyses, and download results without writing shell scripts.

The current repository is [trtcrd/SLIM](https://github.com/trtcrd/SLIM). The full manual starts at [man/README.md](man/README.md).

## What SLIM Does

SLIM provides:

* a Node.js web interface for configuring pipelines;
* a scheduler that runs modules inside a container;
* modules for demultiplexing or grouping samples manually, paired-end read merging, chimera removal, ASV/OTU inference, taxonomic assignment, filtering, and post-processing;
* long-read amplicon modules for Nanopore/PacBio workflows;
* optional shotgun metagenomics modules for taxonomic profiling using Kraken2-Bracken, mOTUs, and SingleM.

SLIM is maintained by [Adrià Antich](mailto:a.antich@ceab.csic.es) and [Tristan Cordier](mailto:tristan.cordier@gmail.com).

## Requirements

Install and start either [Podman](https://podman.io/docs/installation) or Docker before deploying SLIM. Podman is the default.

SLIM is a CPU-only container image. The dependency script downloads both Linux `x86_64` and Linux `aarch64` Miniforge installers, and the Dockerfile selects the matching installer at build time. Native builds are recommended on both x86_64 machines and ARM-based Macs running Linux ARM64 containers. Cross-building an x86_64 image on an ARM Mac may work through emulation, but it is expected to be much slower.

## Install

Download the latest stable archive:

```bash
sudo apt-get update
sudo apt-get install -y git curl
curl -OL https://github.com/trtcrd/SLIM/archive/v1.0.0.tar.gz
tar -xzvf v1.0.0.tar.gz
cd SLIM-1.0.0
```

Then fetch bundled dependencies and build/start the container:

```bash
bash get_dependencies_slim_v1.0.0.sh
bash start_slim_v1.0.0.sh
```

`get_dependencies_slim_v1.0.0.sh` downloads third-party source archives and prepares local dependency folders. `start_slim_v1.0.0.sh` builds the image, stops/replaces any running SLIM container, removes dangling images, and starts the web server.

> Restarting SLIM replaces the current container. Files uploaded to the previous container and analysis results stored there are removed.

## Start Options

Show all options:

```bash
bash start_slim_v1.0.0.sh --help
```

Common options:

```bash
# Use Docker instead of Podman
bash start_slim_v1.0.0.sh --docker

# Expose SLIM on another host port
bash start_slim_v1.0.0.sh --port 8081:80

# Enable shotgun modules and download/mount their databases
bash start_slim_v1.0.0.sh --shotgun-databases

# Choose a Kraken2 database when shotgun modules are enabled
bash start_slim_v1.0.0.sh --shotgun-databases --kraken-db viral
```

Available Kraken2 choices are `viral`, `standard_8`, `standard_16`, `pluspf_8`, and `pluspf_16`. The default is `pluspf_16`.

## Optional Email Notifications

Email notifications are disabled unless a local `slim_mail.env` file exists at the root of the SLIM folder. For Gmail, enable 2-Step Verification and create an app password, then add:

```text
SLIM_MAIL_USER=your.gmail.account@gmail.com
SLIM_MAIL_PASSWORD=your16digitapppassword
SLIM_MAIL_FROM=your.gmail.account@gmail.com
```

Do not commit `slim_mail.env`.

## Optional Shotgun Databases

Shotgun databases are large and are kept outside the Docker image. By default, SLIM starts without downloading or mounting Kraken2-Bracken, SingleM, or mOTUs databases, and those modules are hidden from the module list.

Start with `--shotgun-databases` to download/mount the databases and expose the modules:

```bash
bash start_slim_v1.0.0.sh --shotgun-databases
```

Manual download helpers are also available after the SLIM image exists:

```bash
./download_kraken2_db.sh pluspf_16
./download_motus_db.sh
```

Database locations:

* Kraken2: `lib/kraken2/db/`
* mOTUs: `lib/mOTUs/db/`
* SingleM: `lib/singleM/db/`

## Access the Web Interface

By default, SLIM listens on host port `8080`.

* Local machine: `http://localhost:8080/`
* Remote server: `http://<server-ip>:8080/`

After the first page load, SLIM adds a session token to the URL. If a gmail emailing service is configured, you will receive an email with a direct lonk to your job, otherwise please bookmark the tokenized URL to return to the same session while it remains available.

<p align="left">
  <img src="https://github.com/trtcrd/SLIM/blob/master/tutos/slim_webpage.png" alt="SLIM homepage" width="800px"/>
</p>

## Prepare Input Files

Typical metabarcoding inputs include:

* paired-end FASTQ files for each multiplexed sequencing library;
* a tag-to-sample CSV describing library, sample, forward tag, and reverse tag;
* a primer FASTA file;
* a reference FASTA database for taxonomic assignment;
* or already-demultiplexed FASTQ files for direct per-sample workflows.

Toy datasets:

* [Illumina example dataset](https://github.com/trtcrd/SLIM/blob/gh-pages/assets/tuto/exemple_tuto.zip)
* [Nanopore example dataset](https://github.com/trtcrd/SLIM/blob/gh-pages/assets/tuto/nanopore_tuto.zip)

### Tag-to-Sample CSV

The tag-to-sample CSV must contain at least `run`, `sample`, `forward`, and `reverse` columns. Sample names must be unique, including replicates sequenced in multiple libraries.

```csv
run,sample,forward,reverse
library_1,sample_1,forwardPrimer-A,reversePrimer-B
library_1,sample_2,forwardPrimer-B,reversePrimer-C
library_2,sample_3,forwardPrimer-A,reversePrimer-B
library_2,sample_4,forwardPrimer-B,reversePrimer-C
```

### Primer FASTA

Primer FASTA records must use unique identifiers. Primer sequences may contain IUPAC ambiguity codes.

```fasta
>forwardPrimer-A
ACCTGCCTAGCGTYG
>forwardPrimer-B
GAATGCCTAGCGTYG
>reversePrimer-B
GAATCTYCAAATCGG
>reversePrimer-C
ACTACTYCAAATCGG
```

### Reference FASTA for Taxonomic Assignment

Reference FASTA headers must contain a unique identifier, one space, and a semicolon-separated taxonomy path with the same number of ranks for every record.

```fasta
>AB353770 Eukaryota;Alveolata;Dinophyta;Dinophyceae;Dinophyceae_X;Dinophyceae_XX;Peridiniopsis;Peridiniopsis_kevei
ATGCTTGTCTCAAAGATTAAGCCATGCATGTCTCAGTATAAGCTTTTACATGGCGAAACTGCGAATGGCTCATTAAAACAG
>KC672520 Eukaryota;Opisthokonta;Fungi;Ascomycota;Pezizomycotina;Leotiomycetes;Leotiomycetes_X;Leotiomycetes_X_sp.
TACCTGGTTGATTCTGCCCCTATTCATATGCTTGTCTCAAAGATTAAGCCATGCATGTCTAAGTATAA
>AB284159 Eukaryota;Alveolata;Dinophyta;Dinophyceae;Dinophyceae_X;Dinophyceae_XX;Protoperidinium;Protoperidinium_bipes
TGATCCTGCCAGTAGTCATATGCTTGTCTCAAAGATTAAGCCATGCATGTCTCAGTATAAGCTTCAACATGGCAAGACTGTGAATGGC
```

Common sources include [SILVA](https://www.arb-silva.de/), [EUKREF](https://eukref.org/), [PR2](https://github.com/pr2database/pr2database), [UNITE](https://unite.ut.ee/repository.php), and [MIDORI](http://www.reference-midori.info/download.php#).

## Build a Pipeline

Use **Add a new module** to select modules and chain them in order. Each module consumes uploaded files or files created by earlier modules.

For a typical metabarcoding workflow:

1. Demultiplex libraries, unless each file already corresponds to one sample.
2. Merge paired-end reads.
3. Remove chimeras.
4. Infer ASVs or cluster OTUs.
5. Assign taxonomy.
6. Filter or post-process the ASV/OTU table.

For already-demultiplexed data, use [wildcard creator](man/sections/wildcard_creator.md) to create file groups that can pass through downstream modules.

The pipeline can be saved with **Save** and restored with **Load**. When a job starts, SLIM writes a `pipeline.conf` file recording the selected modules and parameters.

## Wildcards

SLIM uses wildcard patterns to pass groups of files between modules. For example:

```text
sample*_R1.fastq
sample*_R2.fastq
```

Wildcards are generated by modules such as the demultiplexer or `wildcard-creator`. Select suggested wildcards from the autocompletion list instead of typing new wildcard expressions manually.

## Shotgun Modules

The integrated shotgun profilers are:

* [Kraken2-Bracken](man/sections/Kraken2-Bracken.md): fast k-mer/minimizer classification followed by Bracken abundance estimation.
* [mOTUs](man/sections/mOTUs.md): marker-gene profiling for prokaryotic communities.
* [SingleM](man/sections/SingleM.md): single-copy-marker profiling, mainly for bacterial and archaeal shotgun metagenomes.

For general exploratory shotgun data, `kraken2-bracken` is usually the fastest first screen. For marker-gene-based microbial profiling, compare `mOTUs` and `SingleM`.

Experimental ancient-DNA modules are included in the codebase but are not exposed in the default module list.

### Choosing a shotgun profiler

| Feature | Kraken2-Bracken | mOTUs | singleM |
| --- | --- | --- | --- |
| Primary method | k-mer/minimizer matching against a whole-genome database. | Nucleotide mapping to universal marker genes. | Protein-space search against conserved single-copy marker genes. |
| Main output unit | Bracken-estimated read counts and relative abundance at one selected taxonomic rank. | Marker-gene-normalized mOTU abundance profiles. | Marker-gene OTU/profile outputs and relative-abundance summaries. |
| Database dependence | Very dependent on the chosen Kraken2 database. Reads without sufficient database evidence remain unclassified or are assigned conservatively higher in the taxonomy. | Less dependent on exact whole-genome matches, but still limited to marker genes represented in the mOTUs database. | Designed to detect microbial marker-gene lineages, including novel OTUs, but mainly for bacteria and archaea with the default metapackage. |
| Best used for | Fast broad screening, especially with PlusPF databases for bacteria, archaea, viruses, plasmids, human, protozoa, and fungi. | Prokaryotic species-level or mOTU-level profiling when marker-gene precision is preferred over broad whole-genome screening. | Bacterial/archaeal community profiling and microbial novelty estimates from conserved marker genes. |
| Important limitations | Results follow the database content. PlusPF does not include plants by default; use a custom database for other targets. Bracken requires database files built for the selected read length. | Requires enough marker-gene signal and can be memory intensive because mOTUs v4 maps with BWA against a large marker database. | Not intended as a broad eukaryotic, fungal, viral, or plasmid classifier with the default SLIM metapackage. |


## Results

When the job finishes, download icons appear next to module outputs. Uploaded, intermediate, and result files remain available in the session for a limited time.

Module statuses:

* `waiting`: the module is waiting for required input files;
* `running`: the module is executing;
* `warnings`: the module reported warnings but is still running;
* `aborted`: the module failed and the pipeline stopped;
* `ended`: the module finished successfully.

## Configure Parallelism

SLIM currently uses up to 8 CPU cores per module run. This value is set in `server/scheduler.js`:

```javascript
const CORES_BY_RUN = 8;
```

The number of concurrent jobs depends on available CPU cores and the scheduler (1-8 -> 1 job, 16 -> 2 jobs, etc.).

## Create a Module

To add a module, see:

* [How to write a module](man/sections/How-to-write-a-new-module.md)
* [ASHURE example: concept and installation](man/sections/How-to-write-a-new-module-IIa.md)
* [ASHURE example: module scripts](man/sections/How-to-write-a-new-module-IIb.md)

## Version History

### v1.1.0

- Updated version of most dependencies.
- Updated install scripts for better dependencies handling and for x86_64 and ARM64 container builds.
- Added a server status monitoring routine (a message will show up if the server is down/restarting).
- Restored optional email notifications through gmail app-password configuration and job labelling.
- Improved/fix wildcard-creation module.
- Nanopore-oriented modules: streamlined the installation of MSI, integrated a module based on isONclust3-minimap2-racon.
- PacBio-oriented modules: isONclust3.
- Added optional shotgun modules for Kraken2-Bracken, mOTUs, and SingleM.
- Fixed multiple interface and deployment issues.

### v1.0.0

- Moved to podman container by default (docker kept as an option)
- Added modules for processing nanopore amplicon data (CHOPPER, MSI, ASHURE, OPTICS)
- Added module to create wildcard grouping of files
- Added SWARM3 module
- Emailing service restored as an optional Gmail app-password configuration
- Documentation moved from the wiki to the tutos folder.
- Various interface bug fixes

### v0.6.2

Dockerfile: updated systeminformation and docker recipe

### v0.6.1

Dockerfile: updated to DADA2 v1.16 and DECIPHER v2.16.0, cleaned the docker recipe

### v0.6

BUGFIX: resolved issues with the order of module execution when DADA2 is used.
BUGFIX: resolved issues with the pipeline.conf file that did not included the checkbox and radio buttons.

### v0.5.3

DTD: added an option for trimming the primers at the end of the reads in (for fully overlapping pair-end reads) and a contig length filtering

### v0.5.2

DADA2 beta integration, small fix on IDATAXA

### v0.5.1

BUGFIX of the IDTAXA module, added wiki for the module

### v0.5

Integration of the IDTAXA module

### v0.4.1

Fixed the Dockerfile to fetch the latest R version and CASPER util.c file

### v0.4

Added timing checkpoints in the logs of the scheduler; Added the third-party software version infos in the email

### v0.3

Fixed LULU module and the otu table writing is now done by a python script

### v0.2

Updated the `get_dependencies` script.

### v0.1

First release, with third-parties versions handled within the `get_dependencies_slim.sh` script.