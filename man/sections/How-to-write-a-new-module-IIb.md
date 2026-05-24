# How to Write a New Module II: ASHURE Module Scripts

This page continues the ASHURE example and explains how the browser module, server module, and bash wrapper fit together.

## File Layout

ASHURE uses the standard SLIM module layout:

```text
www/modules/ashure.html
www/modules/ashure.js
server/modules/ashure.js
lib/bash_scripts/run_ashure.sh
```

The browser files define the interface. The server file converts selected fields into command arguments. The bash wrapper prepares input files, activates the environment, writes the ASHURE configuration, and runs ASHURE.

## Client JavaScript

`www/modules/ashure.js` registers the module and points the information icon to the manual page:

```javascript
class ashureModule extends Module {
  constructor(params) {
    super('ashure', '/man/sections/ASHURE.md');
    this.params = params;
  }
}

module_manager.moduleCreators.ashure = params => {
  return new ashureModule(params);
};
```

Most modules only need to extend `Module` and call `super.onLoad()` if they customize `onLoad()`.

## Client HTML

`www/modules/ashure.html` defines:

* `input_file_text fastq agregate` for FASTQ wildcard input;
* `input_file fasta` for the primer FASTA;
* three `output_zone` blocks for the CSV outputs;
* an `options` block for advanced ASHURE parameters.

Fields with `param_value` are sent to the server in `config.params.params`. Fields inside `output_zone` are sent in `config.params.outputs`.

## Server Module

`server/modules/ashure.js` exports the module metadata:

```javascript
exports.name = 'ashure';
exports.multicore = true;
exports.category = '07. Nanopore/PacBio pipelines';
```

The `run` function reads browser values, creates the argument list for `run_ashure.sh`, appends the command to the session log, and starts the process:

```javascript
const command = [
  '-f', config.params.inputs.fastq,
  '-p', config.params.inputs.primers,
  '-d', directory,
  '-m', options.minlength,
  '-M', options.maxlength,
  '-C', config.params.outputs.cons_file,
  '-c', config.params.outputs.cin_file,
  '-o', config.params.outputs.cout_file
];
```

Every server module should:

1. Resolve paths under `/app/data/<token>/`.
2. Log the command before execution.
3. Append stdout/stderr to the module log.
4. Call `callback(os, null)` on success.
5. Call `callback(os, <message>)` on failure.

## Bash Wrapper

`lib/bash_scripts/run_ashure.sh` handles the details that are easier in shell than JavaScript:

* parse `getopts` arguments;
* convert wildcard markers back to shell patterns;
* copy or stage input FASTQ files;
* set required paths;
* activate the ASHURE environment;
* write the ASHURE configuration file;
* run ASHURE and move the expected outputs into the session folder.

For wildcard inputs produced by `input_file_text`, SLIM may pass `€` instead of `*`. Convert it before expanding:

```bash
if [[ "${fastq_files}" == *'€'* ]]; then
    fastq_files=$(echo "${fastq_files}" | sed 's/€/*/g')
fi
```

Quote variables unless you intentionally need shell glob expansion. For example, quote output paths but leave a reconstructed wildcard unquoted only at the expansion point.

## Development Tips

* Keep the JavaScript module thin; put pipeline-specific staging in the wrapper.
* Keep wrapper options explicit and documented.
* Use meaningful output defaults in the HTML.
* Test with one small file before testing wildcard groups.
* Check both the SLIM session log and the tool's own output files when debugging.
