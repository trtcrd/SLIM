# Remove Ambiguous FASTA Reads

The `fasta-remove-ambiguous-reads` module removes sequences containing ambiguous bases from a FASTA file.

## Inputs

### Input FASTA File

FASTA file to clean.

## Output

### Output File

Default:

```
noN.fasta
```

FASTA file containing only sequences without ambiguous `N` bases.

## Practical Advice

Use this module before clustering or taxonomic assignment when ambiguous bases cause downstream tools to reject or mis-handle sequences.
