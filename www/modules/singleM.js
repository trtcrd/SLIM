class SingleMModule extends Module {
    constructor(params) {
        super("singleM");
        this.params = params;
    }
}

module_manager.moduleCreators['singleM'] = (params) => {
    return new SingleMModule(params);
};
