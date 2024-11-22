# CHOPPER

This module allows to filter and trim long read fastq files. Filtering is done on average read quality and minimal or maximal read length, and applying a headcrop (start of read) and tailcrop (end of read) while printing the reads passing the filter.

## Module interactions

### Main inputs

* Single fastq file.

### Options

* Quality threshold to filter the sequences

* Nucleotides to trim from and to

* Final read lengths allowes. Max size can't be higher than 2,147,483,647 nucleotides because of software limitations.