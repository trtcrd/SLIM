const exec = require('child_process').spawn;
const fs = require('fs');

exports.name = 'targeted-reference-builder';
exports.multicore = true;
exports.category = '10. Ancient DNA';

exports.run = function (os, config, callback) {
    const token = os.token;
    const directory = '/app/data/' + token + '/';
    const params = config.params.params;

    const options = [
        '-i', directory,
        '-k', config.params.inputs.kraken_table,
        '-r', params.rank || 'S',
        '-a', params.min_abundance || '0.001',
        '-n', params.max_taxa || '25',
        '-g', params.max_genomes || '1',
        '-c', params.assembly_choice || 'reference_then_representative',
        '-o', config.params.outputs.reference_fasta,
        '-m', config.params.outputs.manifest,
        '-A', config.params.outputs.acc2tax,
        '-x', config.params.outputs.archive
    ];

    console.log('Running targeted reference builder with the command line:');
    console.log('/app/lib/bash_scripts/run_targeted_reference_builder.sh', options.join(' '));

    fs.appendFileSync(directory + config.log, '--- Command ---\n');
    fs.appendFileSync(directory + config.log, 'run_targeted_reference_builder ' + options.join(' ') + '\n');
    fs.appendFileSync(directory + config.log, '--- Exec ---\n');

    const runner = '/app/lib/bash_scripts/run_targeted_reference_builder.sh';
    if (!fs.existsSync(runner)) {
        const message = runner + ' is missing. Rebuild the image after copying lib/bash_scripts/run_targeted_reference_builder.sh.';
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
            callback(os, 'targeted-reference-builder terminated with code ' + code);
        }
    });

    child.on('error', function (err) {
        fs.appendFileSync(directory + config.log, err.message + '\n');
        callback(os, 'targeted-reference-builder failed to start: ' + err.message);
    });
};
