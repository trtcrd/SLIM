# Pandaseq module

This module give you the possibility to get the assembly of the forward and reverse reads.  
For space efficiency, the reads are dereplicated after the merging process. A size value is added in each read header to keep the abundance.

## Module interactions

### Main inputs

* Forward reads: The FASTQ file containing the forward reads. This file will be passed to pandaseq using the -f option.
* Reverse reads: Same as Forwards reads replacing -f by -r.
* Output file: The FASTA file within the assembled reads will be outputted.

### Options

* Algorithm: The algorithm used to merge the forward and reverse reads.
  * Simple bayesian: https://bmcbioinformatics.biomedcentral.com/articles/10.1186/1471-2105-13-31
  * FastqJoin: https://benthamopen.com/ABSTRACT/TOBIOIJ-7-1
  * FLASH: https://academic.oup.com/bioinformatics/article/27/21/2957/217265/FLASH-fast-length-adjustment-of-short-reads-to
  * PEAR: https://academic.oup.com/bioinformatics/article/30/5/614/247231/PEAR-a-fast-and-accurate-Illumina-Paired-End-reAd
  * RDP: https://academic.oup.com/nar/article/42/D1/D633/1063201/Ribosomal-Database-Project-data-and-tools-for-high
  * Stitch software: https://github.com/audy/stitch
  * Uparse/Usearch: https://www.nature.com/nmeth/journal/v10/n10/full/nmeth.2604.html
* Quality threshold: Minimum alignment score to keep the joined read in the output. Correspond to the -t option of pandaseq. This value is a probability (ie values are includes in \[0, 1\]). To see the full description of this score please refer to the [Pandaseq article](https://bmcbioinformatics.biomedcentral.com/articles/10.1186/1471-2105-13-31)
* Out read length: Minimum and maximum length accepted for the outputted reads.
* Reads overlap: Minimum and maximum overlap accepted between the forward and reverse reads.

## References

* Pandaseq github: https://github.com/neufeld/pandaseq
* Pandaseq publication: https://bmcbioinformatics.biomedcentral.com/articles/10.1186/1471-2105-13-31