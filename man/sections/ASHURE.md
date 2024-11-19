This module integrates the full ASHURE pipeline. 

This pipeline is designed to run data obtained from rolling circle amplification in which, within the same sequence, the fragment is repeated many times (concatamers) allowing to obtain a consensus sequence from the copies of the exact same original DNA string.

It runs the following steps:

1. Pseudo reference database generation (prfg)

2. Concatamer identification (fgs)\*

3. Consensus error correction (msa)\*

4. Primer identification (fpmr)

5. Cluster with OPTICS (clst)

\* fgs and msa are meant to work only for raw reads with more than one concatamer

## Module interactions

### Main inputs
* The fastq files to process. To be able to select multiple fastq at the same time, the shared pattern is needed. However, to have create such option, upload a tar.gz file with all the fasta files to process compressed in it.

* [Primers file](https://github.com/BBaloglu/ASHURE/blob/master/demo/primers.csv) (csv file). The expected structure of the primer csv must have the following columns:

    [fwd_id,fwd_seq,rev_id,rev_seq]

    fwd_id  = name of forward primer; 
    fwd_seq = sequence of forward primer; 
    rev_id = name of reverse primer; 
    rev_seq = sequence of reverse primer
#### Optional inputs
* Reads length (prfg module): Min and max size allowed

* Minimum cluster size (clst): Number of sequences from the centroid for multi-alignment

* Threshold for making clusters to merge (clst)

* Partitions to split the sequences for sweep (clst): during the clustering in each iteration a random set of sequence subsample is chosen for alignment. This subsample is taken from the poorest aligned sequences. This parameter will define how many partitions will be done to select the lowest quantile.

* Size of sequence subsample (clst)

* Iterations to run the clustering (clst)

### Main outputs
* Consensus sequences.

* Trimmed Consensus sequences. This is the Consensus sequences without the primers.

* Cluster center sequences.

## References

* ASHURE repository: https://github.com/BBaloglu/ASHURE
* ASHURE publication: https://besjournals.onlinelibrary.wiley.com/doi/10.1111/2041-210X.13561