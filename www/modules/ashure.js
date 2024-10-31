
class ashureModule extends Module {
	constructor (params) {
		super ("ashure", "https://github.com/adriantich/SLIM/wiki/ASHURE");

		this.params = params;
	}

	onLoad () {
		super.onLoad();
	}
};


module_manager.moduleCreators.ashure = (params) => {
	return new ashureModule(params);
};

