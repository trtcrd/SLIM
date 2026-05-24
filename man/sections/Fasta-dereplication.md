# FASTA Dereplication

The `fasta-dereplication` module merges identical sequences in a FASTA file with VSEARCH. The output FASTA records sequence abundance in each header.

## Inputs

### Input FASTA File

FASTA file containing sequences to dereplicate.

## Output

### Dereplicated FASTA File

FASTA file containing unique sequences. Each header includes a VSEARCH size annotation such as `;size=234;`.

## References

* VSEARCH repository: https://github.com/torognes/vsearch
* VSEARCH publication: https://peerj.com/articles/2584/
