
class AssignFastaVsearchModule extends Module {
	constructor (params) {
		super ("assignment-fasta-vsearch", "https://github.com/adriantich/SLIM/wiki/Fasta-assignment---Vsearch");
		this.params = params;
	}

	onLoad () {
		super.onLoad();

		var input = this.dom.getElementsByClassName('sequences')[0];
		var output = this.dom.getElementsByClassName('assigned')[0];

		input.onchange = () => {
			var idx = input.value.lastIndexOf('.');
			if (idx <= 0)
				return;
			var filename = input.value.substr(0, input.value.lastIndexOf('.'));
			output.value = filename + '_assigned-vsearch.tsv';
			output.onchange();
		};
	}
};

module_manager.moduleCreators['assignment-fasta-vsearch'] = (params) => {
	return new AssignFastaVsearchModule(params);
};

