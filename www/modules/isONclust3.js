class Isonclust3Module extends Module {
    constructor(params) {
        super("isONclust3", "/man/sections/isONclust3.md");
        this.params = params;
    }

    onLoad() {
        super.onLoad();
        this.setupPlatformDefaults();
        this.autofillFastqWildcard();

        file_manager.register_observer(() => {
            this.autofillFastqWildcard();
        });

        gui_file_updater.file_trigger();
    }

    autofillFastqWildcard() {
        const input = this.dom.querySelector('input[name="fastq"]');
        if (!input || !this.shouldAutofillFastq(input))
            return;

        const wildcard = file_manager.getFiles(['fastq', 'fq'])
            .filter((filename) => {
                return typeof filename == "string" &&
                    (filename.includes("*") || filename.includes("€"));
            })
            .map((filename) => filename.replace("€", "*"))[0];

        if (wildcard) {
            input.value = wildcard;
            if (input.onchange)
                input.onchange();
        }
    }

    shouldAutofillFastq(input) {
        return input.value == "" ||
            input.value == "*.fastq" ||
            input.value == "*.fq" ||
            input.value == "*.fastq.gz" ||
            input.value == "*.fq.gz";
    }

    setupPlatformDefaults() {
        const defaults = {
            nanopore: {
                maxee_rate: "0.05"
            },
            pacbio: {
                maxee_rate: "0.01"
            }
        };

        const platformInputs = this.dom.querySelectorAll('input[name="platform"]');
        const platformSensitiveNames = Object.keys(defaults.nanopore);
        const nanoporeOnly = this.dom.getElementsByClassName('nanopore_only');
        const pacbioOnly = this.dom.getElementsByClassName('pacbio_only');

        const currentPlatform = () => {
            const checked = this.dom.querySelector('input[name="platform"]:checked');
            return checked ? checked.value : "nanopore";
        };

        const applyDefaults = (previousPlatform) => {
            const selected = currentPlatform();

            for (const name of platformSensitiveNames) {
                const input = this.dom.querySelector('[name="' + name + '"]');
                if (!input)
                    continue;

                const previousDefault = previousPlatform ? defaults[previousPlatform][name] : undefined;
                if (input.value === "" || (previousDefault && input.value === previousDefault))
                    input.value = defaults[selected][name];
            }

            for (let idx = 0; idx < nanoporeOnly.length; idx++)
                nanoporeOnly[idx].style.display = selected === "nanopore" ? "" : "none";

            for (let idx = 0; idx < pacbioOnly.length; idx++)
                pacbioOnly[idx].style.display = selected === "pacbio" ? "" : "none";
        };

        let previousPlatform = currentPlatform();
        applyDefaults(previousPlatform === "pacbio" ? "nanopore" : null);

        for (let idx = 0; idx < platformInputs.length; idx++) {
            platformInputs[idx].onchange = () => {
                applyDefaults(previousPlatform);
                previousPlatform = currentPlatform();
            };
        }
    }

    getConfiguration() {
        let config = super.getConfiguration();

        if (!config.inputs.primers)
            delete config.inputs.primers;

        return config;
    }
}

module_manager.moduleCreators['isONclust3'] = (params) => {
    return new Isonclust3Module(params);
};
