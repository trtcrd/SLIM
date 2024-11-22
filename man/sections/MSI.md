# MSI

MSI module runs the MSI pipeline which clusters and classify sequences. Clustering is performed with cd-hit and sequence alignment is done using BLAST against a database that has to be provided. The pipeline is divided in five steps as follows:

A. Preprocess

B. Polish

C. Cluster

D. Primer processing

E. Classification

However in the Module implemented in SLIM, only the steps A, B and C are processed to obtain the centroids for each sample.

This steps are mentioned in Optional inputs as to which they are referred to.

## Module interactions

### Main inputs
* The fastq files to process. To be able to select multiple fastq at the same time, the shared pattern is needed, the wildcard. See [wildcard creator](https://github.com/adriantich/SLIM/blob/master/man/sections/wildcard_creator.md) module for more information.


* Primers file. This fasta file requires the first sequence \*\*\* to be the forward primer and the second the reverse as follows:
```
>forward_primer
GAACCTGGTTGATCCTGCCAGT
>reverse_primer
GGTGATCCTTCTGCAGGTTCACCTAC
```
\*\*\*Only IUPAC characters are allowed.

#### Optional inputs

* Minimum phred score. (A)

* Reads lengths. (A)

* Minimum mapped fraction of reads to be included in cluster. (C)

* Minimum aligned fraction of read to be included in cluster. (C)

* Cluster minimum reads. (C)

* Primer max error. (D)

### Output
* Consensus. One fasta file for each sample with the consensus sequences.

## References
* MSI repository: https://github.com/nunofonseca/msi?tab=readme-ov-file