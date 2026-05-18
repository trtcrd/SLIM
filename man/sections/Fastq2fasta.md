# FASTQ to FASTA

The `fastq2fasta` module converts a FASTQ file to a dereplicated FASTA file with VSEARCH.

## Inputs

### FASTQ Input

FASTQ file to convert.

## Internal Parameters

The module runs VSEARCH `--fastq_filter` with:

```
--fastaout
--fastq_qmax 93
```

After conversion, SLIM dereplicates the temporary FASTA file.

## Output

### FASTA Output

Default:

```
file.fasta
```

Dereplicated FASTA file suitable for downstream FASTA-based modules.
