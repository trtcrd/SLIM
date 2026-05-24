# OTU Filtering

The `asv-otu-filtering` module removes low-abundance OTUs or ASVs from a count table and, optionally, from matching representative and clustered-read FASTA files.

## Inputs

### Minimum Reads per OTU/ASV

Read-count threshold. For example, with a threshold of `5`, OTUs/ASVs with 4 or fewer reads are discarded.

### Input ASV/OTU Table

TSV count table where rows are clusters and columns are samples. The first row is the header and the first column contains cluster IDs.

```text
OTU  sample_1 sample_2 sample_3
0    0        456      124
1    1        0        3
2    12       7        59
```

With a threshold of `5`, the filtered table becomes:

```text
OTU  sample_1 sample_2 sample_3
0    0        456      124
2    12       7        59
```

### Optional Representative Sequences

FASTA file containing one representative sequence per OTU/ASV. If headers include `;cluster=2;`, SLIM uses that annotation. Otherwise, sequences are interpreted in table order.

### Optional Clustered Reads

FASTA file containing all reads with cluster assignment annotations such as `;cluster=124;`.

## Outputs

* Filtered ASV/OTU table.
* Optional filtered representative FASTA.
* Optional filtered clustered-read FASTA.
