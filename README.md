
<p align="center">
  <img src="https://github.com/yoann-dufresne/SLIM/blob/master/www/imgs/slim_logo.svg" alt="SLIM logo" width="250px"/>
</p>

**What is it?**

SLIM is a web application that aims to facilitate the access to state-of-art bioinfirmatic tools to non-specialist and to command-line reluctant for the processing of raw amplicon sequencing data, i.e. DNA metabarcoding, from illumina paired-end or nanopore FASTQ to annotated ASV/OTU matrix.

SLIM is based on the node.js framework, and provide a Graphical User Interface (GUI) to interact with bioinformatic softwares. It simplifies the creation and deployment of a processing pipeline and is accessible within an internet browser over the internet. It is maintened by [Adrià Antich](mailto:a.antich@ceab.csic.es) and [Tristan Cordier](mailto:tristan.cordier@gmail.com).
The application is embedded in a [podman](https://podman.io/).

The full documentation is available [here](https://github.com/adriantich/SLIM/blob/master/man/README.md#tutorials).

# Install and deploy the web app

First of all, podman needs to be installed on the machine. You can find instructions here :
* [podman for Ubuntu](https://podman.io/docs/installation#ubuntu)
* [podman for Debian](https://podman.io/docs/installation#debian)
* [podman for macOS](https://podman.io/docs/installation#macos)

To install SLIM, get the last stable release [here](https://github.com/trtcrd/SLIM/archive/v1.0.0.tar.gz) or, using terminal :
```bash
sudo apt-get update && apt-get install git curl
curl -OL https://github.com/trtcrd/SLIM/archive/v1.0.0.tar.gz
tar -xzvf v1.0.0.tar.gz
cd SLIM-1.0.0
```

Email notifications are optional. To send messages with Gmail, enable 2-Step Verification on the Gmail account and create a Gmail app password. Then create a local file named `slim_mail.env` at the root of the SLIM folder:

```
SLIM_MAIL_USER=your.gmail.account@gmail.com
SLIM_MAIL_PASSWORD=your16digitapppassword
SLIM_MAIL_FROM=your.gmail.account@gmail.com
```

The `start_slim_v1.0.0.sh` script passes this file to the container at runtime. Do not commit `slim_mail.env`.

Kraken2/Bracken databases are optional and are kept outside the Docker image. The Kraken2-Bracken module uses PlusPF-16 by default, which adds protozoa and fungi to the standard archaea/bacteria/viral/plasmid/human database. To download it:

```bash
./download_kraken2_db.sh pluspf_16
```

Available choices are `viral`, `standard_8`, `standard_16`, `pluspf_8`, and `pluspf_16`. The database will be stored under `lib/kraken2/db/` and mounted into the SLIM container by `start_slim_v1.0.0.sh`. The Kraken2-Bracken module can trim adapters and low-quality bases with fastp before classification; this option is enabled by default for FASTQ input.

The SingleM module can also trim paired-end FASTQ files with fastp before profiling. This option is enabled by default and produces a small fastp reports archive.

The mOTUs module is another shotgun metagenomics profiler. Its marker-gene database is kept outside the Docker image and is downloaded by `start_slim_v1.0.0.sh` after the image is built and before the webserver is started. The standalone downloader also uses the `motus` executable inside the built SLIM image, so it is only useful after the image exists. To download it manually after a build:

```bash
./download_motus_db.sh
```

The database is stored under `lib/mOTUs/db/` and mounted into the container at runtime. The mOTUs module can also trim FASTQ files with fastp before profiling; this option is enabled by default.

Experimental ancient-DNA modules are also available. A practical end-to-end workflow is:

```text
kraken2-bracken
-> targeted-reference-builder
-> map-to-targeted-reference
-> metaDMG
```

This workflow uses Kraken2/Bracken taxids to download a small targeted RefSeq reference, maps reads with BWA, adds `MD:Z` tags with samtools, and estimates DNA damage with metaDMG-cpp.


As soon as podman is installed and running and the SLIM archive downloaded, it can be deployed by using the two scripts `get_dependencies_slim_v1.0.0.sh` and `start_slim_v1.0.0.sh`.
* `get_dependencies_slim_v1.0.0.sh` fetches all the bioinformatics tools needed from their respective repositories.
* `start_slim_v1.0.0.sh` builds the SLIM image, downloads missing external databases such as SingleM and mOTUs, mounts those databases into the container, and destroys the current running webserver to replace it with a new one. **/!\\** All the files previously uploaded and the results of analysis will be detroyed during the process.

```bash
bash get_dependencies_slim_v1.0.0.sh
bash start_slim_v1.0.0.sh
```

The server is configured to use up to 8 CPU cores per job. The amount of available cores will determine the amount of job that can be executed in parallel (1-8 -> 1 job, 16 -> 2 jobs, etc.). The number of cores is defined in the [scheduler.js](https://github.com/adriantich/SLIM/blob/master/server/scheduler.js) script in the line:
```javascript
const CORES_BY_RUN = 8;
```


# Accessing the webserver

The execution of the `start_slim_v1.0.0.sh` script deploys and start the webserver.
By default, the webserver is accessible on the 8080 port but can be modified using the -P option:
```
> bash start_slim_v1.0.0.sh -h
start_slim_v1.0.0.sh destroys the current running webserver to replace it with a new one.
/!\ All the files previously uploaded and the results of analysis will be detroyed during the process.

Syntax: start_slim_v1.0.0.sh [-h] [-p] [-P] [port]
options:
-h --help       Print this Help.

-d --docker     Use docker instead of podman

-P --port       <numeric:numeric> Specify the port that has to be opened for the container. 8080:80 by default
```


* To access it on a remote server from your machine, type the server IP address followed by ":8080" (for example `156.241.0.12:8080`) from an internet browser (prefer Firefox and Google Chrome).
* If SLIM is deployed on your own machine, type `localhost:8080/`

If the server is correctly set, you should see this:

<p align="left">
  <img src="https://github.com/trtcrd/SLIM/blob/master/tutos/slim_webpage.png" alt="SLIM homepage" width="800px"/>
</p>

# Prepare and upload your data

You may check by yourself the files and their required format:
- download an illimina [toy dataset](https://github.com/trtcrd/SLIM/blob/gh-pages/assets/tuto/exemple_tuto.zip).
- download an nanopore [toy dataset](https://github.com/trtcrd/SLIM/blob/gh-pages/assets/tuto/nanopore_tuto.zip).


The "file uploader" section allows you to upload all the required files. Usually it consists of:
- one (or multiple) pair(s) of FASTQ files corresponding to the multiplexed library(ies) (can be zipped)
- a CSV (Comma-separated values) file containing the correspondance between library, tagged-primers pairs and samples (the so-called tag-to-sample file, see below for an example)
- alternatively, a list of fastq files that each correspond to a sample (nanopore or illumina)
- a FASTA file containing the tagged primers sequences and name (see below for an example)
- a FASTA file containing sequence reference database (see below for an example)

**Example of tag-to-sample file:**
This file must contain at least the four four fields: run, sample, forward and reverse. "Run" corresponds to your illumina library identification; "sample" corresponds to the names of your samples in the library; "forward" and "reverse" corresponds to the names of your tagged primers.
**Samples names MUST be unique, even for replicates sequenced in multiples libraries**

```
run,sample,forward,reverse
library_1,sample_1,forwardPrimer-A,reversePrimer-B
library_1,sample_2,forwardPrimer-B,reversePrimer-C
library_2,sample_3,forwardPrimer-A,reversePrimer-B
library_2,sample_4,forwardPrimer-B,reversePrimer-C
```

**Example of primers FASTA file:**
It contains the names of your tagged primers and their sequences, in a conventional FASTA format. Each primer tag consists of 4 variables nucleotides at the 5' side, prior the template specific part.
Each primer must contains a specific identifier (by letters in this example). The primers sequences can include IUPAC nucleotide codes, they are taken into account.

```
>forwardPrimer-A
ACCTGCCTAGCGTYG
>forwardPrimer-B
GAATGCCTAGCGTYG
>reversePrimer-B
GAATCTYCAAATCGG
>reversePrimer-C
ACTACTYCAAATCGG
```

**Example of sequences reference database file**

This FASTA file contains reference sequences with unique identifier and taxonomic path in the header.
Such database can be downloaded for instance from [SILVA](https://www.arb-silva.de/) for both prokaryotes and eukaryotes (16S and 18S), [EUKREF](https://eukref.org/) or [PR2](https://github.com/pr2database/pr2database) for eukaryotes (18S), [UNITE](https://unite.ut.ee/repository.php) for fungi (ITS), [MIDORI](http://www.reference-midori.info/download.php#) for metazoan (COI).
Each header include a unique identifier (usually the accession),
a space ' ', and the taxonomic path separated by a semi-colon (without any space, please use "_" underscore).
**You should have the same amount of taxonomic rank for each reference sequences**

```
>AB353770 Eukaryota;Alveolata;Dinophyta;Dinophyceae;Dinophyceae_X;Dinophyceae_XX;Peridiniopsis;Peridiniopsis_kevei
ATGCTTGTCTCAAAGATTAAGCCATGCATGTCTCAGTATAAGCTTTTACATGGCGAAACTGCGAATGGCTCATTAAAACAGTTACAGTTTATTTGAA
GGTCATTTTCTACATGGATAACTGTGGTAATTCTAGAGCTAATACATGCGCCCAAACCCGACTCCGTGGAAGGGTTGTATTTATTAGTTACAGAACC
AACCCAGGTTCGCCTGGCCATTTGGTGATTCATAATAAACGAGCGAATTGCACAGCCTCAGCTGGCGATGTATCATTCAAGTTTCTGACCTATCAGC
TTCCGACGGTAGGGTATTGGCCTACCGTGGCAATGACGGGTAACGGAGAATTAGGGTTCGATTCCGGAGAGGGAGCCTGA
>KC672520 Eukaryota;Opisthokonta;Fungi;Ascomycota;Pezizomycotina;Leotiomycetes;Leotiomycetes_X;Leotiomycetes_X_sp.
TACCTGGTTGATTCTGCCCCTATTCATATGCTTGTCTCAAAGATTAAGCCATGCATGTCTAAGTATAAGCAATATATACCGTGAAACTGCGAATGGC
TCATTATATCAGTTATAGTTTATTTGATAGTACCTTACTACT
>AB284159 Eukaryota;Alveolata;Dinophyta;Dinophyceae;Dinophyceae_X;Dinophyceae_XX;Protoperidinium;Protoperidinium_bipes
TGATCCTGCCAGTAGTCATATGCTTGTCTCAAAGATTAAGCCATGCATGTCTCAGTATAAGCTTCAACATGGCAAGACTGTGAATGGCTCATTAAAA
CAGTTGTAGTTTATTTGGTGGCCTCTTTACATGGATAGCCGTGGTAATTCTAGAACTAATACATGCGCTCAAGCCCGACTTCGCAGAAGGGCTGTGT
TTATTTGTTACAGAACCATTTCAGGCTCTGCCTGGTTTTTGGTGAATCAAAATACCTTATGGATTGTGTGGCATCAGCTGGTGATGACTCATTCAAG
CTT
```


# Analyse your data

## Metabarcoding

Usually, a typical Metabarcoding workflow would include:
1. Demultiplexing the libraries (if each file corresponds to a single sample, use the wildcard-creator module, and proceed to the joining step)
2. Joining the paired-end reads
3. Chimera removal
4. ASVs inference / OTUs clustering
5. Taxonomic assignement

The "Add a new module" section has a drop-down list containing various modules to pick, set and chain.
Pick one and hit the "+" button. This will add the module at the bottom of the first section, and prompting you to fill the required fields. For more informations on the modules, you can refer to their manuals on the wiki or by clicking the (i) button on the module interface.

**The use of wildcard '*' for file pointing**

The chaining between module is made through the files names used as input / output. To avoid having to select mannually all the samples to be included in an analysis, wildcards '*' (meaning 'all') are generated during demultiplexing (or by using the wildcard-creator module, see below) and used by the application.
Such wildcards are generated from the compressed libraries fastq files (tar.gz) and by the tag-to-sample file.
**Users cannot type on their own wildcards in the file names of modules**. Instead, the application has an autocompletion feature and will make wildcards suggestions for the user to select within the GUI.

However, when uploading demultiplexed libraries (each FASTQ corresponds to a single sample), the demultiplexing step is not needed. Instead, create a wildcard pattern to pass groups of files through the different processing steps. To do so, use the module [wildcard-creator](man/sections/wildcard_creator.md).

To point to a set of samples (all samples from the tag-to-sample, or all the samples from the library_1 for instance), there will be a '*', and the application adds the processing step as a suffix incrementaly:
- all samples from the tag-to-sample file that have been demultiplexed: 'tag_to_sample*_fwd.fastq' and 'tag_to_sample*_rev.fastq'
- all samples from the library_1 that have been demultiplexed: 'tag_to_sample_Library_1*_fwd.fastq' and 'tag_to_sample_Library_1*_rev.fastq'
- all samples from the tag-to-sample file that have been joined: 'tag_to_sample*_merge-vsearch.fasta'
- all samples from the tag-to-sample file that have been joined and chimera filtered: 'tag_to_sample*_merge-vsearch_uchime.fasta'

The same principle applies for ASV/OTU matrices, we add the previous processing step as a suffix in the file name.

see below for the demultiplexing

<p align="left">
  <img src="https://github.com/trtcrd/SLIM/blob/master/tutos/slim_demultiplexer.png" alt="SLIM example" width="800px"/>
</p>


and below for an OTU clustering using vsearch and taxonomic assignement

<p align="left">
  <img src="https://github.com/trtcrd/SLIM/blob/master/tutos/slim_otu.png" alt="SLIM example" width="800px"/>
</p>


Once your workflow is set, optionally fill the email field, click on the start button, and bookmark the url to allow returning to the job.
If the server mailer is configured, you will receive an email when your job starts, aborts, and ends.

When the job is over, you will have small icons of download on the right of each output field.
All the uploaded, intermediate and results files are available to download.
Your files will remain available on the server during 24h, after what they will be removed for storage optimisation

Each module status is displayed besides its names:
- waiting: the execution started, the module is waiting for files input.
- running: the module is busy.
- warnings: there was some warnings during the execution, but the module is still running.
- aborted: the module aborted and the pipeline has stopped its execution.
- ended: the module has finnished its task.

For more details on the app, you can refer to the [wiki pages](https://github.com/yoann-dufresne/SLIM/wiki)


# Creating your own module

To contribute by adding new softwares, you will have to know a little bit of HTML and javascript.
Please refer to the Man pages to learn [how to create a module](https://github.com/adriantich/SLIM/blob/master/man/README.md#tutorials).

# Current modules by category

In the [manual](https://github.com/adriantich/SLIM/blob/master/man/README.md#list-of-the-modules) page you can find a list of the different modules implemented and their help pages.

# Version history

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
