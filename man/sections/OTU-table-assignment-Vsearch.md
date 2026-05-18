# ASV/OTU Table Assignment with VSEARCH

The `assignment-table-vsearch` module assigns taxonomy to representative ASV/OTU sequences with VSEARCH, then appends the resulting taxonomy to an ASV/OTU table.

## Inputs

### Reference Sequence Database

FASTA file containing reference sequences. Each header must contain a unique identifier, a space, and a semicolon-separated taxonomy string:

```
>REF001 Eukaryota;Alveolata;Dinophyta;Dinophyceae;Peridiniopsis;Peridiniopsis_kevei
ATGCTTGTCTCAAAGATTAAGCCATGCATGTCTCAGTATAAGCTT
```

All reference records should contain the same number of ranks.

### ASV/OTU Representative Sequences

FASTA file containing one representative sequence for each ASV/OTU in the table.

### Input ASV/OTU Table

TSV count table with ASVs/OTUs as rows and samples as columns. Each ASV/OTU in the table must have a matching sequence in the representative FASTA file.

## Parameters

### Minimum Similarity

Default:

```
0.9
```

Passed to VSEARCH as `--id`. References below this identity threshold are ignored.

### Direct Acceptance Threshold

Default:

```
0.99
```

If a hit reaches this threshold, the assignment can be accepted directly.

### Number of Matches to Create Consensus

Default:

```
3
```

Maximum number of best matching reference sequences used to build the consensus taxonomy.

## Output

### Annotated ASV/OTU Table

Default:

```
assigned-vsearch.tsv
```

The output is the input count table plus taxonomy-related columns, including consensus taxonomy, mean similarity, and reference IDs used for assignment.

## Practical Advice

Use this module when your downstream analysis should keep abundance counts and taxonomy in one table. Use `assignment-fasta-vsearch` if you only need a sequence-to-taxonomy table.

## References

* VSEARCH repository: https://github.com/torognes/vsearch
* Original UCHIME/USEARCH publication: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3150044/
