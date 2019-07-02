const Rexec = require('child_process').exec;
const fs = require('fs');
const tools = require('../toolbox');

exports.name = 'DADA2';
exports.category = 'Clustering';
exports.multicore = false;

exports.run = function(os,config,callback){
  let token = os.token;
  let directory = '/app/data/' + token + '/';
  let tags = directory + config.params.inputs.tags;
  let by_lib = config.params.params.by_lib;
  let asvs_seq = config.params.outputs.asvs_seq;
  let asvs_table = config.params.outputs.asvs_tab;
  let proc = os.cores;

  console.log('value of by_lib:  ' + by_lib)

  var command = ['/app/lib/R_scripts/dada2.R',by_lib,tags,asvs_seq,asvs_table,token,proc];

  var child = Rexec('Rscript '+command.join(' '));

  child.stdout.on('data', function(data) {
		console.log('STDOUT:' + data);
		fs.appendFileSync(directory + config.log, data);
	});
	child.stderr.on('data', function(data) {
		console.log('STDERR:' + data);
		fs.appendFileSync(directory + config.log, data);
	});

  child.on('close', (code) => {
		if (code != 0) {
			console.log("Error code " + code + " during DADA2");
			callback(os, code);
		} else {
			callback(os, null);
		}
	});

}