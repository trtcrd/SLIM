# FASTA Trimming

The `fasta-trimming` module trims sequences around a specified motif.

## Inputs

### Input FASTA File

FASTA file containing sequences to trim.

## Parameters

### Motif

Sequence motif used as the trimming anchor.

### Which Sub-Sequence to Trim?

The interface describes a sequence as:

```
A-MOTIF-B
```

Available modes:

* `Remove A-F`: remove the sequence before and including the motif.
* `Remove M-B`: remove the motif and sequence after it.
* `Remove M-F`: remove only the motif.

### Keep Reads Without Motif?

Default:

```
No
```

If set to `No`, reads without the motif are discarded. If set to `Yes`, they are kept unchanged.

### Search in a Window

Defaults:

```
Beginning: -1
End: -1
```

When both values are `-1`, the motif is searched across the whole sequence. Otherwise, the motif search is restricted to the selected coordinate window.

## Output

### Trimmed FASTA File

Default:

```
trimmed.fasta
```

FASTA file after motif-based trimming.
