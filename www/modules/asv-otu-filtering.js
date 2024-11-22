
class OtuFilteringModule extends Module {
	constructor (params) {
		super ("asv-otu-filtering", "https://github.com/adriantich/SLIM/blob/master/man/sections/OTU-filtering.md");

		this.params = params;
	}

	onLoad () {
		super.onLoad();

		var ins = this.dom.getElementsByClassName('input_file');
		var outs = this.dom.getElementsByClassName('output_zone');
		var threshold_input = this.dom.getElementsByClassName('param_value')[0];

		threshold_input.onchange = () => {
			matrix.onchange();
			centroids.onchange();
			reads.onchange();
		};

		// OTU matrix io
		var matrix = ins[0];
		var matrix_out = outs[0].getElementsByTagName('input')[0];
		matrix.onchange = () => {
			var idx = matrix.value.lastIndexOf('.');
			if (idx <= 0)
				return;
			var threshold = threshold_input.value;
			let name = matrix.value.substr(0, matrix.value.lastIndexOf('.'));
			matrix_out.value = name + '_filtered_' + threshold + '.tsv';
			matrix_out.onchange();
		};

		// Centroids fasta io
		var centroids = ins[1];
		var centroids_out = outs[1].getElementsByTagName('input')[0];
		centroids.onchange = () => {
			var idx = centroids.value.lastIndexOf('.');
			if (idx <= 0)
				return;
			var threshold = threshold_input.value;
			let name = centroids.value.substr(0, centroids.value.lastIndexOf('.'));
			centroids_out.value = name + '_filtered_' + threshold + '.fasta';
			centroids_out.onchange();
		};

		// Clusterised reads fasta io
		var reads = ins[2];
		var reads_out = outs[2].getElementsByTagName('input')[0];
		reads.onchange = () => {
			var idx = reads.value.lastIndexOf('.');
			if (idx <= 0)
				return;
			var threshold = threshold_input.value;
			let name = reads.value.substr(0, reads.value.lastIndexOf('.'));
			reads_out.value = name + '_filtered_' + threshold + '.fasta';
			reads_out.onchange();
		};
	}

	getConfiguration () {
		let conf = super.getConfiguration();

		if (conf.inputs.centroids == '')
			delete conf.inputs.centroids;
		if (conf.inputs.reads == '')
			delete conf.inputs.reads;

		return conf;
	}
};


module_manager.moduleCreators['asv-otu-filtering'] = (params) => {
	return new OtuFilteringModule(params);
};
