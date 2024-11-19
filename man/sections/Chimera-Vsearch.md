# Chimera Vsearch

This module use the uchime module of the Vsearch tool to filter the chimeras from an FASTA file.
For now, only the _de novo_ version is available through the web server.

## Module interactions

### Main inputs

* Input file: The FASTA containing all the sequences to filter.
* Filtered file: The file without chimeras that will be outputted.

### Options

* Chimeras: If not empty, the chimeras will be outputted in this file.

## References

* Vsearch github: https://github.com/torognes/vsearch
* Original publication: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3150044/
