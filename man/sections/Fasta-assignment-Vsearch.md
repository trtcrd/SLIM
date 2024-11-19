# Fasta assignment Vsearch

This module use the assignment function of the Vsearch tool. Using an input database, 

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
* Input sequences: A FASTA file containing all the sequences that you want to annotate.
* Assigned sequences: A tsv file containing 4 fields. The fields are the sequence ID, the consensus taxonomy found, the average distance to nearest references and the ID of the references used to create the consensus. Here an example of this tsv file:
```
sequence	taxon	mean similarity	reference ids
ISU_0;size=2747607;	Eukaryota;Stramenopiles;Ochrophyta;Bacillariophyta;Bacillariophyta_X;Polar-centric-Mediophyceae;Polar-centric-Mediophyceae_X;Polar-centric-Mediophyceae_X_sp.	1	GU822975.1.1077_U;GU823385.1.1401_U;GU823578.1.1076_U
ISU_2905;size=288569;	Eukaryota;Archaeplastida;Chlorophyta;Prasinococcales;Prasinococcales_X;Prasinococcales-Clade-A;Prasinococcus;Prasinococcus_capsulatus	0.995	KT860924
ISU_2908;size=313783;	Eukaryota;Archaeplastida;Chlorophyta;Prasinococcales;Prasinococcales_X;Prasinococcales-Clade-A;Prasinococcus;Prasinococcus_capsulatus	1	AF203400.1.1748_U
```

### Options
* Min similarity: Minimum similarity between a sequence and a reference to annotate the sequence with the reference.
* Direct acceptance threshold: If a reference identity with the sequence is over this threshold, the sequence is directly accepted.
* Number of sequence used for consensus: Maximum number of sequences used to create a consensus. For example, you have 4 sequences from the DB with more than the min similarity. You fix the number of sequences used for the consensus with 2. Then, only the two sequences on four (with the best similarities) will be used to create the consensus assignment.

## References

* Vsearch github: https://github.com/torognes/vsearch
* Original publication: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3150044/
