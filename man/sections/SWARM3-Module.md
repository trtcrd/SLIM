# SWARM3 Module

This module uses Swarm v3 to create an OTU table.
#### Updates
swarm 3.0 introduces:

* a much faster default algorithm
* a reduced memory footprint
* strict dereplication of input sequences is now mandatory
* seed outputs are sorted by decreasing abundance and then by alphabetical order of sequence labels
* the representative sequence is the most abundant in the cluster

## Module interactions

### Main inputs

* Sequence files: Select all the FASTA files that you want to merge before clustering.
* OTU table: The OTU table in TSV format. Each line is a cluster and each column is a sample.
The numbers in the matrix are the numbers of reads for each cluster in each sample.
* Sort the samples: If checked, sort the samples in the matrix using the csv file entered in the following input.
* Most abundant reads: Each centroid sequence for clusters in FASTA format.
The first sequence represents cluster 0, the second sequence represents cluster 1, and so on.
* All reads: A file containing all the reads with their cluster assignment.

### Options

* d value: The maximum distance between two reads in the same cluster.
If d=1, the fastidious option is automatically set (see swarm github).

## References

* Swarm github: https://github.com/torognes/swarm
* Swarm publication: https://peerj.com/articles/593/
* Swarm v3 publication: https://academic.oup.com/bioinformatics/article/38/1/267/6318385
