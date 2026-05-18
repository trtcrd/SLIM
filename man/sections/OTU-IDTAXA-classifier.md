# ASV/OTU Table Assignment with IDTAXA

The `assignment-table-IDTAXA` module uses the IDTAXA classifier from the DECIPHER R package to assign taxonomy to representative ASV/OTU sequences, then appends the assignments to an ASV/OTU table.

## Inputs

### Trained IDTAXA Classifier

RData file containing a trained IDTAXA classifier.

### ASV/OTU Representative Sequences

FASTA file containing one representative sequence for each ASV/OTU in the table.

### Input ASV/OTU Table

TSV count table to annotate. Each ASV/OTU in the table must have a matching sequence in the representative FASTA file.

## Parameters

### Threshold

Default:

```
60
```

Confidence threshold used by IDTAXA. Lower values classify deeper into the taxonomy but may reduce accuracy. Higher values are more conservative and may stop assignments at higher taxonomic ranks.

## Output

### Annotated ASV/OTU Table

Default:

```
idtaxa.tsv
```

TSV table containing the original ASV/OTU table with added taxonomic assignments.

## Practical Advice

Use this module when you want to keep abundance counts and IDTAXA taxonomy together. Use `assignment-fasta-IDTAXA` if you only need a sequence-to-taxonomy table.

## References

* DECIPHER package: http://www2.decipher.codes/
* IDTAXA documentation: http://www2.decipher.codes/Documentation/Documentation-ClassifySequences.html
* IDTAXA publication: https://microbiomejournal.biomedcentral.com/articles/10.1186/s40168-018-0521-5
