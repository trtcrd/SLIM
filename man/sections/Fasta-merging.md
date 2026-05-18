# FASTA Merging

The `fasta-merging` module merges several FASTA files into one dereplicated FASTA file and records the origin of each read.

## Inputs

### FASTA Files to Merge

Select the FASTA files to combine. This module accepts multiple files from the file checklist.

## Outputs

### Merged File

Default:

```
merged.fasta
```

Merged and dereplicated FASTA file.

### Origin of Each Read

Default:

```
origins.tsv
```

TSV file recording which input file each read came from. This is used by downstream OTU table generation.

## Practical Advice

Use this module before clustering when several per-sample FASTA files must be pooled into one dataset while preserving sample origin information.
