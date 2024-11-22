const exec = require('child_process').spawn;
const fs = require('fs');

// const derep = require('./dereplication.js');
// const tools = require('../toolbox.js');

exports.name = 'ashure';
exports.multicore = true;
exports.category = '07. Nanopore Pipelines';

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
	logAttributes(config);
	
	var command = ['-f', config.params.inputs.fastq, // fastq_files
		'-p', config.params.inputs.primers, // primers
		'-d', directory, // directory
		'-m', options.minlength, // min_length
		'-M', options.maxlength, // max_length
		'-s', options.clst_csize, // clst_csize
		'-t', options.clst_th_m, // clst_th_m
		'-T', options.clst_th_s, // clst_th_s
		'-N', options.clst_N, // clst_N
		'-i', options.clst_N_iter, // clst_N_iter
		'-C', config.params.outputs.cons_file, // cons_file
		'-c', config.params.outputs.cin_file, // cin_file
		'-o', config.params.outputs.cout_file]; // cout_file


	// Joining
	console.log('Running optics');
	console.log('/app/lib/bash_scripts/run_ashure.sh', command.join(' '));
	fs.appendFileSync(directory + config.log, '--- Command ---\n');
	fs.appendFileSync(directory + config.log, 'run_ashure ' + command.join(' ') + '\n');
	fs.appendFileSync(directory + config.log, '--- Exec ---\n');
	var command_output = '/app/lib/bash_scripts/run_ashure.sh';
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
			callback(os, "ashure terminate on code " + code);
	});
};
