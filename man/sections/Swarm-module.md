# SWARM2 Module

The `swarm2` module clusters FASTA reads into OTUs with Swarm v2 and creates an OTU table.

## Inputs

### Input FASTA Files

Select one or more FASTA files. SLIM first merges the selected files and records read origins, then runs Swarm on the merged dataset.

## Parameters

### Use the Tag-to-Sample File to Sort the OTU Table

Default:

```
disabled
```

When enabled, provide a tag-to-sample CSV file to order samples in the OTU table.

### Maximum Differences Between Reads

Default:

```
1
```

This controls the Swarm clustering distance. When the value is `1`, SLIM uses Swarm's fastidious mode. For values greater than `1`, SLIM passes the value with Swarm's `-d` option.

## Outputs

### OTU Table

Default:

```
otus-swarm.tsv
```

OTU count table with OTUs as rows and samples as columns.

### OTU Representative Sequences

Default:

```
representative-swarm.fasta
```

FASTA file containing representative sequences for the OTUs.

### Full FASTA with OTU Identifiers

Default:

```
clustered-reads-swarm.fasta
```

FASTA file where each read header includes its OTU assignment.

## Practical Advice

For new analyses, prefer `swarm3` unless you need to reproduce older SWARM2-based results.

## References

* Swarm repository: https://github.com/torognes/swarm
* Swarm publication: https://peerj.com/articles/593/
