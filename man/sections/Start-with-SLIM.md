# Start with SLIM

SLIM is a browser-based platform for building and running genomics pipelines. It is designed for users who want to process metabarcoding, long-read amplicon, or selected shotgun-metagenomics data without writing command-line workflows.

Project repository: [trtcrd/SLIM](https://github.com/trtcrd/SLIM)

## Before You Start

SLIM runs in a Podman or Docker container. Building the container can take time because several bioinformatics tools and language environments are installed. If the build fails because of network, proxy, certificate, or storage restrictions, ask an IT administrator for help and include the build log in any issue report.

SLIM is CPU-only. It does not require GPU support.

## Core Concepts

### Client and Server

The browser page is the client. It lets you upload files, choose modules, set parameters, and start analyses.

The server runs inside the container. It receives the pipeline configuration from the browser, executes the requested modules, writes logs, and exposes output files for download.

### Sessions

When you open SLIM, the server creates a session token and adds it to the URL:

```text
http://localhost:8080/?token=GxgG6vSsdgrNzYBJ7b99CsvDhmWM7C
```

Bookmark or copy the tokenized URL if you want to return to that session while it remains available.

### Modules

A SLIM module is one processing step. Some modules wrap a single command-line tool, while others run several tools and formatting steps.

Modules appear as boxes in the web interface. Each box contains:

* input fields;
* output file names;
* parameters and optional advanced settings;
* download icons after the module finishes.

Modules run in the order shown in the pipeline. Each module must receive files that already exist, either from upload or from an earlier module.

## Uploading Data

Use the file uploader at the top of the page to upload raw data and supporting files.

For many-sample workflows, SLIM relies on wildcard patterns to group files. A wildcard describes the shared file-name pattern:

```text
files:   file_a.txt file_b.txt
pattern: file_*.txt
```

Wildcards are created by modules such as `demultiplexer` and `wildcard-creator`. Prefer selecting a suggested wildcard from autocompletion rather than typing one manually.

If you upload many files that should be grouped together, upload them together in a `.tar.gz` archive or use the `wildcard-creator` module after upload.

## Running an Analysis

1. Upload the required input files.
2. Add modules with **Add a new module**.
3. Fill required input, output, and parameter fields.
4. Check that each module consumes an uploaded file or an output produced by an earlier module.
5. Optionally enter an email address if the server mailer is configured.
6. Click **Start analysis**.

During execution, module statuses indicate whether a module is waiting, running, warning, aborted, or ended.

## Saving and Restoring Pipelines

Click **Save** to download the current pipeline configuration. Click **Load** in a new session to restore it.

SLIM also writes a `pipeline.conf` file inside the session folder while modules run. This file records the modules, inputs, outputs, and parameters used for the job.

## Downloading Results

When a module finishes, download icons appear next to its output fields. You can also download uploaded, intermediate, and final result files from the session while they remain on the server.

## Optional Shotgun Modules

By default, SLIM starts without the large shotgun metagenomics databases, so Kraken2-Bracken, SingleM, and mOTUs are hidden from the module list.

Start SLIM with `--shotgun-databases` to download/mount those databases and expose the shotgun modules:

```bash
bash start_slim_v1.0.0.sh --shotgun-databases
```

Ancient-DNA helper modules are present in the codebase but are not exposed in the default module list.

## Developing Modules

Module developers usually edit three files:

* `server/modules/<module>.js`: server-side command construction and execution;
* `www/modules/<module>.js`: client-side module class;
* `www/modules/<module>.html`: client-side fields shown in the interface.

For details, see [How to write a module](/man/sections/How-to-write-a-new-module.md).
