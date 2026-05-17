class Kraken2BrackenModule extends Module {
    constructor(params) {
        super("kraken2-bracken");
        this.params = params;
    }

    onLoad() {
        super.onLoad();
        gui_file_updater.file_trigger();
        this.updateMode();

        let mode = this.dom.querySelector('select[name="mode"]');
        mode.onchange = () => {
            this.updateMode();
        };
    }

    updateMode() {
        let mode = this.dom.querySelector('select[name="mode"]').value;
        let reads = this.dom.getElementsByClassName('single_reads')[0];
        let paired = this.dom.getElementsByClassName('paired_reads')[0];

        reads.style.display = mode == 'paired' ? 'none' : '';
        paired.style.display = mode == 'paired' ? '' : 'none';
    }

    getConfiguration() {
        let config = super.getConfiguration();

        if (config.params.mode == 'paired') {
            delete config.inputs.reads;
        } else {
            delete config.inputs.fwd;
            delete config.inputs.rev;
        }

        return config;
    }
}

module_manager.moduleCreators['kraken2-bracken'] = (params) => {
    return new Kraken2BrackenModule(params);
};
