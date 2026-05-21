# isONclust-for-Nanopore-PacBio

This module builds OTU representative sequences and an OTU table from long-read amplicon FASTQ files. It supports two platform-specific workflows:

* Oxford Nanopore reads, where each noisy cluster uses the isONclust3 representative read as the initial draft and is polished with iterative minimap2 + Racon.
* PacBio HiFi reads, where reads are primer- and chimera-filtered before clustering, then each retained cluster is converted directly to a SPOA consensus.

The module does not perform taxonomy. The representative FASTA and OTU table can be passed to the existing SLIM taxonomic-assignment modules.

## Workflows

**Nanopore**

1. Raw Nanopore reads.
2. Quality filtering with `vsearch --fastq_maxee_rate`.
3. Optional length filtering with VSEARCH.
4. Sample pooling by concatenating filtered reads.
5. OTU clustering with `isONclust3 --mode ont`.
6. One Racon seed draft per retained cluster, using the first read in the isONclust3 cluster FASTQ as the module-visible isONclust3 representative.
7. 1 to 4 minimap2 + Racon polishing iterations per cluster, mapping reads back to the current draft each round. Default: `3`.
8. Primer-based reorientation of polished consensus sequences, when a primer FASTA is supplied.
9. Optional primer trimming on oriented polished consensus sequences with cutadapt, when a primer FASTA is supplied.
10. De novo chimera filtering on polished consensus sequences with `vsearch --uchime_denovo`.
11. Final Nanopore polished OTU representatives.

**PacBio HiFi**

1. Raw PacBio HiFi reads.
2. Quality filtering with `vsearch --fastq_maxee_rate`.
3. Optional length filtering with VSEARCH.
4. Optional primer trimming on raw HiFi reads with cutadapt, when a primer FASTA is supplied.
5. De novo chimera filtering on HiFi reads with `vsearch --uchime_denovo`.
6. Sample pooling by concatenating retained reads.
7. OTU clustering with `isONclust3 --mode pacbio`.
8. One SPOA consensus per retained isONclust3 cluster.
9. Primer-based reorientation and optional final primer trimming of representative sequences, when a primer FASTA is supplied.
10. Final PacBio cluster/OTU representatives.

For OTU-table counting, SLIM maps each sample's retained reads back to the final representative FASTA with minimap2. The preset is `map-ont` for Nanopore and `map-hifi` for PacBio.

## Inputs

**Input fastq files**

A FASTQ file or wildcard pattern. Examples:

```text
sample.fastq
*.fastq
barcode*_reads.fastq.gz
```

Wildcard groups made with the wildcard-creator module can also be used.

**Sequencing platform**

Default: `Nanopore`.

Nanopore uses `isONclust3 --mode ont` and minimap2 `-x map-ont`. PacBio uses `isONclust3 --mode pacbio` and minimap2 `-x map-hifi`.

The current isONclust3 command-line interface accepts `--mode` rather than separate `--k` and `--w` flags. `--mode ont` uses the ONT minimizer settings described upstream (`k=13`, `w=21`), while `--mode pacbio` uses the PacBio settings (`k=15`, `w=51`).

For Nanopore consensus polishing, the initial Racon draft is the first read in each isONclust3 cluster FASTQ. isONclust3 writes these per-cluster FASTQs from its sorted read order, so this is the representative exposed to SLIM. Primer orientation and trimming are deliberately applied after polishing, because Racon will not extend beyond the supplied target span.

**Quality filtering**

Default maximum expected error rate:

* Nanopore: `0.05`.
* PacBio: `0.01`.

This value is passed to VSEARCH as `--fastq_maxee_rate`. It is a per-base expected-error rate, so `0.05` means approximately 5% and `0.01` means approximately 1%.

**Length filtering**

Default: no minimum or maximum length filter.

Leave a field blank to disable that side of the length filter. Enter a minimum and/or maximum read length when the expected amplicon size is known.

**Primers fasta file (first sequence forward, second sequence reverse; IUPAC supported)**

Optional FASTA file containing the forward primer as the first sequence and the reverse primer as the second sequence. cutadapt handles IUPAC ambiguity codes in adapter/primer sequences.

The first primer record is always interpreted as the forward primer. The second primer record is interpreted as the reverse primer, and SLIM uses its reverse-complement when looking for the 3' primer site on forward-oriented sequences.

When a primer FASTA is supplied, final representative sequences are oriented before OTU ID normalization. SLIM uses the MSI-style linked primer patterns `forward...reverse-complement(reverse)` and `reverse...reverse-complement(forward)` to label orientation with cutadapt when available, then explicitly reverse-complements reverse-labelled records before optional trimming. If the installed cutadapt lacks `--action=none`, SLIM falls back to exact IUPAC-aware orientation before optional trimming. Primer trimming is enabled by default and can be disabled in the module options. When enabled, SLIM trims the forward primer and reverse-complemented reverse primer independently, and keeps records even when one or both primer matches are not found. When minimum and/or maximum length filters are set, the same length window is also applied to Nanopore representative sequences after primer trimming, similar to MSI's centroid filtering.

**Minimap2 + Racon iterations**

Default: `3`.

Nanopore only. The module allows `1` to `4` polishing iterations per retained cluster.

## Outputs

**OTU table**

A TSV table with OTU IDs as rows and samples as columns. Counts are generated by mapping each sample's retained reads to the final representative FASTA with minimap2, keeping the best representative hit for each read, and counting reads per OTU. Candidate representatives with zero final read assignments are removed, then the representative FASTA and OTU table are rewritten together with consecutive `OTU1`, `OTU2`, etc. identifiers.

**OTUs representative sequences**

The final representative FASTA. Sequence IDs are normalized to `OTU1`, `OTU2`, etc. The OTU table uses the exact same IDs and the module validates that the FASTA and table match before finishing.

**Run summary statistics**

A TSV table with one row per input file. It reports the platform, raw input reads, reads after quality filtering, reads after length filtering, reads retained after chimera filtering, final reads assigned to OTUs, isONclust3 settings, cluster counts, final OTU count, and Racon iteration count.

For Nanopore, read-level chimera filtering is not part of the workflow, so the `chimera_filtered_reads` column matches the length-filtered read count. Nanopore chimera filtering is performed on the polished representative sequences.

**Full results archive**

A `.tar.gz` archive containing filtered reads, primer-orientation and primer-trimming logs and outputs, chimera-filtering intermediates, isONclust3 cluster files, Nanopore seed drafts, PacBio SPOA drafts, Racon polishing files for Nanopore, OTU-count minimap2 mappings, the final representative FASTA, the OTU table, and the stats table.

## More options

**Primer max error rate**

Default: `0.20`.

This is passed to cutadapt as its maximum allowed error rate for matching primers.

**Primer trimming**

Default: enabled.

When enabled and a primer FASTA is supplied, SLIM trims primers from PacBio HiFi reads before chimera filtering and from final oriented representatives before OTU ID normalization. When disabled, primer sequences are still used for final representative orientation, but trimming is skipped.

**Minimum reads per retained isONclust3 cluster**

Default: `5`.

Clusters supported by fewer reads are discarded before Nanopore Racon polishing or PacBio SPOA consensus generation.

**SPOA scoring**

PacBio only. Defaults:

* Match: `1`.
* Mismatch: `-8`.
* Gap open: `-6`.
* Gap extend: `-2`.

The PacBio HiFi defaults use a stronger mismatch penalty to take advantage of the higher per-base accuracy.

## References

* isONclust3 GitHub: https://github.com/aljpetri/isONclust3
* SPOA GitHub: https://github.com/rvaser/spoa
