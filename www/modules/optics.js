
class opticsModule extends Module {
	constructor (params) {
		super ("optics", "https://github.com/BBaloglu/ASHURE/blob/master/README.md");

		this.params = params;
	}

	onLoad () {
		super.onLoad();
	}
};


module_manager.moduleCreators.optics = (params) => {
	return new opticsModule(params);
};

