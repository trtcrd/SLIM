class SingleMModule extends Module {
    constructor(params) {
        super("singleM", "/man/sections/SingleM.md");
        this.params = params;
    }

    onLoad() {
        super.onLoad();
        this.autofillPairedReads();

        file_manager.register_observer(() => {
            this.autofillPairedReads();
        });

        gui_file_updater.file_trigger();
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
}

module_manager.moduleCreators['singleM'] = (params) => {
    return new SingleMModule(params);
};
