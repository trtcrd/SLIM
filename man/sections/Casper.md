# Casper

The `casper` module merges paired-end reads with CASPER. For storage efficiency, SLIM dereplicates the merged reads and writes abundance information into the read headers.

## Inputs

* Forward reads: FASTQ file containing R1 reads.
* Reverse reads: FASTQ file containing R2 reads.

## Output

* Merged reads: FASTQ file containing assembled paired-end reads.

## Parameters

* k-mer size: k-mer length used to align reads.
* Maximum quality difference: mismatch-resolution threshold based on quality-score differences.
* Maximum mismatch ratio: maximum allowed mismatch ratio in the overlap. A value of `0.5` allows one mismatch every two bases.
* Minimum read length: minimum length of an assembled read.

## References

* CASPER website: http://best.snu.ac.kr/casper/index.php
* CASPER publication: https://bmcbioinformatics.biomedcentral.com/articles/10.1186/1471-2105-15-S9-S10
