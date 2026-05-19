class NanoporeConsensusModule extends Module {
    constructor(params) {
        super("nanopore-consensus", "/man/sections/Nanopore-consensus.md");
        this.params = params;
    }

    onLoad() {
        super.onLoad();
        gui_file_updater.file_trigger();
    }

    getConfiguration() {
        let config = super.getConfiguration();

        if (!config.inputs.primers)
            delete config.inputs.primers;

        return config;
    }
}

module_manager.moduleCreators['nanopore-consensus'] = (params) => {
    return new NanoporeConsensusModule(params);
};
