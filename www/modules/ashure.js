
class ashureModule extends Module {
	constructor (params) {
		super ("ashure", "https://github.com/BBaloglu/ASHURE/blob/master/README.md");

		this.params = params;
	}

	onLoad () {
		super.onLoad();
	}
};


module_manager.moduleCreators.ashure = (params) => {
	return new ashureModule(params);
};

