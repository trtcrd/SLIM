# LULU post clustering module

This module uses the LULU algorithm for the post clustering of an OTU table.

## Module interactions

### Main inputs

* OTU representative sequences: the representative sequences of each OTU in a fasta format. This is used to produce the pairwise matching list for LULU.
* OTU table: The OTU table in tsv format to be post clustered by LULU.

! The OTU names need to perfectly match between the two files !  

### Options

* Sequence similarity threshold: The similarity above which we consider a pair of sequences as a potential sister.
* Minimum relative co-occurence: The minimum co-occurence across samples to consider a pair of sequences as a potential sister.

### Output

* Post-clustered OTU table in tsv format


## References

* LULU github: https://github.com/tobiasgf/lulu
* LULU publication: https://www.nature.com/articles/s41467-017-01312-x
