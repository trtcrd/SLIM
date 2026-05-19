# metaDMG

The `metaDMG` module estimates DNA damage patterns from BAM/SAM/CRAM files using metaDMG-cpp.

This module is intended for ancient-DNA authentication after mapping reads to a reference. It is not a taxonomic profiler by itself.

## Input

### BAM/SAM/CRAM Pattern

Default:

```text
*_targeted.bam
```

BAM files should contain `MD:Z` tags. The `map-to-targeted-reference` module adds these tags with `samtools calmd`.

### Reference FASTA

Default:

```text
targeted_reference.fna
```

Required for CRAM input and useful for provenance. BAM input can often run without passing a FASTA, but SLIM keeps the field visible because it is part of the targeted-reference workflow.

### acc2tax Table

Default:

```text
targeted_reference.acc2tax.tsv
```

Used only when metaDMG is run in taxid mode.

## Outputs

### metaDMG Summary

Default:

```text
metaDMG.summary.tsv
```

Small SLIM summary table listing each sample and the corresponding metaDMG output prefix.

### metaDMG Results Archive

Default:

```text
metaDMG_results.tar.gz
```

Archive containing `.bdamage.gz`, `.stat.gz`, `.rlens.gz`, `.dfit...` outputs, and the SLIM summary.

## Parameters

| Parameter | Default | Meaning |
| --- | --- | --- |
| Output prefix | `metaDMG` | Prefix used for metaDMG output files inside the archive. |
| Damage mode | `local, per reference` | `global` produces one estimate for the BAM, `local` estimates per reference, `taxid` groups references through `acc2tax`. |
| Minimum read length | `35` | Reads shorter than this are ignored by metaDMG. |
| Positions at read termini | `5` | Number of positions used to estimate terminal damage. |
| Minimum ANI | `-1` | Disabled by default. When set, filters alignments by estimated ANI. |
| Maximum ANI | empty | Disabled by default. |
| Fit detail | `0` | Controls extra dfit columns. Higher values add more detail and larger outputs. |
| Bootstrap iterations | `0` | `0` keeps the default beta-binomial optimization. |
| Library type | `ds` | Double-stranded by default; choose `ss` for single-stranded libraries. |

## Workflow Example

```text
kraken2-bracken
-> targeted-reference-builder
-> map-to-targeted-reference
-> metaDMG
```

For ancient metagenomic data, this targeted workflow is much lighter than mapping against all RefSeq.

## References

* metaDMG-cpp GitHub: https://github.com/metaDMG-dev/metaDMG-cpp
* metaDMG getdamage/dfit options: https://github.com/metaDMG-dev/metaDMG-cpp#usage
