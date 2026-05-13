const exec = require('child_process').spawn;
const fs = require('fs');

// const derep = require('./dereplication.js');
// const tools = require('../toolbox.js');

exports.name = 'wildcard-creator';
exports.multicore = false;
exports.category = '01. Demultiplexing / sample grouping';

exports.run = function (os, config, callback) {
	let token = os.token;
	let directory = '/app/data/' + token + '/';
	let joker = config.params.archive_joker;

	if (!joker || !joker.includes('*')) {
		fs.appendFileSync(directory + config.log, 'No wildcard archive requested.\n');
		callback(os, null);
		return;
	}

	fs.readdir(directory, function (err, items) {
		if (err) {
			callback(os, err.toString());
			return;
		}

		let begin = joker.substring(0, joker.indexOf('*'));
		let end = joker.substring(joker.indexOf('*') + 1);
		let files = [];

		fs.appendFileSync(directory + config.log, '--- Wildcard creator ---\n');
		fs.appendFileSync(directory + config.log, 'Wildcard: ' + joker + '\n');
		fs.appendFileSync(directory + config.log, 'Prefix: ' + begin + '\n');
		fs.appendFileSync(directory + config.log, 'Suffix: ' + end + '\n');

		for (let idx = 0; idx < items.length; idx++) {
			let filename = items[idx];

			if (filename.includes('*'))
				continue;

			if (filename.endsWith('.tar.gz'))
				continue;

			if (filename.startsWith(begin) && filename.endsWith(end))
				files.push(filename);
		}

		if (files.length === 0) {
			fs.appendFileSync(directory + config.log, 'No files matched wildcard: ' + joker + '\n');
			callback(os, 'No files matched wildcard: ' + joker);
			return;
		}

		let archive = directory + joker + '.tar.gz';

		fs.appendFileSync(directory + config.log, 'Matched files:\n');
		for (let idx = 0; idx < files.length; idx++) {
			fs.appendFileSync(directory + config.log, files[idx] + '\n');
		}

		let options = [
			'--use-compress-program=pigz',
			'-Pcf',
			archive,
			'-C',
			directory
		].concat(files);

		console.log('Creating wildcard archive:');
		console.log('tar', options.join(' '));

		let child = exec('tar', options);

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
				callback(os, 'tar terminated with code ' + code);
			}
		});
	});
};
