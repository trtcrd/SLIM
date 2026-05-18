
class ashureModule extends Module {
	constructor (params) {
		super ("ashure", "/man/sections/ASHURE.md");

		this.params = params;
	}

	onLoad () {
		super.onLoad();
	}
};


module_manager.moduleCreators.ashure = (params) => {
	return new ashureModule(params);
};
