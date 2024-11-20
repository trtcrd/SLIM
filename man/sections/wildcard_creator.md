# Wildcard creator

This module is meant to be used for demultiplexed experiments.

As SLIM was originally meant to work with multiplexed experiments (multiple samples in one sequencing library) this module is needed to create the wildcard that SLIM will use to group the sequence files.

## Behaviour

Start typing the shared patter among your target files. Once you press enter or click outside the input box, a list of files matching your pattern will be deploid and a suggested wildcard will be shown. You can use only one * if needed to be more precise in the file selection.

The suggested wildcard can be changed although it is not recommended due to possible incompatibilities.

## Example

If we upload the following files:
```
file_AA.fasta
file_AB.fasta
file_BC.fastq
```

The pattern: _file_ will create the wildcard _file\_*_ and will reffer to all the files.

However, if only the fasta files are the target we can use both _file\_A_ or _file*fasta_, and both will suggest _file\_A*.fasta_ as wildcard. In this example we could manually change it to _file*.fasta_ but it is not recommended to do it.