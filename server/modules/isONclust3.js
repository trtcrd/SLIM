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
    const primerErrorRate = params.primer_error_rate || '0.20';
    const primerTrimming = params.primer_trimming !== false ? 'yes' : 'no';
    const minClusterSize = params.min_cluster_size || '5';
    const yacrdFiltering = params.yacrd_filtering === true || params.yacrd_filtering === 'true' ? 'yes' : 'no';
    const yacrdMinCoverage = params.yacrd_min_coverage || (platform === 'pacbio' ? '3' : '4');
    const yacrdMinReadCoverage = params.yacrd_min_read_coverage || '0.4';
    const raconIterations = params.racon_iterations || '3';
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

    const readFiles = resolveFastqFiles(directory, config.params.inputs.fastq);

    if (readFiles.length > 1) {
        await runParallelSamplePreparation({
            runner,
            directory,
            logFile: config.log,
            baseOptions,
            readFiles,
            cores,
            outputs: config.params.outputs
        });
    } else {
        const options = baseOptions.concat(['-t', String(cores), '-X', 'all']);
        await runCommand({
            command: runner,
            options,
            logPath: directory + config.log,
            displayName: 'run_isonclust3'
        });
    }
}

function resolveFastqFiles(directory, inputPattern) {
    const pattern = String(inputPattern || '').replace(/€/g, '*').replace(/\$/g, '*');

    if (!pattern.includes('*')) {
        return fs.existsSync(directory + pattern) ? [pattern] : [];
    }

    const prefix = pattern.substring(0, pattern.indexOf('*'));
    const suffix = pattern.substring(pattern.indexOf('*') + 1);

    return fs.readdirSync(directory)
        .filter((filename) => filename.startsWith(prefix) && filename.endsWith(suffix))
        .filter((filename) => fs.statSync(directory + filename).isFile())
        .sort();
}

async function runParallelSamplePreparation({ runner, directory, logFile, baseOptions, readFiles, cores, outputs }) {
    cleanPreviousOutputs(directory, outputs);

    const maxParallel = Math.max(1, Math.min(cores, readFiles.length));
    const workerThreads = Math.max(1, Math.floor(cores / maxParallel));
    const prepLogs = readFiles.map((_, idx) => directory + 'isonclust3_results/sample_metadata/sample_' + idx + '.server_prepare.log');
    const mainLogPath = directory + logFile;

    fs.mkdirSync(directory + 'isonclust3_results/sample_metadata', { recursive: true });
    fs.appendFileSync(mainLogPath, '--- Parallel sample preparation ---\n');
    fs.appendFileSync(mainLogPath, 'Samples: ' + readFiles.length + '\n');
    fs.appendFileSync(mainLogPath, 'Parallel jobs: ' + maxParallel + '\n');
    fs.appendFileSync(mainLogPath, 'Threads per sample preparation job: ' + workerThreads + '\n');

    const jobs = readFiles.map((readFile, idx) => {
        const metadataFile = 'isonclust3_results/sample_metadata/sample_' + idx + '.metadata.tsv';
        const options = baseOptions.concat([
            '-t', String(workerThreads),
            '-X', 'prepare',
            '-F', readFile,
            '-D', metadataFile
        ]);

        return () => runCommand({
            command: runner,
            options,
            logPath: prepLogs[idx],
            displayName: 'run_isonclust3'
        });
    });

    const results = await runLimited(jobs, maxParallel);

    for (const prepLog of prepLogs) {
        if (fs.existsSync(prepLog))
            fs.appendFileSync(mainLogPath, fs.readFileSync(prepLog));
    }

    const failed = results.find((result) => result && result.error);
    if (failed)
        throw failed.error;

    const clusterOptions = baseOptions.concat([
        '-t', String(cores),
        '-X', 'cluster',
        '-K', String(readFiles.length)
    ]);

    await runCommand({
        command: runner,
        options: clusterOptions,
        logPath: mainLogPath,
        displayName: 'run_isonclust3'
    });
}

function cleanPreviousOutputs(directory, outputs) {
    fs.rmSync(directory + 'isonclust3_results', { recursive: true, force: true });

    for (const key of ['otus_table', 'centroids', 'stats', 'results_archive']) {
        if (outputs[key])
            fs.rmSync(directory + outputs[key], { force: true });
    }
}

async function runLimited(jobs, limit) {
    const results = new Array(jobs.length);
    const executing = new Set();

    for (let idx = 0; idx < jobs.length; idx++) {
        const promise = jobs[idx]()
            .then(() => {
                results[idx] = { ok: true };
            })
            .catch((error) => {
                results[idx] = { error };
            })
            .finally(() => {
                executing.delete(promise);
            });

        executing.add(promise);

        if (executing.size >= limit)
            await Promise.race(executing);
    }

    await Promise.all(executing);
    return results;
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
