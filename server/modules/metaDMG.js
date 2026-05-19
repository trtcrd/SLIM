const exec = require('child_process').spawn;
const fs = require('fs');

exports.name = 'metaDMG';
exports.multicore = true;
exports.category = '10. Ancient DNA';

exports.run = function (os, config, callback) {
    const token = os.token;
    const directory = '/app/data/' + token + '/';
    const params = config.params.params;

    const options = [
        '-i', directory,
        '-b', config.params.inputs.bam_pattern,
        '-t', os.cores,
        '-r', params.run_mode || '1',
        '-l', params.min_length || '35',
        '-p', params.print_length || '5',
        '-A', params.min_ani || '-1',
        '-B', params.max_ani || '',
        '-S', params.showfits || '0',
        '-n', params.nbootstrap || '0',
        '-L', params.library_type || 'ds',
        '-o', params.output_prefix || 'metaDMG',
        '-s', config.params.outputs.summary,
        '-a', config.params.outputs.archive
    ];

    if (config.params.inputs.acc2tax)
        options.push('-C', config.params.inputs.acc2tax);
    if (config.params.inputs.reference_fasta)
        options.push('-R', config.params.inputs.reference_fasta);

    console.log('Running metaDMG with the command line:');
    console.log('/app/lib/bash_scripts/run_metaDMG.sh', options.join(' '));

    fs.appendFileSync(directory + config.log, '--- Command ---\n');
    fs.appendFileSync(directory + config.log, 'run_metaDMG ' + options.join(' ') + '\n');
    fs.appendFileSync(directory + config.log, '--- Exec ---\n');

    const runner = '/app/lib/bash_scripts/run_metaDMG.sh';
    if (!fs.existsSync(runner)) {
        const message = runner + ' is missing. Rebuild the image after copying lib/bash_scripts/run_metaDMG.sh.';
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
            callback(os, 'metaDMG terminated with code ' + code);
        }
    });

    child.on('error', function (err) {
        fs.appendFileSync(directory + config.log, err.message + '\n');
        callback(os, 'metaDMG failed to start: ' + err.message);
    });
};
