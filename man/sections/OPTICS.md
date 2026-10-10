# OPTICS

The `optics` module runs the clustering submodule (`clst`) from the [ASHURE](/man/sections/ASHURE.md) pipeline.

## Inputs

### Input FASTA Files

FASTA files to process. To select multiple FASTA files at once, use a wildcard pattern created by the [wildcard creator](/man/sections/wildcard_creator.md).

All files matching the pattern are kept in one OPTICS execution. They are combined for clustering, while the source filename is retained as the sample ID used to construct one OTU table.

## Parameters

* Minimum cluster size: minimum number of sequences used for multiple alignment around a centroid.
* Cluster merge threshold: threshold used to merge clusters.
* Sweep partitions: number of partitions used when selecting poorly aligned sequence subsets during clustering.
* Sequence subsample size: number of sequences sampled during clustering sweeps.
* Clustering iterations: number of clustering iterations to run.
* Similarity threshold: threshold for merging sequence reads into the center sequence.

## Outputs

* OTU table.
* Consensus sequences.
* Cluster-membership table recording which sequence belongs to which consensus.

## References

* ASHURE repository: https://github.com/BBaloglu/ASHURE
* ASHURE publication: https://besjournals.onlinelibrary.wiley.com/doi/10.1111/2041-210X.13561
