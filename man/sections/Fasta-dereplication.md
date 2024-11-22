# Fasta dereplication

This module use the dereplication module of the Vsearch tool to merge similar sequences in a FASTA file. The dereplicated sequences are outputted in a FASTA file with the quantity of each read in their header.

## Module interactions

### Main inputs

* FASTA file: The FASTA containing all the sequences to dereplicate.
* Dereplicate FASTA file: The file containing all the merged sequences. For each sequence the header contain the the size annotation as _;size=234;_.

## References

* Vsearch github: https://github.com/torognes/vsearch
* Original publication: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3150044/
