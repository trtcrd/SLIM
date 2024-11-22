# Mergepair vsearch

This module give you the possibility to get the assembly of the forward and reverse reads.  
For space efficiency, the reads are dereplicated after the merging process. A size value is added in each read header to keep the abundance.

## Module interactions

### Main inputs

* Forward reads: The FASTQ file containing the forward reads.
* Reverse reads: The FASTQ file containing the reverse reads.
* Output file: The FASTA file within the assembled reads will be outputted.

### Options

* Quality extremum: The limit quality thresholds. If a nucleotide is over the max or under the min the sequence will be rejected.
* Merged read size extremum: Minimum and maximum length for assembled read.
* Read maximum differences: Maximum mismatches in the forward/reverse overlap.
* Read minimum overlap: Minimum length of the forward/reverse overlap.

## References

* Vsearch github: https://github.com/torognes/vsearch
* Vsearch publication: https://peerj.com/articles/2584/