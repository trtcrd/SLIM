# Double Tag Demultiplexing (DTD)

Module that demultiplex libraries and samples in libraries.
The software detect tagged paired end reads to retrieve the origin sample.

## Module interactions

### Main inputs

* Tags by libraries/sample: The CSV file containing all the metadata information for the demultiplexing.
The csv format used is described on the software webpage [here](https://github.com/yoann-dufresne/DoubleTagDemultiplexer).
When the csv file is loaded, pairs or R1/R2 inputs for each libraries are automatically added in the "Inputs R1/R2 by library" part.
* Inputs R1/R2 by library: R1/R2 FASTQ files for each library.
* Primers: The FASTA file within the primer-tagged are listed.
The header is the tag name and the sequence the tag itself (IUPAC symbols allowed).

### Options

* Unassigned reads: Generate two files unasigned_R1.fastq and unasigned_R2.fastq if the box is checked.
These files are filled with paired-end reads that did not correspond to any sample.
* Errors: Errors allowed to retrieve the tagged-primer in the sequences.
IUPAC matches are not considered as errors.

## References

* DTD github: https://github.com/yoann-dufresne/DoubleTagDemultiplexer