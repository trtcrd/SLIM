/* Helpers for preserving sample identity when a wildcard fans a module out.
 *
 * A literal `*` input creates one execution per matching sample.  `$` and `€`
 * are aggregate markers and deliberately do not fan out, so they are left alone.
 */

var wildcard_output_name = (input, output) => {
	let prefix = input.substring(0, input.indexOf('*'));
	let separator = prefix == '' || /[_\-.]$/.test(prefix) || /^[_\-.]/.test(output) ? '' : '_';

	return prefix + '*' + separator + output;
};


var aggregate_marker = (soft, input_id) => {
	if (input_id.startsWith('list_'))
		return '$';

	if (soft.name == 'DADA2')
		return '$';

	let text_aggregate_inputs = {
		'ashure': ['fastq'],
		'chopper': ['fastq'],
		'isONclust3': ['fastq'],
		'kraken2-bracken': ['reads', 'fwd', 'rev'],
		'mOTUs': ['reads', 'fwd', 'rev'],
		'map-to-targeted-reference': ['reads', 'fwd', 'rev'],
		'metaDMG': ['bam_pattern'],
		'msi': ['fastq'],
		'optics': ['fasta'],
		'singleM': ['fwd', 'rev']
	};

	return text_aggregate_inputs[soft.name] && text_aggregate_inputs[soft.name].includes(input_id) ? '€' : null;
};


exports.preserve_fanout_outputs = (params) => {
	let replacements = {};

	// Pipeline configuration keys are insertion ordered, matching the module order
	// in the UI.  Rewriting references as we go also propagates the wildcard into
	// each following per-sample module.
	for (let soft_id in params) {
		let soft = params[soft_id];
		if (!soft || !soft.params)
			continue;

		let inputs = soft.params.inputs || {};
		for (let input_id in inputs) {
			if (replacements[inputs[input_id]]) {
				let replacement = replacements[inputs[input_id]];
				let marker = aggregate_marker(soft, input_id);
				inputs[input_id] = marker ? replacement.replace('*', marker) : replacement;
			}
		}

		let fanout_input = Object.values(inputs).find((filename) =>
			typeof filename == 'string' && filename.includes('*'));

		if (!fanout_input)
			continue;

		let outputs = soft.params.outputs || {};
		for (let output_id in outputs) {
			let output = outputs[output_id];
			if (typeof output != 'string' || output == '' || output.includes('*'))
				continue;

			let wildcard_output = wildcard_output_name(fanout_input, output);
			outputs[output_id] = wildcard_output;
			replacements[output] = wildcard_output;
		}
	}

	return params;
};


exports.wildcard_output_name = wildcard_output_name;
