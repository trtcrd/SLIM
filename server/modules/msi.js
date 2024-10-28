const exec = require('child_process').spawn;
const fs = require('fs');

// const derep = require('./dereplication.js');
const tools = require('../toolbox.js');

exports.name = 'msi';
exports.multicore = true;
exports.category = 'Full pipeline';

exports.run = function (os, config, callback) {
	let token = os.token;
	var options = config.params.params;
	var directory = '/app/data/' + token + '/';
	// var tmp_outfile = tools.tmp_filename() + '.fastq';
	// var algo_name = config.params.params.algorithm;

	// Define the project name regarding the output filename
	// var project = config.params.outputs.assembly;
	// if (project.lastIndexOf('_panda') == -1)
	// 	project = project.substr(0, project.lastIndexOf('.'));
	// else
	// 	project = project.substr(0, project.lastIndexOf('_panda'));

	// if options.refdb is not defined, set it to empty string

function logAttributes(obj, prefix = '') {
	for (const key in obj) {
		if (obj.hasOwnProperty(key)) {
			const value = obj[key];
			const newPrefix = prefix ? `${prefix}.${key}` : key;
			if (typeof value === 'object' && value !== null) {
				logAttributes(value, newPrefix);
			} else {
				console.log(newPrefix);
			}
		}
	}
}

// Call the function with the options object
logAttributes(options);
console.log('checking config');
logAttributes(config);


// if (config.params.inputs.refdb === " " || config.params.inputs.refdb === "") {
//     console.log("params.inputs.refdb is undefined");
//     refdb_option = '';
// } else {
//     refdb_option = '-b ' + config.params.inputs.refdb;
// }
	
	var command = ['-i', directory, // TL_DIR
		'-y', config.params.inputs.fastq, // FASTQ
		'-t', os.cores, // THREADS
		// '-I', config.params.inputs.metadata, // METADATAFILE
		'-p', config.params.inputs.primerfile, // primerfile
		// '-g', options.target_gene, // target_gene
		'-C', options.clusterminreads, // CLUSTER_MIN_READS
		'-a', options.cdhitclusterthr, // CD_HIT_CLUSTER_THRESHOLD
		'-A', options.primermaxerror, // PRIMER_MAX_ERROR
		'-m', options.minlength, // MIN_LEN
		'-M', options.maxlength, // MAX_LEN
		'-q', options.minqual, // MIN_QUAL
		'-x', options.minmap, // CLUST_MAPPED_THRESHOLD
		// '-X', options.minaligned, // CLUST_ALIGNED_THRESHOLD
		// refdb_option]; // blast_refdb
		'-X', options.minaligned]; // CLUST_ALIGNED_THRESHOLD


	// Joining
	console.log('Running msi');
	console.log('/app/lib/bash_scripts/run_msi.sh', command.join(' '));
	fs.appendFileSync(directory + config.log, '--- Command ---\n');
	fs.appendFileSync(directory + config.log, 'run_msi ' + command.join(' ') + '\n');
	fs.appendFileSync(directory + config.log, '--- Exec ---\n');
	var command_output = '/app/lib/bash_scripts/run_msi.sh';
	var child = exec(command_output, command);


	child.stdout.on('data', function(data) {
		fs.appendFileSync(directory + config.params.outputs.assembly, data);
	});
	child.stderr.on('data', function(data) {
		fs.appendFileSync(directory + config.log, data);
	});
	child.on('close', function(code) {
		if (code == 0) {
			callback(os, null);
		} else
			callback(os, "msi terminate on code " + code);
	});
};
