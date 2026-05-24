# Merge Paired Reads with VSEARCH

The `mergepair-vsearch` module assembles paired-end reads with VSEARCH. For storage efficiency, SLIM dereplicates the merged reads and writes abundance information into the read headers.

## Inputs

* Forward reads: FASTQ file containing R1 reads.
* Reverse reads: FASTQ file containing R2 reads.

## Output

Merged FASTA file containing assembled reads.

## Parameters

* Quality range: minimum and maximum quality values accepted by VSEARCH.
* Merged read length range: minimum and maximum length for assembled reads.
* Maximum differences: maximum number of mismatches allowed in the overlap.
* Minimum overlap: minimum overlap length required to merge a pair.

## References

* VSEARCH repository: https://github.com/torognes/vsearch
* VSEARCH publication: https://peerj.com/articles/2584/
