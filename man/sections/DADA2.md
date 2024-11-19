# DADA2

This module integrate the DADA2 workflow.

## Module interactions

### Main inputs

* The tag-to-sample file (.csv)

* The forward reads file(s). Fastq must be oriented and primers trimmed. For now, only paired-end fastq files are compatible. You can used the DTD module of SLIM for that (designed for multiplexed paired-end double tagged amplicons) 

* The reverse reads file(s). Fastq must be oriented and primers trimmed. 

* The strategy for training error(s) model(s) 

* The strategy for ASV inference, see Benjamin explanations [here](https://benjjneb.github.io/dada2/pseudo.html#pseudo-pooling). "no pool" (naive, fully de novo), pseudo-pool (2 steps, with prior from the first step used during the second step), pool (pooled sample for inference. If the strategy for error model training is by sample, this option has no effect.

### Output

* An ASV table (chimera-free, using the "consensus" mode) 

* A fasta file containing the ASV sequences 

* A table containing the filtering statistics 


## References

* DADA2 webpage: https://benjjneb.github.io/dada2/index.html
* DADA2 publication: https://www.nature.com/articles/nmeth.3869

## Known issue

On macOS, the DADA2 module returns: 
```Error in names(answer) <- names1 : 
  'names' attribute [30] must be the same length as the vector [10]
Calls: filterAndTrim -> mcmapply
In addition: Warning message:
In mclapply(seq_len(n), do_one, mc.preschedule = mc.preschedule,  :
  scheduled cores 2, 3, 4, 5, 6 did not deliver results, all values of the jobs will be affected
```
Docker v2.0.0.3
R version 3.6.0
dada2_1.12.1 

Seems to be a docker issue, as the script on macOS version of R runs it fine. 

