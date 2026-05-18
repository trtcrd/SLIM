# Kraken2-Bracken

The `kraken2-bracken` module performs taxonomic classification of shotgun metagenomic reads with [Kraken2](https://github.com/DerrickWood/kraken2), then estimates abundance at a chosen taxonomic rank with [Bracken](https://ccb.jhu.edu/software/bracken/).

Kraken2 is a k-mer/minimizer-based classifier. Bracken uses the Kraken2 report and database-specific k-mer distribution files to estimate abundance at one selected taxonomic level.

## Module Inputs

### Input Mode

Default:

```
Single-end or already merged reads
```

Available modes:

* `Single-end or already merged reads`: one FASTQ or FASTA pattern is used.
* `Paired-end reads`: forward and reverse FASTQ patterns are used.

### Reads Pattern

Used in single-end mode. Examples:

```
*.fastq.gz
*.fasta
```

### Forward and Reverse Reads Pattern

Used in paired-end mode. Use wildcard patterns created by the `wildcard-creator` module when processing several samples, for example:

```
ERR*_1.fastq.gz
ERR*_2.fastq.gz
```

The number and ordering of forward and reverse files must match.

## Database

Default in SLIM:

```
PlusPF-16
```

The database selected in the module must exist in:

```
/app/lib/kraken2/db
```

When using the `start_slim_v1.0.0.sh` script, this directory is mounted from:

```
lib/kraken2/db
```

Available SLIM database choices:

| SLIM value | Content |
| --- | --- |
| `pluspf_16` | Standard plus RefSeq protozoa and fungi, 16 GB indexed database variant. |
| `pluspf_8` | Standard plus RefSeq protozoa and fungi, 8 GB indexed database variant. |
| `standard_16` | Archaea, bacteria, viral, plasmid, human, and UniVec_Core, 16 GB indexed database variant. |
| `standard_8` | Archaea, bacteria, viral, plasmid, human, and UniVec_Core, 8 GB indexed database variant. |
| `viral` | Viral database. |
| `custom` | Custom database placed in `/app/lib/kraken2/db/custom`. |

`PlusPF` is a useful default when fungi or protozoa may be present. It does not include plants by default. For plant-heavy samples, a PlusPFP database or a custom database is more appropriate.

## Outputs

### Bracken Abundance Matrix

Default:

```
kraken2_bracken_abundance.tsv
```

This table contains Bracken-estimated read counts for each taxon at the selected taxonomic level.

### Bracken Relative-Abundance Matrix

Default:

```
kraken2_bracken_relative_abundance.tsv
```

This table contains the Bracken fraction of total reads for each taxon at the selected taxonomic level.

### Kraken2/Bracken Results Archive

Default:

```
kraken2_bracken_results.tar.gz
```

This archive contains per-sample Kraken2 outputs, Kraken2 reports, Bracken outputs, Bracken reports, the combined matrices, and fastp reports when fastp preprocessing is enabled.

## Options

### Kraken2 Confidence

Default in SLIM:

```
0.05
```

Kraken2 default:

```
0.0
```

The confidence score is a threshold between 0 and 1. Higher values are more conservative: fewer reads are assigned to specific taxa, and more reads may be moved higher in the taxonomy or left unclassified. Kraken2's confidence value is a practical score, not a formal probability.

Suggested starting points:

| Data type | Suggested values |
| --- | --- |
| General shotgun screening | `0.05` or `0.1` |
| Conservative reporting | `0.1` to `0.2` |
| Ancient DNA or very short reads | compare `0`, `0.05`, and `0.1` |
| Targeted, high-confidence pathogen calls | consider `0.1` or higher, plus manual validation |

### Bracken Taxonomic Level

Default in SLIM:

```
Species
```

Available values:

| Value | Rank |
| --- | --- |
| `S` | Species |
| `G` | Genus |
| `F` | Family |
| `O` | Order |
| `C` | Class |
| `P` | Phylum |
| `D` | Domain |

Species-level output is useful but can be fragile when reference genomes are incomplete, reads are short, or closely related taxa share many sequences. Genus or family is often more robust for ancient DNA, environmental samples, or broad eukaryotic screening.

### Bracken Read Length

Default in SLIM:

```
300
```

Bracken requires database files generated for a specific read length, such as:

```
database150mers.kmer_distrib
```

The selected read length should match the average read length after preprocessing. If the database does not contain Bracken files for the selected value, the module stops and reports the missing read length.

Suggested values:

| Data type | Suggested Bracken read length |
| --- | --- |
| Illumina 2x150, unmerged | `150` |
| Illumina 2x250 or 2x300 | `250` or `300` |
| Already merged short reads | approximate mean merged length |
| Ancient DNA | often `50` or `75` |

### Bracken Minimum Reads

Default in SLIM:

```
10
```

This is Bracken's `-t` threshold. A taxon must have at least this many reads before Bracken redistributes higher-level reads to it. Higher values reduce low-count noise but can hide rare taxa.

Suggested starting points:

| Aim | Suggested value |
| --- | ---: |
| Exploratory screening | `1` to `10` |
| Routine profiling | `10` |
| Conservative reporting | `20` to `50` |
| Ancient DNA with strict reporting | `20` or higher, depending on controls |

### Use Kraken2 Memory Mapping

Default in SLIM:

```
disabled
```

When enabled, Kraken2 uses `--memory-mapping`. This can reduce RAM pressure because the database is not loaded entirely into memory. It is usually slower. Use it when the database is too large for the available RAM.

### Trim Adapters and Low-Quality Bases with fastp

Default in SLIM:

```
enabled
```

When enabled, SLIM runs fastp before Kraken2. For paired-end reads, SLIM uses:

```
--detect_adapter_for_pe
--thread <SLIM threads>
```

For single-end FASTQ reads, SLIM uses fastp's single-end mode. FASTA inputs are not passed through fastp.

Important fastp defaults are:

| Parameter | fastp default | Meaning |
| --- | ---: | --- |
| `--qualified_quality_phred` | `15` | A base is considered qualified if its Phred score is at least this value. |
| `--unqualified_percent_limit` | `40` | A read can contain this percentage of unqualified bases before being filtered. |
| `--length_required` | `15` | Reads shorter than this after trimming are discarded. |
| `--average_qual` | `0` | No average-read-quality filter by default. |
| `--detect_adapter_for_pe` | disabled by fastp, enabled by SLIM for paired-end reads | Enables paired-end adapter detection. |

## Kraken2 k-mer and Minimizer Parameters

The k-mer and minimizer sizes are database-build parameters, not normal runtime parameters. With prebuilt databases such as `pluspf_16`, they are already fixed.

Kraken2 nucleotide database build defaults are:

| Parameter | Kraken2 default | Meaning |
| --- | ---: | --- |
| `--kmer-len` | `35` | Length of k-mers considered during database construction. |
| `--minimizer-len` | `31` | Length of minimizers stored in the database. |
| `--minimizer-spaces` | `7` | Number of minimizer positions masked in Kraken2's spaced seed approach. |

Changing these values requires building a custom Kraken2 database. Smaller k-mer values can increase sensitivity for short or damaged reads, but may also increase false positives. Larger k-mer values can be more specific but will miss reads shorter than the k-mer length.

## Advanced Kraken2 Runtime Parameters

The current SLIM interface exposes confidence and memory mapping. The parameters below are useful candidates for a future "advanced" section.

| Parameter | Kraken2 default | Meaning |
| --- | ---: | --- |
| `--minimum-hit-groups` | `2` | Minimum number of hit groups needed before Kraken2 classifies a sequence. Increasing it is more conservative; lowering it to `1` can help very short reads but increases false positives. |
| `--minimum-base-quality` | not set | Ignores bases below this quality during classification. Useful for noisy reads, but can remove signal from already short reads. |
| `--quick` | disabled | Stops after the first hit. Faster, but less thorough. |
| `--report-minimizer-data` | disabled | Adds minimizer support information to reports, useful for checking whether a hit is supported by many independent minimizers or only a few. |
| `--classified-out` | disabled | Writes classified reads to a file. Useful for checking or downstream mapping. |
| `--unclassified-out` | disabled | Writes unclassified reads to a file. Useful for downstream assembly or reclassification. |

For ancient DNA or other very short reads, `--minimum-hit-groups 1` can increase sensitivity, but it should be treated as exploratory unless controls support the result.

## Practical Advice

### Prokaryotic Shotgun Metagenomes

`standard_16` or `pluspf_16` are reasonable. Use `confidence = 0.05` or `0.1`. Species-level Bracken can be useful if the organisms are well represented in the database; genus-level summaries are usually more robust.

### Fungi or Protozoa

Use `pluspf_16` rather than `standard_16`. For broad eukaryotic screening, genus or family-level summaries are often safer than species-level calls.

### Plants or Other Large Eukaryotes

`PlusPF` does not include plants. Use a PlusPFP database or a custom database if plant reads are important.

### Ancient DNA

Ancient DNA often contains short, damaged reads and environmental contamination. Use fastp for adapter trimming, but avoid aggressive length filtering if you customize the script. Choose a Bracken read length close to the post-trim mean, often `50` or `75`. Run a sensitivity check across multiple confidence values, for example `0`, `0.05`, and `0.1`.

For ancient DNA, taxonomic classification alone is not authentication. Use controls, damage patterns, fragment-length distributions, and independent mapping where possible.

## Current Command Structure

The SLIM wrapper runs approximately:

```
fastp -i R1.fastq.gz -I R2.fastq.gz \
  -o trimmed.R1.fastq.gz -O trimmed.R2.fastq.gz \
  --detect_adapter_for_pe \
  --thread <threads>

kraken2 \
  --db <database> \
  --threads <threads> \
  --use-names \
  --confidence <confidence> \
  --report sample.kraken2.report \
  --output sample.kraken2.output \
  [--memory-mapping] \
  [--paired R1 R2]

bracken \
  -d <database> \
  -i sample.kraken2.report \
  -o sample.bracken.tsv \
  -w sample.bracken.report \
  -r <read_length> \
  -l <taxonomic_level> \
  -t <minimum_reads>
```

## References

* Kraken2 manual: https://github.com/DerrickWood/kraken2/wiki/Manual
* Kraken2 prebuilt database index zone: https://benlangmead.github.io/aws-indexes/k2
* Bracken manual: https://ccb.jhu.edu/software/bracken/index.shtml?t=manual
* fastp documentation: https://github.com/OpenGene/fastp
