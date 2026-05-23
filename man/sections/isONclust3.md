# isONclust3

This module builds OTU representative sequences and an OTU table from long-read amplicon FASTQ files. It supports two platform-specific workflows:

* Oxford Nanopore reads, where each sample is quality- and length-filtered before pooling, clustered with isONclust3, oriented per cluster, optionally flipped by primer-majority vote, and polished with iterative minimap2 + Racon.
* PacBio HiFi reads, where each sample is quality- and length-filtered before pooling, clustered with isONclust3, oriented per cluster, optionally flipped by primer-majority vote, and represented by the oriented isONclust3 seed read.

The module does not perform taxonomy. The representative FASTA and OTU table can be passed to the existing SLIM taxonomic-assignment modules.

## Workflows

**Nanopore**

1. Raw Nanopore reads.
2. Quality filtering with `vsearch --fastq_maxee_rate`.
3. Length filtering with VSEARCH when a minimum and/or maximum length is set.
4. Sample pooling by concatenating retained reads.
5. OTU clustering with `isONclust3 --mode ont`.
6. One Racon seed draft per retained cluster, using the first isONclust3 cluster read.
7. Cluster reads are oriented to the seed with minimap2 PAF strand calls.
8. When a primer FASTA is supplied, the whole cluster is kept or reverse-complemented by primer-majority voting.
9. For clusters with at least two reads, minimap2 maps the oriented cluster reads to the oriented seed emitted by isONclust3, then Racon polishes from that seed. The minimap2 + Racon loop runs 1 to 4 times. Default: `3`. Singleton clusters skip Racon and keep the oriented seed directly.
10. Final Nanopore polished OTU representatives are written with plain sequential OTU IDs.

**PacBio HiFi**

1. Raw PacBio HiFi reads.
2. Quality filtering with `vsearch --fastq_maxee_rate`.
3. Length filtering with VSEARCH when a minimum and/or maximum length is set.
4. Sample pooling by concatenating retained reads.
5. OTU clustering with `isONclust3 --mode pacbio`.
6. One representative seed read per retained isONclust3 cluster, selected from the per-cluster FASTQ emitted by isONclust3.
7. Cluster reads are oriented to the seed with minimap2 PAF strand calls.
8. When a primer FASTA is supplied, the whole cluster and representative seed are kept or reverse-complemented by primer-majority voting.
9. Final PacBio cluster/OTU representatives.

For OTU-table counting, SLIM uses the sample prefix added to each pooled read header before clustering. Counts therefore come directly from retained isONclust3 cluster membership instead of remapping reads to the final representative FASTA.

Per-sample preparation steps are run in parallel when multiple input FASTQ files are provided. VSEARCH quality and length filtering are not effectively multithreaded in this workflow, so SLIM batches samples instead, launching up to 8 preparation jobs or the available core count, whichever is lower. Prepared sample metadata is loaded in the original input order before pooling reads for isONclust3.

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

SLIM does not perform primer trimming or chimera filtering in this module. Primer sequences, when supplied, are used only to orient retained clusters.

For Nanopore consensus polishing, the initial Racon draft is the first read in each isONclust3 cluster FASTQ after sample-level quality and length filtering. isONclust3 writes these per-cluster FASTQs from its sorted read order, so this is the seed exposed to SLIM. Cluster reads are first oriented to this seed with minimap2, then the whole cluster can be flipped by primer-majority vote before the iterative minimap2 + Racon polishing starts.

For PacBio HiFi, SLIM does not run a final SPOA consensus step. It uses the first read in each retained isONclust3 cluster FASTQ as the OTU representative after applying the same seed-orientation and optional primer-majority cluster flip.

**Quality filtering**

Default maximum expected error rate:

* Nanopore: `0.05`.
* PacBio: `0.01`.

This value is passed to VSEARCH as `--fastq_maxee_rate`. It is a per-base expected-error rate, so `0.05` means approximately 5% and `0.01` means approximately 1%.

**Length filtering**

Default: no minimum or maximum length filter.

Leave a field blank to disable that side of the length filter. Enter a minimum and/or maximum read length when the expected amplicon size is known.

**Primers fasta file (first sequence forward, second sequence reverse; IUPAC supported)**

Optional FASTA file containing the forward primer as the first sequence and the reverse primer as the second sequence. IUPAC ambiguity codes are supported by the exact primer-vote matcher.

The first primer record is always interpreted as the forward primer. The second primer record is interpreted as the reverse primer, and SLIM uses its reverse-complement when looking for the 3' primer site on forward-oriented sequences.

When a primer FASTA is supplied, SLIM scores each seed-oriented cluster by looking for forward evidence in the first third and reverse-complemented reverse-primer evidence in the last third. It also scores reverse evidence using the reverse primer in the first third and the reverse-complemented forward primer in the last third. If reverse evidence is greater than forward evidence, the whole cluster FASTQ and its seed representative are reverse-complemented. Ties, no-primer evidence, and ambiguous evidence keep the seed-oriented cluster unchanged and are recorded in the primer-orientation logs.

**Minimap2 + Racon iterations**

Default: `3`.

Nanopore only. The module allows `1` to `4` polishing iterations per retained cluster. Clusters with one retained read are not polished with Racon, because there is no within-cluster read support to improve the seed; SLIM keeps the isONclust3 representative seed instead.

## Outputs

**OTU table**

Default output: `otus-isonclust.tsv`.

A TSV table with OTU IDs as rows and samples as columns. Counts are generated from the sample prefixes in retained cluster read headers. OTU row names use plain sequential IDs such as `OTU1` and exactly match the representative FASTA headers.

**OTUs representative sequences**

Default output: `representative-isonclust.fasta`.

The final representative FASTA. Sequence IDs are normalized to `OTU1`, `OTU2`, etc., with no additional header annotations. The OTU table uses the exact same IDs and the module validates that both outputs contain exactly `OTU1` through `OTUN` before finishing.

**Run summary statistics**

Default output: `stats-isonclust.tsv`.

A TSV table with one row per input file. It reports the platform, raw input reads, reads after quality filtering, reads after length filtering, reads used after the final preparation step, final reads assigned to OTUs, isONclust3 settings, cluster counts, final OTU count, and Racon iteration count.

The main read-count columns represent the following filtering/counting stages:

* `raw_reads`: FASTQ reads in the original input file before any filtering.
* `quality_filtered_reads`: reads remaining after the first VSEARCH quality filter using `--fastq_maxee_rate`.
* `length_filtered_reads`: reads remaining after length filtering.
* `post_length_filter_reads`: reads retained for pooling after quality and length filtering.
* `final_assigned_reads`: retained reads from that sample that belong to retained isONclust3 clusters after the minimum-cluster-size filter. This equals the sum of that sample's column in `otus-isonclust.tsv` and can be lower than `post_length_filter_reads` when reads belong to discarded small clusters.

**Full results archive**

Default output: `results-isonclust.tar.gz`.

A `.tar.gz` archive containing filtered reads, cluster-orientation logs and FASTQs, primer-majority vote tables when primers are supplied, isONclust3 cluster files, Nanopore seed drafts, PacBio representative-read drafts, Racon polishing files for Nanopore, cluster sample-count tables, the final representative FASTA, the OTU table, and the stats table.

## More options

**Minimum reads per retained isONclust3 cluster**

Default: `5`.

Clusters supported by fewer reads are discarded before Nanopore Racon polishing or PacBio representative-read selection. If this is set to `1`, Nanopore singleton clusters are retained but are not passed through Racon.

## References

* isONclust3 GitHub: https://github.com/aljpetri/isONclust3
