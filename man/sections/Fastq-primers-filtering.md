# FASTQ Primers Filtering

The `fastq-primers-filtering` module removes paired reads that still contain primer sequences.

## Inputs

### Primers File

FASTA file containing primer sequences. IUPAC symbols are supported.

### Input Forward FASTQ File

Forward FASTQ file to filter.

### Input Reverse FASTQ File

Reverse FASTQ file to filter.

## Internal Parameters

The module searches primer sequences in both forward and reverse files using VSEARCH with:

```
--id 0.8
--strand both
--uc_allhits
--maxaccept 0
--maxrejects 0
```

Reads matching primers are identified, then a Python script removes the corresponding pairs from both FASTQ files.

## Outputs

### Primer-Cleaned Forward FASTQ

Default:

```
noPrimers.fastq
```

### Primer-Cleaned Reverse FASTQ

Default:

```
noPrimers.fastq
```

The web interface updates these names automatically from the selected input filenames when possible.

## Practical Advice

Use this module before DADA2 or paired-end merging if primers remain in demultiplexed reads. If too many reads are removed, verify primer orientation and the primer FASTA file.
