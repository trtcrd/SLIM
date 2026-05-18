# FASTA Filtering

The `fasta-filtering` module filters dereplicated FASTA files with VSEARCH according to sequence abundance and sequence length.

## Inputs

### Input FASTA File

FASTA file to filter. The module expects abundance information in the FASTA headers, for example `;size=10;`, because it uses VSEARCH `--sizein`.

## Parameters

### Abundance Filter

Defaults:

```
Min: 1
Max: 1000000000
```

These values are passed to VSEARCH as:

```
--minuniquesize
--maxuniquesize
```

They keep only sequences whose abundance is inside the selected interval.

### Sequence Size Filter

Defaults:

```
Min: 1
Max: 1000000000
```

These values are passed to VSEARCH as:

```
--minseqlength
--maxseqlength
```

They keep only sequences whose length is inside the selected interval.

## Output

### Filtered File

Default:

```
filtered.fasta
```

Filtered FASTA file with VSEARCH size annotations preserved.
