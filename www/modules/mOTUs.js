class MOTUsModule extends Module {
    constructor(params) {
        super("mOTUs", "/man/sections/mOTUs.md");
        this.params = params;
    }

    onLoad() {
        super.onLoad();
        this.autofillPairedReads();

        file_manager.register_observer(() => {
            this.autofillPairedReads();
        });

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

    autofillPairedReads() {
        let pair = file_manager.getPairedReadPatterns(['fastq']);
        if (!pair)
            return;

        let fwd = this.dom.querySelector('input[name="fwd"]');
        let rev = this.dom.querySelector('input[name="rev"]');

        if (fwd && this.shouldAutofillPattern(fwd))
            fwd.value = pair.fwd;
        if (rev && this.shouldAutofillPattern(rev))
            rev.value = pair.rev;
    }

    shouldAutofillPattern(input) {
        return input.value == '' ||
            input.value == '*_R1.fastq.gz' ||
            input.value == '*_R2.fastq.gz';
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

module_manager.moduleCreators['mOTUs'] = (params) => {
    return new MOTUsModule(params);
};
