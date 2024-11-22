
class opticsModule extends Module {
	constructor (params) {
		super ("optics", "https://github.com/adriantich/SLIM/blob/master/man/sections/OPTICS.md");

		this.params = params;
	}

	onLoad () {
		super.onLoad();
	}
};


module_manager.moduleCreators.optics = (params) => {
	return new opticsModule(params);
};

