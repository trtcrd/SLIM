# LULU Post-Clustering

The `lulu` module uses the LULU algorithm to curate an OTU table after clustering. It identifies likely erroneous daughter OTUs using sequence similarity and co-occurrence patterns.

## Inputs

* OTU representative sequences: FASTA file containing one representative sequence per OTU.
* OTU table: TSV table to curate.

OTU identifiers must match exactly between the representative FASTA file and the OTU table.

## Parameters

* Sequence similarity threshold: similarity above which a pair of OTUs can be considered related.
* Minimum relative co-occurrence: minimum co-occurrence required to consider a lower-abundance OTU a potential daughter.

## Output

Post-clustered OTU table in TSV format.

## References

* LULU repository: https://github.com/tobiasgf/lulu
* LULU publication: https://www.nature.com/articles/s41467-017-01312-x
