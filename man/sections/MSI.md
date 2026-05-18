# MSI

The MSI module runs the MSI pipeline, which clusters and classifies sequences. Clustering is performed with CD-HIT and sequence alignment is done using BLAST against a database that has to be provided. The full MSI pipeline is divided into five steps:

A. Preprocess

B. Polish

C. Cluster

D. Primer processing

E. Classification

In the SLIM module, only steps A, B, and C are run to obtain centroids for each sample.

The optional inputs below indicate which MSI step they refer to.

## Module interactions

### Main inputs
* FASTQ files to process. To select several FASTQ files at the same time, use their shared wildcard pattern. See the [wildcard creator](/man/sections/wildcard_creator.md) module for more information.


* Primers file. This FASTA file requires the first sequence to be the forward primer and the second sequence to be the reverse primer, as follows:
```
>forward_primer
GAACCTGGTTGATCCTGCCAGT
>reverse_primer
GGTGATCCTTCTGCAGGTTCACCTAC
```
Only IUPAC characters are allowed.

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
