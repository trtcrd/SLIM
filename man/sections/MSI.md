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
* Input fastq file. If multiple fastq files are about to be run, type manually the shared pattern among the file names changing the unique part of the name with an \*.
```
i.e. for the files 

sample_001.fastq sample_002.fastq 

you can use:

sample_00*.fastq or sample*.fastq or sample_0*.fastq

but keep always the file extension (.fastq)
```


* Primers file. This fasta file requires the first sequence \*\*\* to be the forward primer and the second the reverse as follows:
```
>forward_primer
GAACCTGGTTGATCCTGCCAGT
>reverse_primer
GGTGATCCTTCTGCAGGTTCACCTAC
```
\*\*\*Only IUPAC characters are allowed.

#### Optional inputs

* Cluster minimum reads. (C)

* Cd-hit cluster threshold. (C)

* Primer max error. (D)

* Reads lengths. (A)

* Minimum phred score. (A)

* Minimum mapped fraction of reads to be included in cluster. (C)

* Minimum aligned fraction of read to be included in cluster. (C)

### Output
* consensus. One fasta file for each sample with the consensus sequences.

## References
* MSI repository: https://github.com/nunofonseca/msi?tab=readme-ov-file