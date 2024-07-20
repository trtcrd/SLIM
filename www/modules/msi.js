
class msiModule extends Module {
	constructor (params) {
		super ("msi", "https://github.com/nunofonseca/msi?tab=readme-ov-file#Overview");

		this.params = params;
	}

	onLoad () {
		super.onLoad();
	}

};


module_manager.moduleCreators.msi = (params) => {
	return new msiModule(params);
};

