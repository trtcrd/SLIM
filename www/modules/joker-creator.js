

class jokercreatorModule extends Module {
	constructor (params) {
		super ("joker-creator", "");

		this.params = params;
	}

	onLoad () {

		super.onLoad();
		var that = this;
		that.update_input_lists();
		
		var that = this;
		var suggest = this.dom.getElementsByClassName('input_text_suggest')[0];
		suggest.onchange = () => {
			var input_lists = document.getElementsByClassName('input_list_suggest');
			var output_file = that.dom.getElementsByClassName('output_zone')[0].getElementsByTagName('input')[0];
			

			console.log("jokercreator.js: suggest.onchange");

			// for (let id_list=0 ; id_list<input_lists.length ; id_list++) {
				// let input_list = input_lists[id_list];
			let input_list = input_lists[0];
			let checked = [];
			
			// Save checked files
			let inputs = input_list.getElementsByTagName('input');
			for (let input_id=0 ; input_id<inputs.length ; input_id++) {
				let input = inputs[input_id];
				if (input.checked)
					checked.push(input.name);
			}


			// Recreate file list
			input_list.innerHTML = "";

			let classes = input_list.classList;
			let filenames = file_manager.getFiles(classes);
			// from filenames keep those that contain the suggest value

			

			filenames = filenames.filter(function (filename) {
				if (suggest.value.includes('*')) {
					var begin = suggest.value.indexOf('*');
					var end = suggest.value.lastIndexOf('*');
				} else {
					var begin = suggest.value;
					var end = suggest.value;
				}
				return filename.includes(begin, end);
				// filename = filename.includes(end);
				// return filename.includes(suggest.value);
				// return filename;
			});
			var html = '';
			for (let file_id in filenames) {
				let filename = filenames[file_id];
				console.log("filename");
				console.log(filename);
				console.log("output_file");
				console.log(output_file.value);
				if (filename != output_file.value) {
					// html += '<p><input type="checkbox" name="' + filename + '" class="checklist"'
					// 	+ (checked.includes(filename) ? ' checked' : '') + '> ' + filename + '</p>';
					html += '<p> ' + filename + '</p>';
				}
			}

			// Add reloaded inputs
			for (let id_check=0 ; id_check<checked.length ; id_check++) {
				let check = checked[id_check];

				if (!filenames.includes(check)) {
					html += '<p><input type="checkbox" name="' + check
						+ '" class="checklist" checked> ' + check + '</p>';
					// html += '<p> ' + check + '</p>';
				}
			}
			input_list.innerHTML = html;
			// }

			function findCommonPattern(strings) {
				if (strings.length === 0) return '';
			  
				// Function to find the longest common prefix
				function longestCommonPrefix(strs) {
				  if (strs.length === 0) return '';
				  let prefix = strs[0];
				  for (let i = 1; i < strs.length; i++) {
					while (strs[i].indexOf(prefix) !== 0) {
					  prefix = prefix.substring(0, prefix.length - 1);
					  if (prefix === '') return '';
					}
				  }
				  return prefix;
				}
			  
				// Function to find the longest common suffix
				function longestCommonSuffix(strs) {
				  if (strs.length === 0) return '';
				  let suffix = strs[0];
				  for (let i = 1; i < strs.length; i++) {
					while (!strs[i].endsWith(suffix)) {
					  suffix = suffix.substring(1);
					  if (suffix === '') return '';
					}
				  }
				  return suffix;
				}
			  
				// Find the longest common prefix and suffix
				const prefix = longestCommonPrefix(strings);
				const suffix = longestCommonSuffix(strings);
			  
				// Replace the unique parts with '*'
				return strings.map(str => {
				  const start = prefix.length;
				  const end = str.length - suffix.length;
				  return prefix + '*' + suffix;
				});
			}
			const commonPattern = findCommonPattern(filenames);
			console.log(commonPattern);

			output_file.value = commonPattern[0];
			// // this.out_files = [consens.value];
			output_file.onchange();
		};

	}
	update_input_lists () {
		var input_lists = document.getElementsByClassName('input_list_suggest');

		console.log("jokercreator.js: update_input_lists_suggest");

		for (let id_list=0 ; id_list<input_lists.length ; id_list++) {
			let input_list = input_lists[id_list];
			let checked = [];
			
			// Save checked files
			let inputs = input_list.getElementsByTagName('input');
			for (let input_id=0 ; input_id<inputs.length ; input_id++) {
				let input = inputs[input_id];
				if (input.checked)
					checked.push(input.name);
			}


			// Recreate file list
			input_list.innerHTML = "";

			let classes = input_list.classList;
			let filenames = file_manager.getFiles(classes);
			var html = '';
			for (let file_id in filenames) {
				let filename = filenames[file_id];
				html += '<p><input type="checkbox" name="' + filename + '" class="checklist"'
					+ (checked.includes(filename) ? ' checked' : '') + '> ' + filename + '</p>';
			}

			// Add reloaded inputs
			for (let id_check=0 ; id_check<checked.length ; id_check++) {
				let check = checked[id_check];

				if (!filenames.includes(check)) {
					html += '<p><input type="checkbox" name="' + check
						+ '" class="checklist" checked> ' + check + '</p>';
				}
			}
			input_list.innerHTML = html;
		}
	}

	getConfiguration () {
		var config = super.getConfiguration();
		console.log("jokercreator.js: getConfiguration");
		console.log(config);
		config.inputs.filechecked = file_manager.getFiles()[0];

		config.inputs.suggestion = config.outputs.joker;
		config.outputs.joker = undefined;
		// config.outputs.joker= config.outputs.joker.replace('*','$');
		console.log("jokercreator.js: getConfiguration2");
		console.log(config);

		return config;
	}

	

};


module_manager.moduleCreators['joker-creator'] = (params) => {
	return new jokercreatorModule(params);
};

