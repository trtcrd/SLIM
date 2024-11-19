# OPTICS

This module integrates the clustering submodule (clst) from the ASHURE pipeline.
It runs the following steps:

## Module interactions

### Main inputs
* The fastq files to process. To be able to select multiple fastq at the same time, the shared pattern is needed. However, to have create such option, upload a tar.gz file with all the fasta files to process compressed in it.

#### Optional inputs
* Minimum cluster size: Number of sequences from the centroid for multi-alignment (integer)

* Threshold for making clusters to merge (from 0 to 1)

* Partitions to split the sequences for sweep: during the clustering in each iteration a random set of sequence subsample is chosen for alignment. This subsample is taken from the poorest aligned sequences. This parameter will define how many partitions will be done to select the lowest quantile (integer)

* Size of sequence subsample (integer)

* Iterations to run the clustering (integer)

* Simmilarity threshold for sequence reads to be merged into the center sequence (from 0 to 1)

### Main outputs
* Consensus sequences

* OTU table output file

## References

* ASHURE repository: https://github.com/BBaloglu/ASHURE
* ASHURE publication: https://besjournals.onlinelibrary.wiley.com/doi/10.1111/2041-210X.13561