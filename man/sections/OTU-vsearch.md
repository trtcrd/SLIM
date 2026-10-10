# OTU Clustering with VSEARCH

The `otu-vsearch` module clusters FASTA reads into OTUs with VSEARCH and creates an OTU table.

## Inputs

### Input FASTA Files

Select one or more FASTA files. Wildcard-creator patterns are supported. SLIM dereplicates and merges all matching files into one clustering input while recording each source filename as the sample ID. VSEARCH is run once on that combined input, and the source records are used to build one sample-by-OTU table.

## Parameters

### Use the Tag-to-Sample File to Sort the OTU Table

Default:

```
disabled
```

When enabled, provide a tag-to-sample CSV file to order samples in the OTU table.

### Sequence Similarity Threshold

Default:

```
0.97
```

Passed to VSEARCH as `--id`. The default corresponds to a 97% OTU clustering threshold.

## Outputs

### OTU Table

Default:

```
otus-vsearch.tsv
```

OTU count table with OTUs as rows and samples as columns.

### OTU Representative Sequences

Default:

```
representative-vsearch.fasta
```

FASTA file containing the most abundant read for each OTU.

### Full FASTA with OTU Identifiers

Default:

```
clustered-reads-vsearch.fasta
```

FASTA file where each read header includes its OTU assignment.

## Practical Advice

For classical OTUs, keep the default `0.97` threshold. For stricter clustering, increase the threshold. For broader clusters, decrease it.
