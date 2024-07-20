const exec = require('child_process').spawn;
const fs = require('fs');

// const derep = require('./dereplication.js');
const tools = require('../toolbox.js');


exports.name = 'msi';
exports.multicore = true;
exports.category = 'Utils';

// var algorithms = {
// 	bayesian: 'simple_bayesian',
// 	fastqjoin: 'ea_util',
// 	flash: 'flash',
// 	pear: 'pear',
// 	rdp: 'rdp_mle',
// 	stitch: 'stitch',
// 	uparse: 'uparse'
// };

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

	var command = ['--input', directory + config.params.inputs.fastq,
		'--quality', options.threshold,
		'--headcrop', options.headcrop,
		'--tailcrop', options.tailcrop,
		'--minlength', options.minlength,
		'--maxlength', options.maxlength,
		'--threads', os.cores];


	// Joining
	console.log('Running chopper');
	console.log('/root/miniconda3/envs/env/bin/chopper', command.join(' '));
	fs.appendFileSync(directory + config.log, '--- Command ---\n');
	fs.appendFileSync(directory + config.log, 'chopper ' + command.join(' ') + '\n');
	fs.appendFileSync(directory + config.log, '--- Exec ---\n');
	// var command_output = '/root/miniconda3/envs/env/bin/chopper > ' + directory + config.params.outputs.assembly;
	var command_output = '/root/miniconda3/envs/env/bin/chopper';
	var child = exec(command_output, command);


	child.stdout.on('data', function(data) {
		fs.appendFileSync(directory + config.params.outputs.assembly, data);
	});
	child.stderr.on('data', function(data) {
		fs.appendFileSync(directory + config.log, data);
	});
	child.on('close', function(code) {
		if (code == 0) {
			var outfile = directory + config.params.outputs.assembly;
			tools.sort(outfile, () => {callback(os, null);});
			// // Params definition for dereplication
			// let derep_params = {params: {
			// 	inputs: {fastq: tmp_outfile},
			// 	outputs: {derep: config.params.outputs.assembly},
			// 	params: {}
			// },log:config.log};

			// // Dereplicate and sort
			// derep.run(os, derep_params, (os, msg) => {
			// 	fs.unlink(directory + tmp_outfile, ()=>{});
				
			// 	// Error case
			// 	if (msg != null) {
			// 		callback(os, msg);
			// 		return;
			// 	}

			// 	// Normal case
			// 	tools.sort(directory + config.params.outputs.assembly, () => {
			// 		callback(os, msg);
			// 	});
			// });
		} else
			callback(os, "chopper terminate on code " + code);
	});
};
