const exec = require('child_process').spawn;
const fs = require('fs');

// const derep = require('./dereplication.js');
// const tools = require('../toolbox.js');

exports.name = 'joker-creator';
exports.multicore = true;
exports.category = 'Utils';

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
	var command = ['creating', 'joker'];
	// Joining
	console.log('Creating joker');
	fs.appendFileSync(directory + config.log, '--- Joker creation ---\n');
	var child = exec('echo', command);


	child.stdout.on('data', function(data) {
		fs.appendFileSync(directory + config.log, data);
	});
	child.stderr.on('data', function(data) {
		fs.appendFileSync(directory + config.log, data);
	});
	child.on('close', function(code) {
		if (code == 0) {
			callback(os, null);
		} else
			callback(os, "create joker terminate on code " + code);
	});
};
