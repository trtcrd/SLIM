# FASTA Assignment with IDTAXA

The `assignment-fasta-IDTAXA` module uses the IDTAXA classifier from the DECIPHER R package to assign taxonomy to sequences in a FASTA file.

## Inputs

### Trained IDTAXA Classifier

RData file containing a trained IDTAXA classifier. You can train your own classifier from a curated FASTA database or use a compatible pre-trained classifier.

### Input FASTA to Be Annotated

FASTA file containing the sequences to classify.

## Parameters

### Threshold

Default:

```
60
```

Confidence threshold used by IDTAXA. Lower values classify deeper into the taxonomy but may reduce accuracy. Higher values are more conservative and may stop assignments at higher taxonomic ranks.

## Output

### Annotated Sequences

Default:

```
idtaxa.tsv
```

TSV table containing the taxonomic assignment for each input sequence.

## Practical Advice

IDTAXA results depend strongly on the quality and taxonomic scope of the trained classifier. Use a classifier matching your marker gene and target group, for example 16S for bacteria/archaea, 18S for eukaryotes, ITS for fungi, or another marker-specific database.

## References

* DECIPHER package: http://www2.decipher.codes/
* IDTAXA documentation: http://www2.decipher.codes/Documentation/Documentation-ClassifySequences.html
* IDTAXA publication: https://microbiomejournal.biomedcentral.com/articles/10.1186/s40168-018-0521-5
