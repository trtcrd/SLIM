# mOTUs

The `mOTUs` module profiles shotgun metagenomic reads with the mOTUs marker-gene profiler. It is useful when you want a prokaryotic community profile that is less dependent on exact whole-genome matches than Kraken2, because mOTUs estimates abundance from universal single-copy marker genes.

This module runs `motus profile` for each sample and then combines the per-sample profiles with `motus merge`.

## Input

### Input mode

Choose how the reads are provided:

| Mode | Use case |
| --- | --- |
| Single-end or already merged reads | One FASTQ/FASTA file per sample, or a wildcard grouping several files. |
| Paired-end reads | One forward and one reverse FASTQ/FASTA file per sample. |

The inputs can be real files or wildcard groups created with the `wildcard-creator` module.

## Output

### mOTUs merged profile

Default:

```text
mOTUs.profile.tsv
```

Merged mOTUs profile table. For each mOTU, the table includes the mOTU identifier, taxonomy, and one abundance column per sample.

### mOTUs merged relative profile

Default:

```text
mOTUs.relative_abundance.tsv
```

Merged relative-abundance table generated from the `.relab` files produced by mOTUs. If the installed mOTUs version does not produce `.relab` files, SLIM copies the merged profile into this output and reports this in the module log.

### mOTUs results archive

Default:

```text
mOTUs.results.tar.gz
```

Archive containing all per-sample mOTUs profiles, merged outputs, and processing logs/reports kept by the module.

### fastp reports archive

Default:

```text
mOTUs.fastp_reports.tar.gz
```

HTML and JSON reports from fastp when FASTQ trimming is enabled.

## Parameters

| Parameter | Default | Meaning |
| --- | --- | --- |
| Marker genes required | `3` | Number of marker genes required before a mOTU is called present. Lower values increase recall; higher values increase precision. mOTUs accepts values from 1 to 10. |
| Minimum alignment length | `75` | Minimum marker-gene alignment length in base pairs. It must be lower than the average read length. Lower values increase recall and are useful for short/degraded reads; higher values increase precision. |
| Counting mode | `INSERT_SCALED` | Abundance scale used by mOTUs. Other choices are `INSERT_RAW`, `INSERT_NORM`, `BASE_RAW`, and `BASE_NORM`. |
| Trim adapters and low-quality bases with fastp | enabled | Runs fastp before mOTUs for FASTQ input. Paired-end data uses `--detect_adapter_for_pe`. |

## fastp Preprocessing

When trimming is enabled, SLIM uses fastp with its default quality and length filters. Important defaults include:

| fastp setting | Default | Notes |
| --- | --- | --- |
| `--length_required` | `15` | Reads shorter than 15 bp after filtering are discarded. |
| Qualified quality threshold | `15` | A base with Phred quality at least Q15 is treated as qualified. |
| Paired-end adapter detection | enabled in SLIM | SLIM adds `--detect_adapter_for_pe` for paired-end runs. |

For FASTA input, fastp is skipped automatically.

## Database

The mOTUs marker-gene database is kept outside the Docker image:

```text
lib/mOTUs/db/db_mOTU
```

`start_slim_v1.0.0.sh` downloads it after the image is built if it is not already present, then mounts it into the container at:

```text
/app/lib/mOTUs/db/db_mOTU
```

You can also download it manually after building the image:

```bash
./download_motus_db.sh
```

On Intel Macs running Linux containers, the standard Polars wheel can crash with `Illegal instruction` because the virtualized CPU does not expose all SIMD features requested by that wheel. The SLIM Dockerfile installs mOTUs from Bioconda, then replaces Polars with `polars[rtcompat]` in the mOTUs environment for this reason.

Current mOTUs 4 does not expose a `-db` option in `motus profile`. SLIM therefore mounts the external `db_mOTU` folder and symlinks it into the installed mOTUs package directory before running the profile command.

### Memory requirements

mOTUs v4 uses BWA against a large marker-gene database. BWA must load the database index before aligning reads, so small Docker/Podman virtual machines can fail even on a small read subset. If the log shows `bwa exit code: 137`, BWA was killed by the operating system because the container ran out of memory.

On macOS with Podman, allocate more memory to the VM before starting SLIM:

```bash
podman machine stop
podman machine set --memory 24576
podman machine start
```

For Docker Desktop, increase Resources > Memory to at least 16 GB, preferably 24 GB.

## Choosing mOTUs, SingleM, or Kraken2-Bracken

Use `mOTUs` when you want a marker-gene-based prokaryotic profile from shotgun data. It is a good companion to SingleM because both are marker-gene profilers, but mOTUs produces mOTU species-level units from its own marker-gene database and includes many uncultivated prokaryotic lineages.

Use `singleM` when you want SingleM's single-copy-marker OTU/profile outputs and its GTDB metapackage.

Use `kraken2-bracken` when you want fast k-mer classification against a broad database. With PlusPF databases, Kraken2-Bracken can include bacteria, archaea, viruses, plasmids, human, protozoa, and fungi, but it is more database-match driven.

## Ancient DNA

For ancient or heavily degraded DNA, the default `75` bp minimum alignment length can be too strict if most reads are short. A starting point is:

| Parameter | Suggested ancient-DNA start |
| --- | --- |
| Minimum alignment length | `35` to `50` |
| Marker genes required | `1` or `2` |
| fastp trimming | enabled, but check the fastp report carefully |

These relaxed settings increase recall but also increase false-positive risk, so compare against negative controls and, when possible, another classifier.

## Command Pattern

For a paired-end sample, SLIM runs a command equivalent to:

```bash
motus profile \
  -f sample_R1.fastq.gz \
  -r sample_R2.fastq.gz \
  -n sample \
  -o mOTUs/sample.mOTUs.profile.tsv \
  -t 8 \
  -g 3 \
  -l 75 \
  -y INSERT_SCALED
```

Then profiles are merged:

```bash
motus merge -i sample1.mOTUs.profile.tsv sample2.mOTUs.profile.tsv -o mOTUs.profile.tsv
```

## References

* mOTUs profiler documentation: https://www.motus-tool.org/profiler/quickstart.html
* mOTUs command manual: https://sunagawalab.ethz.ch/share/TEST_MOTUS_WEBSITE/website/docs/res/documentation/options_manual.html
* mOTUs GitHub repository: https://github.com/motu-tool/mOTUs
* fastp GitHub repository: https://github.com/OpenGene/fastp
