# FASTA Assignment with VSEARCH

The `assignment-fasta-vsearch` module assigns taxonomy to representative sequences by comparing them against a reference FASTA database with VSEARCH.

## Inputs

### Reference Sequence Database

FASTA file containing reference sequences. Each header must contain a unique identifier, a space, and a semicolon-separated taxonomy string:

```
>REF001 Eukaryota;Alveolata;Dinophyta;Dinophyceae;Peridiniopsis;Peridiniopsis_kevei
ATGCTTGTCTCAAAGATTAAGCCATGCATGTCTCAGTATAAGCTT
```

All reference records should have the same number of taxonomic ranks. If ranks are inconsistent, consensus taxonomy can become misleading.

### Input Representative Sequences

FASTA file containing the sequences to annotate.

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

If a hit reaches this threshold, the assignment can be accepted directly instead of relying on a broader consensus.

### Number of Matches to Create Consensus

Default:

```
3
```

Maximum number of best matching reference sequences used to build the consensus taxonomy.

## Output

### Taxonomic Assignment of the Sequences

Default:

```
assigned-vsearch.tsv
```

The output contains the sequence ID, consensus taxonomy, mean similarity, and reference IDs used for the consensus.

## Practical Advice

This module is useful after ASV or OTU generation when you want a standalone assignment table for representative sequences. Use the OTU-table version of this module if you want the taxonomy appended directly to an ASV/OTU count table.

## References

* VSEARCH repository: https://github.com/torognes/vsearch
* Original UCHIME/USEARCH publication: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3150044/
