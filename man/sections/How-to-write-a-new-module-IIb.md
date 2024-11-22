# Editing How to write a new module II: ASHURE example, Module scripts

Edited by Adrià:

Here I will explain how I created ASHURE Module using existing Modules as templates.

This is a continuation of the [How to write a module II: ASHURE example, concept and installation](https://github.com/adriantich/SLIM/wiki/How-to-write-a-new-module-II:-ASHURE-example,-concept-and-installation) manual. If you have not read it yet I recommend you to start there and come back here once you finish.

# Module scripts
To understand how the Module works you have to keep in mind that there are two structures or blocks:

* The client
* The server

They both communicate to each other but the client part will be the one in charge of handle the inputs and outputs and how the Module will look for the user, and the server part will run the code. 

## The client
For each Module, the client part will be held by two main scripts, a [js](https://github.com/adriantich/SLIM/blob/master/www/modules/ashure.js) and a [html](https://github.com/adriantich/SLIM/blob/master/www/modules/ashure.html) files. 

### JS file
This file will handle the module parameters. However, you will see that usually this script is short and no many things seem to happen, this is because what you do in this script is to call a previous class that it's called Module into your new class and expand their content if needed. An example of it could be the [dada2 module](https://github.com/adriantich/SLIM/blob/master/www/modules/DADA2.js) with the *by_lib* and *pool* elements.

In this case you will see that nothing is added but I did some modifications indeen. However, as I found them useful for future modules I added them to the source script for this class, [module.js](https://github.com/adriantich/SLIM/blob/master/www/js/module.js). Here you can search for a new class name called input_file_text. This is a copy of the class input_file with the difference that instead of replacing "*" by "$", it does by "€". This change was needed for the bash script of ashure. (see more details at the end of the document)

All the inputs will be stored in _params_ and will be used by the server part to run the code.


### HTML file
In this file you will need to define the fields for the different input and outputs. It is important to know that the types and classes used are defined in the js files. You can create new ones but the easiest is to find one that fits you in the modules already created and copy them. 

## The Server
On the server, a series of commands to deal with the parameters introduced by the user in the client will be handled and used to run the main command. Lets see step by step what the [js] file of ashure server does:

### Requirements
First I need to call the requirements and export little information of the module as the name and the category:

```
const exec = require('child_process').spawn;
const fs = require('fs');

exports.name = 'ashure';
exports.multicore = true;
exports.category = 'Full pipeline';
```
### Starting the run function
Then I start defining the run function that will be the one called when starting the analysis of the module. I need to define the token and the directory in which the analysis will be running in the container in the server. Remember that the token is used to define your session but also will be the name that will be used for the folder corresponding to the session in the server. Finally I need to retrieve the parameters from config. This is part of the class defined in the client part. Now *options* will have all the input parameters.
```
exports.run = function (os, config, callback) {
	let token = os.token;
	var options = config.params.params;
	var directory = '/app/data/' + token + '/';
```
### Defining the command to run
Within the same run function, once I have all the parameters in the options vatiable, now I can call them to create the options of the command. As I created a bash script that will be called to run the pipeline, I can define the different parameters as desired. Finally I use the exec function to join the program (the bash script) and the commands into child. This child process will be executed in the next step.
```
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
```

### Running the command and closing run function
To finish the run function I will call the child process and specify the actions for the diffent outputs and errors.
```
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
```

## The Bash script
Finally, I will explain some tips for the [bash script](https://github.com/adriantich/SLIM/blob/master/lib/bash_scripts/run_ashure.sh). Remember that you can also call a python or a R script. 

The more important comments for this script for ASHURE are the options allowed for the script, the activation of the environment and the analysis itself. You can choose whatever way is preferred to specify the input options but in the present example I used *getopts*:
```
while getopts f:p:m:M:d:s:t:T:N:i:C:c:o: flag
do
    case "${flag}" in
	f) fastq_files="${OPTARG}";;
	p) primers="${OPTARG}";;
	d) directory="$( cd -P "$( dirname "${OPTARG}" )" >/dev/null 2>&1 && pwd )/$( echo ${OPTARG%\/} | rev | cut -f1 -d '/' | rev )/";;
	m) min_length="${OPTARG}";;
	M) max_length="${OPTARG}";;
  s) clst_csize="${OPTARG}";;
  t) clst_th_m="${OPTARG}";;
  T) clst_th_s="${OPTARG}";;
  N) clst_N="${OPTARG}";;
  i) clst_N_iter="${OPTARG}";;
  C) cons_file="${OPTARG}";;
  c) cin_file="${OPTARG}";;
  o) cout_file="${OPTARG}";;
	\?) echo "usage: bash run_ashure.sh [-f|p|m|M|d|s|t|T|N|i|C|c|o]"; exit;;
    esac
done
```

Then I need to specify some paths and activate the environment:
```
export PATH=$PATH:/root/.local/bin/:
export PATH=$PATH/app/lib/msi/bin/:/app/lib/ASHURE/spoa/build/bin/
export PATH=$PATH/app/lib/ASHURE/src/:

source activate ashure
```
And finally the rest of the script will create the config file and run the ashure with it.

Note:
To handle all the files I used the joker pattern to copy all the fastq files into a subfolder and reference it in the config file. (see Further comments)

# Further comments
#### Explaining the input_file_text
The problem that I had with the jokers is that not only they where pointing to a character name but also to a compressed file in the server. This file was produced by the Modules and not when uploading multiple files in one .tar.gz file. What I needed then was only the character string but when the Module handles this string, it replaces the "\*" by "$" and bash do not like such expressions. Then I decided to change the character to one that does not interfere with the bash script and that is why I change it to "€". This character that is not probable to be used in any file name, then is changed back to "\*" to point to multiple files with the joker pattern. See in the [bash script](https://github.com/adriantich/SLIM/blob/master/lib/bash_scripts/run_ashure.sh) the following lines to handle it:

```
# check if fastq_files has '$' in it
if [[ ${fastq_files} == *'€'* ]]; then
    echo "more than one fastq file"
    # change the $ to a space
    fastq_files=$(echo ${fastq_files} | sed 's/\€/\*/g')
fi
```