# How to Write a New Module

SLIM modules are small adapters around command-line tools. A module describes the fields shown in the browser, translates those fields into a command, runs the command inside the container, and reports success or failure to the scheduler.

This guide uses the existing `fasta-dereplication` module as the running example.

## Module Checklist

Before writing code, decide:

1. Which tool or script the module will run.
2. Which inputs, outputs, and parameters the user should control.
3. Which files the module creates.
4. Whether the tool is already multithreaded.
5. Which dependencies must be downloaded and installed in the image.

Avoid exposing every command-line option at first. Start with the options that are necessary, stable, and understandable for users.

## Add Dependencies

Dependencies are prepared in two places:

* `get_dependencies_slim_v1.0.0.sh`: downloads or prepares source archives under `lib/`.
* `Dockerfile`: copies dependencies into the image and installs/builds them.

For tools cloned from GitHub, add a guarded download step to `get_dependencies_slim_v1.0.0.sh`. For tools that must be pinned, prefer release archives or explicit versions.

For example, VSEARCH is copied from `lib/vsearch` and built in the Docker image before modules use `/app/lib/vsearch/bin/vsearch`.

## Server-Side Module

Create a file in:

```text
server/modules/<module>.js
```

A server module exports:

```javascript
exports.name = 'fasta-dereplication';
exports.multicore = false;
exports.category = '09. Utils';
exports.run = (os, config, callback) => {
  // Build and run the command here.
};
```

### Exported Fields

* `name`: module identifier. It must match the client files in `www/modules/`.
* `multicore`: `true` if the tool uses the cores assigned by SLIM; `false` if the scheduler may parallelize independent jobs.
* `category`: display group in the module list.
* `run`: function called by the scheduler.

### Runtime Arguments

`run(os, config, callback)` receives:

* `os.token`: session token; session files live in `/app/data/<token>/`.
* `os.cores`: number of CPU threads available to the module.
* `config.log`: log file name for the module.
* `config.params.inputs`: input files selected in the browser.
* `config.params.outputs`: output file names selected in the browser.
* `config.params.params`: other parameter values.

Always write stdout/stderr to the module log and call `callback(os, null)` on success. On failure, call `callback(os, <message-or-code>)`.

### Example Command Wrapper

The `fasta-dereplication` module builds a VSEARCH command like this:

```javascript
const exec = require('child_process').spawn;
const fs = require('fs');

exports.run = (os, config, callback) => {
  const directory = '/app/data/' + os.token + '/';
  const input = directory + config.params.inputs.fasta;
  const output = directory + config.params.outputs.derep;

  const options = [
    '--derep_fulllength', input,
    '--sizeout',
    '--sizein',
    '--minseqlength', '1',
    '--output', output
  ];

  const child = exec('/app/lib/vsearch/bin/vsearch', options);
  child.stdout.on('data', data => fs.appendFileSync(directory + config.log, data));
  child.stderr.on('data', data => fs.appendFileSync(directory + config.log, data));
  child.on('close', code => callback(os, code === 0 ? null : code));
};
```

## Client-Side Module

Create two files:

```text
www/modules/<module>.js
www/modules/<module>.html
```

The JavaScript file registers the module with the browser:

```javascript
class DereplicationModule extends Module {
  constructor(params) {
    super('fasta-dereplication', '/man/sections/Fasta-dereplication.md');
    this.params = params;
  }
}

module_manager.moduleCreators['fasta-dereplication'] = params => {
  return new DereplicationModule(params);
};
```

The HTML file defines inputs, outputs, and parameters:

```html
<p>Input FASTA file</p>
<input type="text" name="fasta" class="input_file fasta" />

<p>Dereplicated FASTA file</p>
<span class="output_zone">
  <input type="text" name="derep" value="derep.fasta" />
  <a href="" download><img src="/imgs/download.png" class="download"/></a>
</span>
```

## HTML Helper Classes

SLIM's base `Module` class reads specific classes from the module HTML:

| Class | Use |
| --- | --- |
| `input_file` | Single input file with autocompletion. Stored in `config.params.inputs`. |
| `input_file_text` | Input pattern that keeps wildcard text for bash-oriented modules. |
| `input_list` | Multiple file selection through checkboxes. |
| `output_zone` | Output field with automatic download-link handling. |
| `param_value` | Parameter stored in `config.params.params`. |
| `number` | Adds numeric validation. |
| `integer` | Adds integer-oriented styling/validation. |
| `options` | Hidden advanced-options block toggled by a **More options** button. |

Each field needs a `name`, because the name becomes the key in the configuration object.

## Wildcards

SLIM uses `*` in the interface, but the base module class may encode wildcards before sending them to the server. Use the same input class as the closest existing module:

* `input_file`: normal file input.
* `input_file_text`: wildcard/pattern input intended to be reconstructed by a bash wrapper.
* `input_list`: checklist input for selecting multiple explicit files.

If your bash script receives the `€` marker from `input_file_text`, convert it back to `*` before expanding files.

## Testing a Module

1. Run `bash get_dependencies_slim_v1.0.0.sh` if new dependency folders are needed.
2. Build/start SLIM with `bash start_slim_v1.0.0.sh`.
3. Open `http://localhost:8080/`.
4. Upload a small test dataset.
5. Run the new module alone.
6. Chain it with expected upstream and downstream modules.
7. Inspect the module log and output files.

When testing inside the container, find the running container with:

```bash
podman ps
podman exec -it slim /bin/bash
```

Use `docker` instead of `podman` if you started SLIM with `--docker`.
