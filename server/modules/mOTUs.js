const exec = require('child_process').spawn;
const fs = require('fs');
const nodeOs = require('os');

exports.name = 'mOTUs';
exports.multicore = true;
exports.category = '08. Shotgun metagenomics';

exports.run = function (os, config, callback) {
    const token = os.token;
    const directory = '/app/data/' + token + '/';
    const params = config.params.params;
    const availableCores = nodeOs.cpus().length || 1;
    const threads = Math.max(1, Math.min(Number(os.cores) || 1, availableCores));

    const options = [
        '-i', directory,
        '-t', threads,
        '-m', params.mode,
        '-g', params.marker_genes || '3',
        '-l', params.alignment_length || '75',
        '-y', params.counting_mode || 'INSERT_SCALED',
        '-f', params.fastp_trim !== false ? 'yes' : 'no',
        '-o', config.params.outputs.profile_matrix,
        '-O', config.params.outputs.relative_matrix,
        '-a', config.params.outputs.results_archive,
        '-q', config.params.outputs.fastp_report_archive || 'mOTUs.fastp_reports.tar.gz'
    ];

    if (params.mode == 'paired') {
        options.push('-1', config.params.inputs.fwd);
        options.push('-2', config.params.inputs.rev);
    } else {
        options.push('-s', config.params.inputs.reads);
    }

    console.log('Running mOTUs with the command line:');
    console.log('/app/lib/bash_scripts/run_mOTUs.sh', options.join(' '));

    fs.appendFileSync(directory + config.log, '--- Command ---\n');
    fs.appendFileSync(directory + config.log, 'run_mOTUs ' + options.join(' ') + '\n');
    fs.appendFileSync(directory + config.log, '--- Exec ---\n');

    const runner = '/app/lib/bash_scripts/run_mOTUs.sh';
    if (!fs.existsSync(runner)) {
        const message = runner + ' is missing. Rebuild the image after copying lib/bash_scripts/run_mOTUs.sh.';
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
            callback(os, 'mOTUs terminated with code ' + code);
        }
    });

    child.on('error', function (err) {
        fs.appendFileSync(directory + config.log, err.message + '\n');
        callback(os, 'mOTUs failed to start: ' + err.message);
    });
};
