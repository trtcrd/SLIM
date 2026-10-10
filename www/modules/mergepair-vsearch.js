
class MergeVsearchModule extends Module {
	constructor (params) {
		super ("mergepair-vsearch", '/man/sections/Mergepair-vsearch.md');

		this.params = params;
	}

	onLoad () {
		super.onLoad();
		var that = this;

		// --- Inputs ---
		var inputs = this.dom.getElementsByClassName('input_file');
		this.fwd = inputs[0]; this.rev = inputs[1];
		this.fwd.onchange = this.rev.onchange = () => {that.input_change()};
	}

	input_change () {
		let fwd_prefix = this.pair_prefix(this.fwd.value, true);
		let rev_prefix = this.pair_prefix(this.rev.value, false);

		if (fwd_prefix != null && fwd_prefix == rev_prefix) {
			let output_file = this.dom.getElementsByClassName('output_zone')[0];
			output_file = output_file.getElementsByTagName('input')[0];
			let separator = fwd_prefix == '' || /[_\-.]$/.test(fwd_prefix) ? '' : '_';
			output_file.value = fwd_prefix + separator + 'merge-vsearch.fasta';
			output_file.onchange();
		}
	}

	pair_prefix (filename, forward) {
		let stem = filename.replace(/\.(fastq|fq)(\.gz)?$/i, '');
		let direction = forward ? '(?:R1|1|fwd|forward)' : '(?:R2|2|rev|reverse)';
		let match = stem.match(new RegExp('([._-])' + direction + '(?:[._-]001)?$', 'i'));

		return match ? stem.substring(0, match.index) : null;
	}
};


module_manager.moduleCreators['mergepair-vsearch'] = (params) => {
	return new MergeVsearchModule(params);
};
