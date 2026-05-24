# SWARM3

The `swarm3` module clusters dereplicated FASTA sequences with Swarm v3 and creates an OTU table.

Swarm v3 introduced a faster default algorithm, reduced memory use, mandatory strict dereplication of input sequences, and representative sequences sorted by decreasing abundance and then by sequence label.

## Inputs

* Sequence files: FASTA files to merge before clustering.
* Optional tag-to-sample CSV: used to sort samples in the output table when requested.

## Parameters

* `d` value: maximum distance between two reads in the same cluster. If `d=1`, Swarm's fastidious option is enabled automatically.

## Outputs

* OTU table in TSV format, with clusters as rows and samples as columns.
* Most abundant reads, one centroid sequence per cluster in FASTA format.
* All reads with cluster assignments in their headers.

## References

* Swarm repository: https://github.com/torognes/swarm
* Swarm publication: https://peerj.com/articles/593/
* Swarm v3 publication: https://academic.oup.com/bioinformatics/article/38/1/267/6318385
