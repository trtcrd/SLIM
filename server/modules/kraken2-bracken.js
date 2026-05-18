const exec = require('child_process').spawn;
const fs = require('fs');

exports.name = 'kraken2-bracken';
exports.multicore = true;
exports.category = '08. Shotgun metagenomics';

exports.run = function (os, config, callback) {
    const token = os.token;
    const directory = '/app/data/' + token + '/';
    const params = config.params.params;
    const database = params.database || 'pluspf_16';

    const options = [
        '-i', directory,
        '-t', os.cores,
        '-m', params.mode,
        '-d', database,
        '-c', params.confidence,
        '-l', params.tax_level,
        '-r', params.read_length,
        '-T', params.bracken_threshold,
        '-M', params.memory_mapping ? 'yes' : 'no',
        '-f', params.fastp_trim !== false ? 'yes' : 'no',
        '-o', config.params.outputs.abundance_matrix,
        '-O', config.params.outputs.relative_abundance_matrix,
        '-a', config.params.outputs.results_archive
    ];

    if (params.mode == 'paired') {
        options.push('-1', config.params.inputs.fwd);
        options.push('-2', config.params.inputs.rev);
    } else {
        options.push('-s', config.params.inputs.reads);
    }

    console.log('Running Kraken2/Bracken with the command line:');
    console.log('/app/lib/bash_scripts/run_kraken2_bracken.sh', options.join(' '));

    fs.appendFileSync(directory + config.log, '--- Command ---\n');
    fs.appendFileSync(directory + config.log, 'run_kraken2_bracken ' + options.join(' ') + '\n');
    fs.appendFileSync(directory + config.log, '--- Exec ---\n');

    const runner = '/app/lib/bash_scripts/run_kraken2_bracken.sh';
    if (!fs.existsSync(runner)) {
        const message = runner + ' is missing. Rebuild the image after copying lib/bash_scripts/run_kraken2_bracken.sh.';
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
            callback(os, 'Kraken2/Bracken terminated with code ' + code);
        }
    });

    child.on('error', function (err) {
        fs.appendFileSync(directory + config.log, err.message + '\n');
        callback(os, 'Kraken2/Bracken failed to start: ' + err.message);
    });
};
