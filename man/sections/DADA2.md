# DADA2

The `DADA2` module runs a paired-end DADA2 workflow to infer amplicon sequence variants (ASVs). It expects demultiplexed, correctly oriented, primer-trimmed FASTQ files. In SLIM, these files are usually produced by the `demultiplexer` module.

## Inputs

### Tag-to-Sample File

CSV file describing the samples and libraries. This is used to connect the demultiplexed FASTQ files to sample names.

### Forward Reads

Forward FASTQ files. These reads must already be oriented and primer-trimmed.

### Reverse Reads

Reverse FASTQ files. These reads must already be oriented and primer-trimmed.

## Parameters

### Error Model

Default:

```
for each library
```

Available values:

* `for each library`: one error model is learned per sequencing library.
* `for each sample`: one error model is learned per sample.

Library-level error learning is usually more stable when each sample has modest read depth.

### Pooling Strategy

Default:

```
no pool
```

Available values:

* `no pool`: each sample is processed independently.
* `pseudo-pool`: ASVs found across samples are used as priors in a second inference step.
* `pool`: samples are pooled for ASV inference.

Pooling can improve detection of rare variants, but it can also increase compute time. In this SLIM module, pooling only matters when the error model is trained by library.

## Outputs

### ASV Table

Default:

```
asvs-table.tsv
```

Tabular count matrix with ASVs as rows and samples as columns.

### ASV Sequences

Default:

```
representative-asvs.fasta
```

FASTA file containing the inferred ASV sequences.

### Filtering Statistics

Default:

```
filtering-stats.tsv
```

Per-sample statistics from filtering and trimming steps inside the DADA2 workflow.

## Practical Advice

Use the `demultiplexer` module first when working with double-tagged amplicon libraries. DADA2 is sensitive to read orientation, primers, and low-quality tails, so inspect filtering statistics if many reads disappear.

For low-depth datasets, start with library-level error models and no pooling or pseudo-pooling. Full pooling can help rare ASVs but is more computationally demanding.

## References

* DADA2 webpage: https://benjjneb.github.io/dada2/
* DADA2 pooling explanation: https://benjjneb.github.io/dada2/pseudo.html
* DADA2 publication: https://www.nature.com/articles/nmeth.3869
