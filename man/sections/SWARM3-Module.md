# SWARM3 Module

This module use the swarm v3 software to create an OTU table.
#### Updates
swarm 3.0 introduces:

* a much faster default algorithm
* a reduced memory footprint
* strict dereplication of input sequences is now mandatory,
* seeds outputs results sorted by decreasing abundance, and then by alphabetical order of sequence labels.
* the representative sequence is the most abundant in the cluster

## Module interactions

### Main inputs

* Sequence files: Select all the FASTA files that you want to merge to perform the clustering.
* OTUs table: The OTUs table in tsv format. each line is a cluster and each column a sample.
The numbers in the matrix is the number of reads for the cluster in the sample.
* Sort the samples: If checked, sort the samples in the matrix using the csv file entered in the following input.
* Most abundant reads: Each centroid sequence for clusters in FASTA format.
The first sequence represent the 0th cluster centroid, the second sequence, the 1th cluster centroid, ...
* All reads: A file containing all the reads with their cluster assignment.

### Options

* d value: The maximum distance between two reads in the same cluster.
If d=1, the fastidious option is automatically set (see swarm github).

## References

* Swarm github: https://github.com/torognes/swarm
* Swarm publication: https://peerj.com/articles/593/
* Swarm v3 publication: https://academic.oup.com/bioinformatics/article/38/1/267/6318385