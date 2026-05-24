# Chimera Removal with VSEARCH

The `chimera-vsearch` module removes chimeric sequences from a FASTA file with VSEARCH `uchime_denovo`. The SLIM interface currently exposes the _de novo_ chimera-detection workflow.

## Inputs

### Input FASTA File

FASTA file containing sequences to filter.

## Outputs

* Filtered FASTA file without detected chimeras.
* Optional chimera FASTA file containing removed sequences.

## References

* VSEARCH repository: https://github.com/torognes/vsearch
* Original UCHIME publication: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3150044/
