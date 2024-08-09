
class LuluModule extends Module {
	constructor (params) {
		super ("lulu", "https://github.com/adriantich/SLIM/wiki/LULU-post-clustering-module");

		this.params = params;
	}

	onLoad () {
		super.onLoad();

		let otus_table = this.dom.getElementsByClassName('tsv')[0]
		let otus_lulu = this.dom.getElementsByClassName('output_zone')[0].getElementsByTagName('input')[0];

		let similarity = this.dom.getElementsByClassName('param_value')[0]
		let cooccurence = this.dom.getElementsByClassName('param_value')[1]

		otus_table.onchange = () => {
			var idx = otus_table.value.lastIndexOf('.');
			if (idx <= 0)
				return;
			otus_lulu.value = otus_table.value.substr(0, otus_table.value.lastIndexOf('.')) + '_lulu.tsv';
			otus_lulu.onchange();
		};
	}
};


module_manager.moduleCreators['lulu'] = (params) => {
	return new LuluModule(params);
};

