# CHOPPER

The `chopper` module filters and trims long-read FASTQ files. It can filter by average read quality, minimum and maximum read length, and trim bases from the start or end of each read.

## Inputs

### Input FASTQ File

Single FASTQ file containing long reads.

## Parameters

* Quality threshold: minimum average read quality.
* Head crop: number of bases to trim from the start of each read.
* Tail crop: number of bases to trim from the end of each read.
* Read length limits: minimum and maximum allowed read length. The maximum cannot exceed `2,147,483,647` bases because of software limits.

## Output

Filtered FASTQ file containing reads that pass all selected filters.
