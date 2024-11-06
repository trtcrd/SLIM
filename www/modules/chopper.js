
class ChopperModule extends Module {
	constructor (params) {
		super ("chopper", "https://github.com/wdecoster/chopper/tree/master");

		this.params = params;
	}

	onLoad () {
		super.onLoad();
		gui_file_updater.file_trigger();

		var that = this;
		var fastq = this.dom.getElementsByClassName('input_file_text')[0];
		fastq.onchange = () => {
			var idx = fastq.value.lastIndexOf('.');
			if (idx <= 0)
				return;
			let output_file = that.dom.getElementsByClassName('output_zone')[0].getElementsByTagName('input')[0];
			output_file.value = fastq.value.substr(0, fastq.value.lastIndexOf('.')) + '_filtered-chopper.fastq';
			output_file.onchange();
		};
	}
};


module_manager.moduleCreators.chopper = (params) => {
	return new ChopperModule(params);
};

