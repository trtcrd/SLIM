# Double Tag Demultiplexing

The `demultiplexer` module runs the Double Tag Demultiplexer (DTD). It detects tagged paired-end reads, assigns them to samples, trims primer/tag regions, and writes one forward and one reverse FASTQ file per sample.

## Inputs

### Tag-to-Sample File

CSV file containing the demultiplexing metadata. The CSV must contain at least the library/run identifiers and sample identifiers expected by DTD. When this file is selected, SLIM reads it and automatically creates R1/R2 input fields for each library found in the file.

### Inputs R1/R2 by Library

For each library listed in the tag-to-sample file, select the corresponding raw paired-end FASTQ files:

* `R1`: forward reads
* `R2`: reverse reads

SLIM tries to auto-fill these fields from uploaded FASTQ names when possible.

### Primers File

FASTA file containing the tagged primers. IUPAC symbols are supported.

## Parameters

### Trim Also the Primer Sequence at the End of the Read

Default:

```
disabled
```

When enabled, DTD also trims primer sequences found at the end of reads.

### Filtering by Length

Default:

```
1
```

Minimum length of the trimmed read. Reads shorter than this value are discarded and written to `empty.fasta`.

### Output Undetermined Reads

Default:

```
disabled
```

When enabled, reads that cannot be assigned to a sample are written to a `mistags.tar.gz` archive.

### Mismatches Allowed in Primers

Default:

```
0
```

Number of mismatches allowed when matching tagged primers. IUPAC-compatible matches are not counted as errors.

## Outputs

For every sample in the tag-to-sample CSV, two output FASTQ files are produced:

```
<tag_file>_<library>_<sample>_fwd.fastq
<tag_file>_<library>_<sample>_rev.fastq
```

SLIM also exposes wildcard outputs per library, for example:

```
<tag_file>_<library>*_fwd.fastq
<tag_file>_<library>*_rev.fastq
```

These wildcard outputs can be passed directly into downstream modules such as DADA2, merge-pair tools, or ASV/OTU workflows.

## Practical Advice

Check the generated output list before starting the pipeline. If SLIM warns about sample name collisions, the tag-to-sample file contains duplicated output names and should be fixed before running.

If too many reads are unassigned, check primer orientation, tag spelling, and the mismatch parameter.

## References

* DTD repository: https://github.com/yoann-dufresne/DoubleTagDemultiplexer
