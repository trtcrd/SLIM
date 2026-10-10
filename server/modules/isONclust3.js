const exec = require('child_process').spawn;
const fs = require('fs');

exports.name = 'isONclust3';
exports.multicore = true;
exports.category = '07. Nanopore/PacBio pipelines';

exports.run = function (os, config, callback) {
    runModule(os, config)
        .then(() => callback(os, null))
        .catch((err) => callback(os, err.message || String(err)));
};

async function runModule(os, config) {
    const token = os.token;
    const directory = '/app/data/' + token + '/';
    const params = config.params.params || {};
    const platform = (params.platform || 'nanopore').toLowerCase();
    const maxExpectedErrorRate = params.maxee_rate || (platform === 'pacbio' ? '0.01' : '0.05');
    const minLength = params.minlength || '';
    const maxLength = params.maxlength || '';
    const minClusterSize = params.min_cluster_size || '5';
    const raconIterations = params.racon_iterations || '3';
    const isonclustK = String(params.isonclust_k || '').trim();
    const isonclustW = String(params.isonclust_w || '').trim();
    const cores = Math.max(1, Number(os.cores) || 1);
    const runner = '/app/lib/bash_scripts/run_isonclust3.sh';

    if (!fs.existsSync(runner)) {
        const message = runner + ' is missing. Rebuild the image after copying lib/bash_scripts/run_isonclust3.sh.';
        fs.appendFileSync(directory + config.log, message + '\n');
        throw new Error(message);
    }

    const baseOptions = [
        '-i', directory,
        '-y', config.params.inputs.fastq,
        '-p', config.params.inputs.primers || '',
        '-P', platform,
        '-q', maxExpectedErrorRate,
        '-m', minLength,
        '-M', maxLength,
        '-R', raconIterations,
        '-s', minClusterSize,
        '-O', config.params.outputs.otus_table,
        '-o', config.params.outputs.centroids,
        '-S', config.params.outputs.stats,
        '-a', config.params.outputs.results_archive
    ];

    if (isonclustK || isonclustW)
        baseOptions.push('-k', isonclustK, '-w', isonclustW);

    // The runner owns the complete aggregate workflow: prepare every matching
    // sample, prefix read headers with the sample ID, pool the reads, cluster
    // the pool once, and build one sample-by-OTU table.
    const options = baseOptions.concat(['-t', String(cores), '-X', 'all']);
    await runCommand({
        command: runner,
        options,
        logPath: directory + config.log,
        displayName: 'run_isonclust3'
    });
}

function runCommand({ command, options, logPath, displayName }) {
    return new Promise((resolve, reject) => {
        console.log('Running isONclust3');
        console.log(command, options.join(' '));
        fs.appendFileSync(logPath, '--- Command ---\n');
        fs.appendFileSync(logPath, displayName + ' ' + options.join(' ') + '\n');
        fs.appendFileSync(logPath, '--- Exec ---\n');

        const child = exec(command, options);

        child.stdout.on('data', function (data) {
            fs.appendFileSync(logPath, data);
        });

        child.stderr.on('data', function (data) {
            fs.appendFileSync(logPath, data);
        });

        child.on('close', function (code) {
            if (code === 0) {
                resolve();
                return;
            }

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
            reject(new Error(message));
        });

        child.on('error', function (err) {
            fs.appendFileSync(logPath, err.message + '\n');
            reject(new Error('isONclust3 failed to start: ' + err.message));
        });
    });
}
