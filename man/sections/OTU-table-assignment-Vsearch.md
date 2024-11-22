# OTU table assignment Vsearch

This module use the assignment function of the Vsearch tool. Using an input database, this module will modify the input OTU table to add a column with the taxonomic annotation.

## Module interactions

### Main inputs

* Database: A sequence database in FASTA format with constraints on header. The sequence headers must be composed of a unique ID a space character and a taxonomic annotation with taxon separated by ';'. Each taxonomic annotation must contain the same number of taxa. If not, the consensus taxonomy will be wrong. Here is an example:
```
>AB353770.1.1740_U Eukaryota;Alveolata;Dinophyta;Dinophyceae;Dinophyceae_X;Dinophyceae_XX;Peridiniopsis;Peridiniopsis_kevei
ATGCTTGTCTCAAAGATTAAGCCATGCATGTCTCAGTATAAGCTTTTACATGGCGAAACTGCGAATGGCTCATTAAAACAGTTACAGTTTATTTGAA
GGTCATTTTCTACATGGATAACTGTGGTAATTCTAGAGCTAATACATGCGCCCAAACCCGACTCCGTGGAAGGGTTGTATTTATTAGTTACAGAACC
AACCCAGGTTCGCCTGGCCATTTGGTGATTCATAATAAACGAGCGAATTGCACAGCCTCAGCTGGCGATGTATCATTCAAGTTTCTGACCTATCAGC
TTCCGACGGTAGGGTATTGGCCTACCGTGGCAATGACGGGTAACGGAGAATTAGGGTTCGATTCCGGAGAGGGAGCCTGA
>KC672520.1.1801_U Eukaryota;Opisthokonta;Fungi;Ascomycota;Pezizomycotina;Leotiomycetes;Leotiomycetes_X;Leotiomycetes_X_sp.
TACCTGGTTGATTCTGCCCCTATTCATATGCTTGTCTCAAAGATTAAGCCATGCATGTCTAAGTATAAGCAATATATACCGTGAAACTGCGAATGGC
TCATTATATCAGTTATAGTTTATTTGATAGTACCTTACTACT
>AB284159.1.1765_U Eukaryota;Alveolata;Dinophyta;Dinophyceae;Dinophyceae_X;Dinophyceae_XX;Protoperidinium;Protoperidinium_bipes
TGATCCTGCCAGTAGTCATATGCTTGTCTCAAAGATTAAGCCATGCATGTCTCAGTATAAGCTTCAACATGGCAAGACTGTGAATGGCTCATTAAAA
CAGTTGTAGTTTATTTGGTGGCCTCTTTACATGGATAGCCGTGGTAATTCTAGAACTAATACATGCGCTCAAGCCCGACTTCGCAGAAGGGCTGTGT
TTATTTGTTACAGAACCATTTCAGGCTCTGCCTGGTTTTTGGTGAATCAAAATACCTTATGGATTGTGTGGCATCAGCTGGTGATGACTCATTCAAG
CTT
```
* Input OTU table: a tsv file where lines are OTU and columns samples. The first line contain the sample names. The first column contain the OTU id.
* Reference sequences: A FASTA file containing all the reference sequences for the OTU that you want to annotate. Each OTU in the table must have a corresponding sequence in the FASTA file.
* Assigned OTU table: A tsv file containing the OTU table followed by 3 fields. The fields are the consensus taxonomy found, the average distance to nearest references and the ID of the references used to create the consensus.

### Options
* Min similarity: Minimum similarity between a sequence and a reference to annotate the sequence with the reference.
* Direct acceptance threshold: If a reference identity with the sequence is over this threshold, the sequence is directly accepted.
* Number of sequence used for consensus: Maximum number of sequences used to create a consensus. For example, you have 4 sequences from the DB with more than the min similarity. You fix the number of sequences used for the consensus with 2. Then, only the two sequences on four (with the best similarities) will be used to create the consensus assignment.

## References

* Vsearch github: https://github.com/torognes/vsearch
* Original publication: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3150044/
