class SingleMModule extends Module {
    constructor(params) {
        super("singleM", "/man/sections/SingleM.md");
        this.params = params;
    }
}

module_manager.moduleCreators['singleM'] = (params) => {
    return new SingleMModule(params);
};
