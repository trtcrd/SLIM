
class opticsModule extends Module {
	constructor (params) {
		super ("optics", "/man/sections/OPTICS.md");

		this.params = params;
	}

	onLoad () {
		super.onLoad();
	}
};


module_manager.moduleCreators.optics = (params) => {
	return new opticsModule(params);
};
