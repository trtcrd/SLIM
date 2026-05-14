const exec = require('child_process').spawn;
const fs = require('fs');

exports.name = 'singleM';
exports.multicore = true;
exports.category = '08. Shotgun metagenomics';

exports.run = function (os, config, callback) {
    const token = os.token;
    const directory = '/app/data/' + token + '/';

    const options = [
        '-i', directory,
        '-1', config.params.inputs.fwd,
        '-2', config.params.inputs.rev,
        '-t', os.cores,
        '-p', config.params.outputs.profile,
        '-O', config.params.outputs.otu_table,
        '-a', config.params.outputs.relative_abundance_archive
    ];

    console.log('Running SingleM with the command line:');
    console.log('/app/lib/bash_scripts/run_singleM.sh', options.join(' '));

    fs.appendFileSync(directory + config.log, '--- Command ---\n');
    fs.appendFileSync(directory + config.log, 'run_singleM ' + options.join(' ') + '\n');
    fs.appendFileSync(directory + config.log, '--- Exec ---\n');

    const child = exec('/app/lib/bash_scripts/run_singleM.sh', options);

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
            callback(os, 'SingleM terminated with code ' + code);
        }
    });
};
