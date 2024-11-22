# Casper

This module give you the possibility to get the assembly of the forward and reverse reads.  
For space efficiency, the reads are dereplicated after the merging process. A size value is added in each read header to keep the abundance.

## Module interactions

### Main inputs

* Forward reads: The FASTQ file containing the forward reads.
* Reverse reads: The FASTQ file containing the reverse reads.
* Output file: The FASTQ file within the assembled reads will be outputted.

### Options

* kmer size: Size of the kmers used to align reads.
* Maximal quality difference: Threshold based on quality score difference between two nucleotides in a mismatch. Under this threshold, the kmer context aware will chose the nucleotide to keep and over the best quality nucleotide.
* Maximal mismatch ratio: The maximal ratio of mismatches. A 0.5 ratio will allow one base over two.
* Minimal read length: The minimal length of an assembled read.

## References

* Casper website: http://best.snu.ac.kr/casper/index.php
* Casper publication: https://bmcbioinformatics.biomedcentral.com/articles/10.1186/1471-2105-15-S9-S10