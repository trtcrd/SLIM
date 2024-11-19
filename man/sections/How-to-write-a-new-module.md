# How to write a new module

Write a new module for the pipeline is quite easy if you know a little bit of html and javascript.  
  
The process of module creation is divided in four steps:
1. Perfectly understand your software command line and be sure what you want to do with it
2. Write installation instructions in the deployment scripts
3. Integrate the software in the modules present on the server and expose its interface
4. Create the web interface that users will use

# The software command line
This pipeline is not a dark magic software.
The only thing that it does is to create a command line, execute it and send back an answer when the software ended (with some minor modifications to the output if needed).  
So, the first thing you need to do is perfectly understand what options you want to pass to your software and what files you need to input.
To explain all the steps we will take the dereplication module as example.  
  
## The dereplication example
### Basic command line
To create the dereplication module, we used the [vsearch software](https://github.com/torognes/vsearch).
The aim of a dereplication software is to compress all the identical sequences in a fasta file.
So, looking at the vsearch documentation we can create the following command line
```bash
vsearch --derep-fulllength <input_fasta> --output <output_fasta>
```
An output file different from the input file is a good practice to avoid unexpected behavior of your software and to allow the usage of the input file unmodified for other softwares.

### Define your specifications
The previous command line works fine but is not enough for our purpose.
For example, sometime we will have partially dereplicated input fasta.
So, the module must understand inputs with size annotations in the header.
This can be handled by the option --sizein of the command line.  
  
So, this example show that you need to specify exactly what you want before implementing the module.
Here is the complete list of the specifications for the dereplication tool and the command line correspondances:
* Read the input fasta understanding previous size annotations: --sizein option of vsearch
* Output the amount of each read in the header: --sizeout
* Output sequences on a unique line. By default vsearch output sequences in a multi-line format: --fasta_width 0
* Dereplacate all the sequences even when the sequence size is smaller than 32: --minseqlength 1
* Add an optional filtering threshold quantity: --minuniquesize <threshold>

When all the the options are defined for your software, you can go to the next steps and start the server side module part.

# Install your software
## Download the software
There are two kind of softwares, those which using a versioning tool and the others.
For the first ones, we can easily add a line in the software update script to get the latest version.
Follow what have be done in the update_dependencies.sh script for other softs to add your own.
For the non-versioned softwares, we don't have any other choice than manually download a version and push it in our own repository (in the lib directory) to deploy it.

For example, for the vsearch update we added the following lines:
```bash
# Vsearch
if [ ! -d "vsearch" ]; then
	git clone https://github.com/torognes/vsearch.git vsearch/
else
	cd vsearch
	git pull
	cd ..
fi
```

## Deploy the software in the docker container
The software is now deployed on your computer but you have to explain how to deploy it when the docker is started.
So, let's open the Dockerfile.
This file can be decomposed in 4 distinct parts.  

First, you will find the basic setup and requirements for the system.
The construction will start with the creation of a 'nodejs' docker, the creation of the /app working directory of our application and the installation of standard unix packages.
You may be interested in the installation of unix package if your software have some requirements.  

Second, there is the part including all the time consuming installations like miniconda of QIIME.
These installations are made at the beginning of the script because they will not be changed very often and docker can use the cache to bypass their installations.  

Third, this is the most important part for you.
This is the part where the dependencies are copied in the /app/lib directory and compiled if needed.
For now we did not needed to globaly deploy a software.
All of the binaries are in the lib directory and we specify the path for each execution.  

For the vsearch tool we added a line to copy the lib and a line to compile it.
```
COPY lib/vsearch /app/lib/vsearch
RUN cd /app/lib/vsearch && ./autogen.sh && ./configure && make && cd /app
```

Finally, the forth part is about the web server deployment and must not be touched when you are adding a new tool.

We are now ready to start programming the pipeline module.

# Server side module programming
The pipeline have an automatic module detection.
To add a new module you only need to create a file corresponding to your module in the directory server/modules.
A module can be see as a collection of 4 public attributes: name, multicore, category and run.
The name and category are respectively the module name that will be used in the pipeline and the kind of software that it is.
For example, the dereplication module is called fasta-dereplication and is include in the FASTA/FASTQ software group:
```javascript
exports.name = 'fasta-dereplication';
exports.category = 'FASTA/FASTQ';
```
The multicore attribute is to tell the pipeline if the software is already threaded or if the scheduler must parallelized multiple execution.
For the dereplication, we have no software parallellization:
```javascript
exports.multicore = false;
```
Finally, the run parameter correspond to the function that will be executed when the module is triggered:
```javascript
exports.run = (os, config, callback) => {
  // Content
};
```

## Understand the run function
The run function of a module is where everything happen.
It is the place where you will get the options selected by the user, transform them into a valid command line, execute this command line and send back outputs.

### The arguments
Let's start with the arguments of the function.
The fist argument represent all the elements that you need to know about the emulated exploitation system.
For now there are two arguments: os.token and os.cores.
If your program had been declared as multicore, os.core is the number of threads that you are allowed to create.
os.token represent the user token used for this execution.
All the file uploaded and generated by other softwares will be present in the directory /app/data/\<token\>/.

The second argument represent the software configuration for the current run.
config.log is the name of the log file where you have to write all your software standard outputs.
config.params is the most important value. This is an object containing all the inputs, outputs and other parameters for your software.  
Here is the object config for an example of dereplication:
```json
"config" : {
  "log": "execution.log",
  "params": {
    "inputs": {
      "fasta": "test.fasta"
    },
    "outputs": {
      "derep": "test_derep.fasta"
    },
    "params": {
      "threshold": 3
    }
  }
}
```
It's a very simple example with only one input, one output and one option.
We can, of course, have multiple entries for each category.

The last argument is the callback function.
When your program is over, you must call it using the os object as first parameter and a message for the second argument only if the execution went wrong. If the software ends normally use the null object as second parameter.

### The software execution
Now it's time to use the command line created in the first part of this tutorial.
To execute a command line we will use the spawn function from the 'child_process' library of nodejs.
The spawn command take 2 arguments: the path to the program and the list of options.
For example, to call the "ls -l /app" you will have to write the following code lines:
```javascript
const spawn = require('child_process').spawn;
spawn('ls', ['-l', '/app']);
```
Attention, to execute locally installed softwares you will have to specify the exact path to it.
For example, to execute the vsearch dereplication the spawn command will be:
```javascript
spawn('/app/lib/vsearch/bin/vsearch', ['--derep_fulllength', ...]);
```

For more details on the command line construction and how to write the log file, please refer to the [complete implementation of the dereplication](https://github.com/yoann-dufresne/amplicon_pipeline/blob/master/server/modules/dereplication.js).

Now let's go to the client side implementation of the module

# The client side module
Creating a graphical interface for your module is the final step!
This graphical interface is a simplified HTML/javascript program.
Your module html and js files must be created in the www/modules directory.

The global principle is very simple.
When a module is detected on the server, the client try to load the js file www/modules/<module_name>.js.
This js module will try to create an HTML div module loading the file www/modules/<module_name>.html.
Finally, if everything is correctly loaded and the start button is pushed, the javascript module is called to get the param object described in the server side part.

## mymodule.js
All the modules in the client file must be inheritance of the Module class www/js/module.js.
The most important functions in modules are the constructor, the onLoad function, the getConfiguration function and the toDOMelement function.

For an easy example: [dereplication module](https://github.com/yoann-dufresne/amplicon_pipeline/blob/master/www/modules/fasta-dereplication.js)  
For a more complex one: [pandaseq module](https://github.com/yoann-dufresne/amplicon_pipeline/blob/master/www/modules/pandaseq.js)

### Module constructor
The module constructor must be called during the very beginning of your module constructor:
```javascript
super ("fasta-dereplication", "https://web/url/to/my/doc.html");
```
You have to pass the name of the module as first argument and the web url of your module doc if there is one.
This doc must contain information about your graphical interface and not about your software!
Put your software doc into a reference part of the GUI doc.

Attention: the module name passed as first argument will be used by the Module parent class to load your html file.
So, be sure that your name <module_name> correspond to the <module_name>.html.

### The toDOMelement function
toDOMelement will create a div element for an instance of your module, add all the generic elements and load specific elements from your html part of the module.
Normally, you shouldn't have to modify this function.

### The onLoad function
onLoad is the function that will be called immediately after the HTML part loading.
Depending on the annotation in the HTML (see mymodule.html for more details), the basic onLoad function will recognize your inputs, outputs and param, reload their previous value and setup triggers on value changes.
If you want to add comportment on unrecognized html pieces, don't forget to call "super.onLoad()" (for an example, see the module [pandaseq](https://github.com/yoann-dufresne/amplicon_pipeline/blob/master/www/modules/pandaseq.js)).

### the getConfiguration function
getConfiguration will transform the values in the HTML to the configuration object that will be send to the server.
The format of this object is described in the server side module programming part.

Most of the time, you will not have to modify this function if you add the right tags in your html.
See the next part to understand the tags.


## mymodule.html
In this file you will have to create the specific html for your module.
This html must contains elements to fill inputs, outputs and parameter values.
Here is the example for the dereplication tool (one input and one output area):
```html
<p>Fasta file</p>
<input type="text" name="fasta" class="input_file fasta" />

<p>Dereplicated fasta file</p>
<span class="output_zone">
	<input type="text" name="derep" value='derep.fasta' />
	<a href="" download><img src="/imgs/download.png" class="download"/></a>
</span>
```
All those values must be added to the configuration object in the js file when the getConfiguration method is called.
To facilitate this process we created a list of tags that you can add in the class names of the html elements.

### Automatisation tags
The tags can be used to automate the getConfiguration function, to automatize the creation of download links and to automatize the update of auto-completions.

* Filetype: if you add a filetype as "fasta" in the class names of an input, the element will automatically be updated when a new file is added or an old file is removed.
On `<input type="text">` the file autocompletion will be updated.
On `<div class="input_list">` the file list with checkboxes will be updated.

* Automatic configuration: We created 4 tags that you can add to class list of some elements to automatically retrieve their values.
In addition to these tags your must specify a name for the element.
The name will be used in the configuration object as key.
Here is the list of tags used for configuration:
  * input_file: Applied to an `<input name="a">`, this class name will automatically add the field value in the configuration object as `config.inputs.a = <value>`
  * input_list: Applied to a `<div>`, this class will transform all the checked checkboxes in the div into inputs in the config object.
  * output_zone: Must be applied to span with class output_zone and containing an imput `<span class="output_zone"><input name="a"></span>`.
The result in the configuration object will be `config.outputs.a = <value>`
  * param_value: Applied to an `<input name="a">`, this class name will automatically add the field value in the configuration object as `config.params.a = <value>`

* Update download link: In output_zone spans you can add download links.
Those links will automatically updated with a reference to the file value in the input HTML element of the zone.
Here an example of download link added:
```html
<span class="output_zone">
	<input type="text" name="a">
	<a href="" download><img src="/imgs/download.png" class="download"/></a>
</span>
```

### Hidden options
For many softwares all the options are not always needed.
So we provide a the possibility of using a div element with the class "options" that will be hidden by default.
A button "More options" is added instead of this div.
This button show all the hidden options.
```html
<div class="options">
	<p>Similarity: <input type="text" name="similarity" value="0.97"></p>
</div>
```





