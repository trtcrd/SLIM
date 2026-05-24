# MSI

The `msi` module runs the centroid-generation portion of the MSI pipeline. In SLIM, MSI is used to preprocess reads, polish/cluster them, trim primers, and export one consensus-centroid FASTA file per sample.

SLIM does not use MSI for downstream sequence labelling or database-based taxonomy.

## Workflow

The SLIM wrapper uses these MSI stages:

1. Preprocess reads.
2. Polish sequences.
3. Cluster centroids.
4. Process primers and export centroid FASTA files.

## Inputs

### Input FASTQ Files

FASTQ files to process. To select multiple FASTQ files at once, use a wildcard pattern created by the [wildcard creator](/man/sections/wildcard_creator.md).

### Primers File

FASTA file containing the forward primer as the first sequence and the reverse primer as the second sequence. Only IUPAC nucleotide characters are allowed.

```fasta
>forward_primer
GAACCTGGTTGATCCTGCCAGT
>reverse_primer
GGTGATCCTTCTGCAGGTTCACCTAC
```

## Parameters

* Minimum Phred score: read-quality filter used during preprocessing.
* Read length limits: minimum and maximum read length.
* Minimum mapped fraction: minimum mapped fraction for reads to be included in a cluster.
* Minimum aligned fraction: minimum aligned fraction for reads to be included in a cluster.
* Minimum reads per cluster: minimum cluster support.
* Maximum primer error: allowed primer-matching error rate.

## Output

### Consensus Centroids

One FASTA file per sample containing consensus centroid sequences.

## References

* MSI repository: https://github.com/nunofonseca/msi
