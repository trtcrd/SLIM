class MetaDMGModule extends Module {
    constructor(params) {
        super("metaDMG", "/man/sections/metaDMG.md");
        this.params = params;
    }

    onLoad() {
        super.onLoad();
        gui_file_updater.file_trigger();
    }
}

module_manager.moduleCreators['metaDMG'] = (params) => {
    return new MetaDMGModule(params);
};
