class TargetedReferenceBuilderModule extends Module {
    constructor(params) {
        super("targeted-reference-builder", "/man/sections/Targeted-reference-builder.md");
        this.params = params;
    }

    onLoad() {
        super.onLoad();
        gui_file_updater.file_trigger();
    }
}

module_manager.moduleCreators['targeted-reference-builder'] = (params) => {
    return new TargetedReferenceBuilderModule(params);
};
