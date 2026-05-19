const exec = require('child_process').spawn;
const fs = require('fs');

exports.name = 'nanopore-consensus';
exports.multicore = true;
exports.category = '07. Nanopore pipelines';

exports.run = function (os, config, callback) {
    const token = os.token;
    const directory = '/app/data/' + token + '/';
    const params = config.params.params;
    const primerErrorRate = params.primer_error_rate || '0.20';
    const medakaModel = params.medaka_model || 'auto';

    const options = [
        '-i', directory,
        '-y', config.params.inputs.fastq,
        '-p', config.params.inputs.primers || '',
        '-t', os.cores,
        '-m', params.minlength,
        '-M', params.maxlength,
        '-e', params.maxee,
        '-r', params.trim_primers ? 'yes' : 'no',
        '-E', primerErrorRate,
        '-u', params.discard_untrimmed ? 'yes' : 'no',
        '-G', params.pool_reads === false ? 'no' : 'yes',
        '-P', params.polish_medaka === false ? 'no' : 'yes',
        '-F', params.allow_medaka_fallback === false ? 'no' : 'yes',
        '-c', params.cluster_id,
        '-s', params.min_cluster_size,
        '-k', medakaModel,
        '-o', config.params.outputs.consensus,
        '-O', config.params.outputs.otu_table,
        '-S', config.params.outputs.stats,
        '-a', config.params.outputs.results_archive
    ];

    console.log('Running nanopore consensus');
    console.log('/app/lib/bash_scripts/run_nanopore_consensus.sh', options.join(' '));

    fs.appendFileSync(directory + config.log, '--- Command ---\n');
    fs.appendFileSync(directory + config.log, 'run_nanopore_consensus ' + options.join(' ') + '\n');
    fs.appendFileSync(directory + config.log, '--- Exec ---\n');

    const runner = '/app/lib/bash_scripts/run_nanopore_consensus.sh';
    if (!fs.existsSync(runner)) {
        const message = runner + ' is missing. Rebuild the image after copying lib/bash_scripts/run_nanopore_consensus.sh.';
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
            const logPath = directory + config.log;
            let message = 'Nanopore consensus terminated with code ' + code;

            try {
                const lines = fs.readFileSync(logPath, 'utf8').trim().split(/\r?\n/);
                const tail = lines.slice(-30).join('\n');
                if (tail)
                    message += '\n\nLast log lines:\n' + tail;
            } catch (err) {
                message += '\nUnable to read the module log tail: ' + err.message;
            }

            fs.appendFileSync(logPath, '\n' + message + '\n');
            callback(os, message);
        }
    });

    child.on('error', function (err) {
        fs.appendFileSync(directory + config.log, err.message + '\n');
        callback(os, 'Nanopore consensus failed to start: ' + err.message);
    });
};
