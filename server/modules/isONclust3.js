const exec = require('child_process').spawn;
const fs = require('fs');

exports.name = 'isONclust3';
exports.multicore = true;
exports.category = '07. Nanopore/PacBio pipelines';

exports.run = function (os, config, callback) {
    const token = os.token;
    const directory = '/app/data/' + token + '/';
    const params = config.params.params || {};
    const platform = (params.platform || 'nanopore').toLowerCase();
    const maxExpectedErrorRate = params.maxee_rate || (platform === 'pacbio' ? '0.01' : '0.05');
    const minLength = params.minlength || '';
    const maxLength = params.maxlength || '';
    const primerErrorRate = params.primer_error_rate || '0.20';
    const primerTrimming = params.primer_trimming !== false ? 'yes' : 'no';
    const minClusterSize = params.min_cluster_size || '5';
    const yacrdFiltering = params.yacrd_filtering === true || params.yacrd_filtering === 'true' ? 'yes' : 'no';
    const yacrdMinCoverage = params.yacrd_min_coverage || (platform === 'pacbio' ? '3' : '4');
    const yacrdMinReadCoverage = params.yacrd_min_read_coverage || '0.4';
    const raconIterations = params.racon_iterations || '3';

    const options = [
        '-i', directory,
        '-y', config.params.inputs.fastq,
        '-p', config.params.inputs.primers || '',
        '-t', os.cores,
        '-P', platform,
        '-q', maxExpectedErrorRate,
        '-m', minLength,
        '-M', maxLength,
        '-E', primerErrorRate,
        '-T', primerTrimming,
        '-R', raconIterations,
        '-s', minClusterSize,
        '-Y', yacrdFiltering,
        '-c', yacrdMinCoverage,
        '-n', yacrdMinReadCoverage,
        '-O', config.params.outputs.otus_table,
        '-o', config.params.outputs.centroids,
        '-S', config.params.outputs.stats,
        '-a', config.params.outputs.results_archive
    ];

    console.log('Running isONclust3');
    console.log('/app/lib/bash_scripts/run_isonclust3.sh', options.join(' '));

    fs.appendFileSync(directory + config.log, '--- Command ---\n');
    fs.appendFileSync(directory + config.log, 'run_isonclust3 ' + options.join(' ') + '\n');
    fs.appendFileSync(directory + config.log, '--- Exec ---\n');

    const runner = '/app/lib/bash_scripts/run_isonclust3.sh';
    if (!fs.existsSync(runner)) {
        const message = runner + ' is missing. Rebuild the image after copying lib/bash_scripts/run_isonclust3.sh.';
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
            let message = 'isONclust3 terminated with code ' + code;

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
        callback(os, 'isONclust3 failed to start: ' + err.message);
    });
};
