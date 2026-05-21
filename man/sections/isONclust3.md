# isONclust3

This module builds OTU representative sequences and an OTU table from long-read amplicon FASTQ files. It supports two platform-specific workflows:

* Oxford Nanopore reads, where each sample can optionally be filtered with experimental YACRD read/chimera filtering before pooling, then clustered with isONclust3 and polished with iterative minimap2 + Racon.
* PacBio HiFi reads, where reads can be primer-trimmed, length-filtered, and optionally filtered with experimental YACRD read/chimera filtering per sample before clustering, then each retained cluster contributes the representative read emitted by isONclust3.

The module does not perform taxonomy. The representative FASTA and OTU table can be passed to the existing SLIM taxonomic-assignment modules.

## Workflows

**Nanopore**

1. Raw Nanopore reads.
2. Quality filtering with `vsearch --fastq_maxee_rate`.
3. Optional length filtering with VSEARCH.
4. Optional sample-level chimera/read-coverage filtering with minimap2 all-vs-all overlaps and YACRD.
5. Sample pooling by concatenating retained reads.
6. OTU clustering with `isONclust3 --mode ont`.
7. One Racon seed draft per retained cluster, using the first isONclust3 cluster read as the module-visible isONclust3 representative.
8. 1 to 4 minimap2 + Racon polishing iterations per cluster, mapping retained cluster reads back to the current draft each round. Default: `3`. Singleton clusters skip Racon and keep the representative seed directly.
9. Primer-based reorientation of polished consensus sequences, when a primer FASTA is supplied.
10. Optional primer trimming on oriented polished consensus sequences with cutadapt, when a primer FASTA is supplied.
11. Final Nanopore polished OTU representatives.

**PacBio HiFi**

1. Raw PacBio HiFi reads.
2. Quality filtering with `vsearch --fastq_maxee_rate`.
3. Optional primer trimming on quality-filtered HiFi reads with cutadapt, when a primer FASTA is supplied.
4. Optional length filtering with VSEARCH after primer trimming.
5. Optional sample-level chimera/read-coverage filtering on primer-aware, length-filtered HiFi reads with minimap2 all-vs-all overlaps and YACRD.
6. Sample pooling by concatenating retained reads.
7. OTU clustering with `isONclust3 --mode pacbio`.
8. One representative read per retained isONclust3 cluster, selected from the per-cluster FASTQ emitted by isONclust3.
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

YACRD uses all-vs-all read overlaps to classify reads as non-chimeric, chimeric, or not covered. It does not consume an OTU abundance table directly; abundance affects the inference indirectly through overlap coverage. For this reason, SLIM runs YACRD on per-sample read sets rather than on final OTU representatives. This follows YACRD's intended input shape while keeping samples independent before pooling. Because YACRD was developed and benchmarked for long-read genome assembly rather than amplicon OTU inference, its output should be treated as an experimental chimera/read-coverage filter for amplicon datasets and checked against positive controls or mock communities when possible. YACRD filtering is disabled by default and must be explicitly enabled in the module options.

For Nanopore consensus polishing, the initial Racon draft is the first read in each isONclust3 cluster FASTQ after optional sample-level YACRD filtering. isONclust3 writes these per-cluster FASTQs from its sorted read order, so this is the representative exposed to SLIM. Primer orientation and trimming are deliberately applied after polishing, because Racon will not extend beyond the supplied target span.

For PacBio HiFi, SLIM does not run a final SPOA consensus step. It uses the first read in each retained isONclust3 cluster FASTQ as the OTU representative, then applies the same optional primer-based orientation and trimming as for Nanopore representatives.

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

When a primer FASTA is supplied, final representative sequences are oriented before OTU ID normalization. SLIM uses the MSI-style linked primer patterns `forward...reverse-complement(reverse)` and `reverse...reverse-complement(forward)` to label orientation with cutadapt when available, then explicitly reverse-complements reverse-labelled records before optional trimming. If the installed cutadapt lacks `--action=none`, SLIM falls back to exact IUPAC-aware orientation before optional trimming. Representatives with no primer evidence or ambiguous forward/reverse evidence are kept unchanged and annotated in the orientation log rather than dropped. Primer trimming is enabled by default and can be disabled in the module options. When enabled, SLIM trims the forward primer and reverse-complemented reverse primer independently, and keeps records even when one or both primer matches are not found. When minimum and/or maximum length filters are set, the same length window is also applied to Nanopore representative sequences after primer trimming, similar to MSI's centroid filtering.

**Minimap2 + Racon iterations**

Default: `3`.

Nanopore only. The module allows `1` to `4` polishing iterations per retained cluster. Clusters with one retained read are not polished with Racon, because there is no within-cluster read support to improve the seed; SLIM keeps the isONclust3 representative seed instead.

## Outputs

**OTU table**

Default output: `otus-isonclust.tsv`.

A TSV table with OTU IDs as rows and samples as columns. Counts are generated by mapping each sample's retained reads to the final representative FASTA with minimap2, keeping the best representative hit for each read, and counting reads per OTU. Candidate representatives with zero final read assignments are removed, then the representative FASTA and OTU table are rewritten together with consecutive `OTU1`, `OTU2`, etc. identifiers.

**OTUs representative sequences**

Default output: `representative-isonclust.fasta`.

The final representative FASTA. Sequence IDs are normalized to `OTU1`, `OTU2`, etc. The OTU table uses the exact same IDs and the module validates that the FASTA and table match before finishing.

**Run summary statistics**

Default output: `stats-isonclust.tsv`.

A TSV table with one row per input file. It reports the platform, raw input reads, reads after quality filtering, reads after length filtering, reads retained after chimera filtering, final reads assigned to OTUs, isONclust3 settings, cluster counts, final OTU count, and Racon iteration count.

For Nanopore and PacBio, the `chimera_filtered_reads` column reports reads retained after optional sample-level YACRD filtering. These retained reads are also used for the final read-to-OTU counting step.

If YACRD filtering is disabled, `chimera_filtered_reads` matches the reads retained after quality, primer, and length filtering.

The `final_assigned_reads` column is the number of retained reads from that sample that map back to at least one final representative sequence during OTU-table creation. SLIM assigns each mapped read to its best representative hit, counts those assignments per OTU, and sums the sample's OTU-table column. This value can be lower than `chimera_filtered_reads` when retained reads do not align to any final representative.

**Full results archive**

Default output: `results-isonclust.tar.gz`.

A `.tar.gz` archive containing filtered reads, primer-orientation and primer-trimming logs and outputs, YACRD reports and overlap mappings when enabled, isONclust3 cluster files, Nanopore seed drafts, PacBio representative-read drafts, Racon polishing files for Nanopore, OTU-count minimap2 mappings, the final representative FASTA, the OTU table, and the stats table.

## More options

**Primer max error rate**

Default: `0.20`.

This is passed to cutadapt as its maximum allowed error rate for matching primers.

**Primer trimming**

Default: enabled.

When enabled and a primer FASTA is supplied, SLIM trims primers from PacBio HiFi reads before length filtering and chimera filtering, and from final oriented representatives before OTU ID normalization. When disabled, primer sequences are still used for final representative orientation, but trimming is skipped.

**YACRD filtering**

Default: disabled.

When enabled, SLIM runs minimap2 all-vs-all overlap mapping per sample and uses YACRD `filter` to remove reads marked `Chimeric` or `NotCovered`. This step is experimental for amplicon data and should be treated with caution: benchmark it with mock communities, positive controls, or side-by-side runs before using it as the default filtering decision.

**YACRD minimum overlap coverage**

Default:

* Nanopore: `4`.
* PacBio: `3`.

This is passed to YACRD as `-c`. SLIM uses minimap2 `-x ava-ont -g 500` for Nanopore sample reads and `-x ava-pb -g 5000` for PacBio HiFi sample reads.

**YACRD minimum covered read fraction**

Default: `0.4`.

This is passed to YACRD as `-n`. Reads with insufficient covered length are filtered as `NotCovered` by YACRD. If a sample has too few reads to support the requested overlap coverage, SLIM keeps that read set unfiltered and records the reason in the module log.

**Minimum reads per retained isONclust3 cluster**

Default: `5`.

Clusters supported by fewer reads are discarded before Nanopore Racon polishing or PacBio representative-read selection. If this is set to `1`, Nanopore singleton clusters are retained but are not passed through Racon.

## References

* isONclust3 GitHub: https://github.com/aljpetri/isONclust3
* YACRD GitHub: https://github.com/natir/yacrd
