
class DereplicationModule extends Module {
	constructor (params) {
		super ("fasta-dereplication", 'https://github.com/adriantich/SLIM/wiki/Fasta-dereplication');

		this.params = params;
	}

	onLoad () {
		super.onLoad();

		var that = this;
		var fasta = this.dom.getElementsByClassName('input_file')[0];
		fasta.onchange = () => {
			var idx = fasta.value.lastIndexOf('.');
			if (idx <= 0)
				return;
			let derep = that.dom.getElementsByClassName('output_zone')[0].getElementsByTagName('input')[0];
			derep.value = fasta.value.substr(0, fasta.value.lastIndexOf('.')) + '_derep.fasta';
			derep.onchange();
		};
	}
};


module_manager.moduleCreators['fasta-dereplication'] = (params) => {
	return new DereplicationModule(params);
};

