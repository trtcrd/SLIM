const assert = require('node:assert/strict');
const test = require('node:test');

const wildcards = require('./pipeline_wildcards.js');


test('adds sample-preserving outputs throughout an Illumina fan-out pipeline', () => {
	let pipeline = {
		0: {
			name: 'wildcard-creator',
			params: {
				inputs: {},
				outputs: {joker: 'sample*_R1.fastq'},
				params: {archive_joker: 'sample*_R1.fastq'}
			}
		},
		1: {
			name: 'mergepair-vsearch',
			params: {
				inputs: {fwd: 'sample*_R1.fastq', rev: 'sample*_R2.fastq'},
				outputs: {assembly: 'merge-vsearch.fasta'},
				params: {}
			}
		},
		2: {
			name: 'fasta-remove-ambiguous-reads',
			params: {
				inputs: {fasta: 'merge-vsearch.fasta'},
				outputs: {cleaned: 'noN.fasta'},
				params: {}
			}
		},
		3: {
			name: 'swarm3',
			params: {
				inputs: {list_0_0: 'noN.fasta'},
				outputs: {otus_table: 'otus.tsv'},
				params: {}
			}
		}
	};

	wildcards.preserve_fanout_outputs(pipeline);

	assert.equal(pipeline[1].params.outputs.assembly, 'sample*_merge-vsearch.fasta');
	assert.equal(pipeline[2].params.inputs.fasta, 'sample*_merge-vsearch.fasta');
	assert.equal(pipeline[2].params.outputs.cleaned, 'sample*_noN.fasta');
	assert.equal(pipeline[3].params.inputs.list_0_0, 'sample$_noN.fasta');
	assert.equal(pipeline[3].params.outputs.otus_table, 'otus.tsv');
});


test('keeps explicit wildcard outputs unchanged', () => {
	let pipeline = {
		0: {
			name: 'mergepair-vsearch',
			params: {
				inputs: {fwd: 'tag_to_sample*_fwd.fastq', rev: 'tag_to_sample*_rev.fastq'},
				outputs: {assembly: 'tag_to_sample*_merge-vsearch.fasta'},
				params: {}
			}
		}
	};

	wildcards.preserve_fanout_outputs(pipeline);
	assert.equal(pipeline[0].params.outputs.assembly, 'tag_to_sample*_merge-vsearch.fasta');
});


test('does not alter Nanopore and PacBio aggregate inputs', () => {
	for (let aggregate_marker of ['$', '€']) {
		let pipeline = {
			0: {
				name: 'isONclust3',
				params: {
					inputs: {fastq: 'nanopore' + aggregate_marker + '.fastq'},
					outputs: {clusters: 'clusters.tsv'},
					params: {}
				}
			}
		};

		wildcards.preserve_fanout_outputs(pipeline);
		assert.equal(pipeline[0].params.outputs.clusters, 'clusters.tsv');
	}
});


test('keeps clustering modules as one aggregate execution with global outputs', () => {
	let pipeline = {
		0: {
			name: 'fasta-remove-ambiguous-reads',
			params: {
				inputs: {fasta: 'sample*_merged.fasta'},
				outputs: {cleaned: 'cleaned.fasta'},
				params: {}
			}
		},
		1: {
			name: 'otu-vsearch',
			params: {
				inputs: {list_0_0: 'cleaned.fasta'},
				outputs: {otus_table: 'otus-vsearch.tsv'},
				params: {}
			}
		},
		2: {
			name: 'swarm3',
			params: {
				inputs: {list_0_0: 'cleaned.fasta'},
				outputs: {otus_table: 'otus-swarm.tsv'},
				params: {}
			}
		}
	};

	wildcards.preserve_fanout_outputs(pipeline);

	assert.equal(pipeline[0].params.outputs.cleaned, 'sample*_cleaned.fasta');
	assert.equal(pipeline[1].params.inputs.list_0_0, 'sample$_cleaned.fasta');
	assert.equal(pipeline[1].params.outputs.otus_table, 'otus-vsearch.tsv');
	assert.equal(pipeline[2].params.inputs.list_0_0, 'sample$_cleaned.fasta');
	assert.equal(pipeline[2].params.outputs.otus_table, 'otus-swarm.tsv');
});


test('keeps text-input OTU/ASV modules as one aggregate execution', () => {
	let pipeline = {
		0: {
			name: 'isONclust3',
			params: {
				inputs: {fastq: 'sample€_sub.fastq'},
				outputs: {otus_table: 'otus-isonclust.tsv'},
				params: {}
			}
		},
		1: {
			name: 'DADA2',
			params: {
				inputs: {fwd: 'sample$_R1.fastq', rev: 'sample$_R2.fastq'},
				outputs: {asvs_tab: 'asvs-table.tsv'},
				params: {}
			}
		},
		2: {
			name: 'optics',
			params: {
				inputs: {fasta: 'sample€_cleaned.fasta'},
				outputs: {otutab: 'otus-optics.tsv'},
				params: {}
			}
		}
	};

	wildcards.preserve_fanout_outputs(pipeline);

	assert.equal(pipeline[0].params.inputs.fastq, 'sample€_sub.fastq');
	assert.equal(pipeline[0].params.outputs.otus_table, 'otus-isonclust.tsv');
	assert.equal(pipeline[1].params.inputs.fwd, 'sample$_R1.fastq');
	assert.equal(pipeline[1].params.inputs.rev, 'sample$_R2.fastq');
	assert.equal(pipeline[1].params.outputs.asvs_tab, 'asvs-table.tsv');
	assert.equal(pipeline[2].params.inputs.fasta, 'sample€_cleaned.fasta');
	assert.equal(pipeline[2].params.outputs.otutab, 'otus-optics.tsv');
});
