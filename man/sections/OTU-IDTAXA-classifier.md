# OTU IDTAXA classifier

This module uses the IDTAXA classifier from the DECIPHER R package for taxonomic assignments.

## Module interactions

### Main inputs

* Representative sequences OTU/ASV: the (representative) sequences of each (OTU)/ASV in a fasta format. 

* OTU/ASV table: The OTU/ASV table in tsv format to be annotated with IDTAXA. Each OTU/ASV in the table must have a corresponding sequence in the FASTA file.

* Trained IDTAXA classifier: A RData file containing the previously trained classifier. See [here](http://www2.decipher.codes/Documentation/Documentation-ClassifySequences.html) for training your own classifier from a curated FASTA database. Alternatively you can download some on the [download](http://www2.decipher.codes/Downloads.html) page of the package. 

### Options

* Confidence threshold: the confidence at which to truncate the output taxonomic classifications. Lower values of threshold will classify deeper into the taxonomic tree at the expense of accuracy, and vise-versa for higher values of threshold.


### Output

* Annotated OTU/ASV table


## References

* DECIPHER package: http://www2.decipher.codes/
* IDTAXA publication: https://microbiomejournal.biomedcentral.com/articles/10.1186/s40168-018-0521-5
