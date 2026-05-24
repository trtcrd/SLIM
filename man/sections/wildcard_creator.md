# Wildcard Creator

The `wildcard-creator` module groups already-demultiplexed files so they can be passed together into downstream modules.

SLIM originally focused on multiplexed sequencing libraries, where demultiplexing modules naturally create wildcard outputs. This utility provides the same grouping behavior when each uploaded file already corresponds to one sample.

## Behavior

Start typing the shared pattern among the target files. After you press Enter or click outside the input box, SLIM lists matching files and suggests a wildcard.

Use only one `*` wildcard. More specific patterns are safer and reduce the risk of selecting unintended files.

The suggested wildcard can be edited, but this is not recommended unless you understand the downstream file-matching behavior.

## Example

Uploaded files:

```text
file_AA.fasta
file_AB.fasta
file_BC.fastq
```

Typing `file` suggests:

```text
file_*
```

This pattern refers to all three files. If only the FASTA files are wanted, use a more specific starting pattern such as `file_A` or `file*fasta`; SLIM can then suggest:

```text
file_A*.fasta
```
