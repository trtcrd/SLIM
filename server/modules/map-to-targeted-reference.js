const exec = require('child_process').spawn;
const fs = require('fs');

exports.name = 'map-to-targeted-reference';
exports.multicore = true;
exports.category = '10. Ancient DNA';

exports.run = function (os, config, callback) {
    const token = os.token;
    const directory = '/app/data/' + token + '/';
    const params = config.params.params;

    const options = [
        '-i', directory,
        '-t', os.cores,
        '-m', params.mode,
        '-R', config.params.inputs.reference_fasta,
        '-p', params.mapper || 'aln',
        '-f', params.fastp_trim !== false ? 'yes' : 'no',
        '-q', params.min_mapq || '0',
        '-b', config.params.outputs.bam_pattern,
        '-a', config.params.outputs.archive
    ];

    if (params.mode == 'paired') {
        options.push('-1', config.params.inputs.fwd);
        options.push('-2', config.params.inputs.rev);
    } else {
        options.push('-s', config.params.inputs.reads);
    }

    console.log('Running map-to-targeted-reference with the command line:');
    console.log('/app/lib/bash_scripts/run_map_to_targeted_reference.sh', options.join(' '));

    fs.appendFileSync(directory + config.log, '--- Command ---\n');
    fs.appendFileSync(directory + config.log, 'run_map_to_targeted_reference ' + options.join(' ') + '\n');
    fs.appendFileSync(directory + config.log, '--- Exec ---\n');

    const runner = '/app/lib/bash_scripts/run_map_to_targeted_reference.sh';
    if (!fs.existsSync(runner)) {
        const message = runner + ' is missing. Rebuild the image after copying lib/bash_scripts/run_map_to_targeted_reference.sh.';
        fs.appendFileSync(directory + config.log, message + '\n');
        callback(os, message);
        return;
    }

    const child = exec(runner, options);

    child.stdout.on('data', function (data) {
        fs.appendFileSync(directory + config.log, data);
    });

    child.stderr.on('data', function (data) {
        fs.appendFileSync(directory + config.log, data);
    });

    child.on('close', function (code) {
        if (code === 0) {
            callback(os, null);
        } else {
            callback(os, 'map-to-targeted-reference terminated with code ' + code);
        }
    });

    child.on('error', function (err) {
        fs.appendFileSync(directory + config.log, err.message + '\n');
        callback(os, 'map-to-targeted-reference failed to start: ' + err.message);
    });
};
