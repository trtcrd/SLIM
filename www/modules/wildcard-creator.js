

class wildcardcreatorModule extends Module {
	constructor (params) {
		super ("wildcard-creator", "/man/sections/wildcard_creator.md");

		this.params = params;
	}

	onLoad () {

		super.onLoad();
		var that = this;
		that.update_input_lists();
		
		var suggest = this.dom.getElementsByClassName('input_text_suggest')[0];

		if (this.params && this.params.params && this.params.params.suggestion !== undefined) {
			suggest.value = this.params.params.suggestion;
		} else if (this.params && this.params.suggestion !== undefined) {
			suggest.value = this.params.suggestion;
		} else if (suggest.value == "undefined") {
			suggest.value = "";
		}

		suggest.onchange = () => {
			var input_list = that.dom.getElementsByClassName('input_list_suggest')[0];
			var output_file = that.dom.getElementsByClassName('output_zone')[0].getElementsByTagName('input')[0];
			
			// console.log("wildcardcreator.js: suggest.onchange");

			if (!input_list) {
				return;
			}

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
			let filenames = file_manager.getFilesBeforeElement(classes, that.dom);
			// from filenames keep those that contain the suggest value

			

			filenames = filenames.filter(function (filename) {
				// console.log(filename)
				if (suggest.value.includes('*')) {
					var begin = suggest.value.indexOf('*');
					var beforeAsterisk = suggest.value.substring(0, begin);
					var end = suggest.value.lastIndexOf('*');
					var afterAsterisk = suggest.value.substring(end + 1);
					// console.log(beforeAsterisk + ' & ' + afterAsterisk)
					if (filename.includes(beforeAsterisk)){
						// remove the first match in the filename with begin
						filename = filename.replace(beforeAsterisk, '');
						return filename.includes(afterAsterisk)					
					} else {
						return false
					}
				} else {
					return filename.includes(suggest.value);
				}
				// filename = filename.includes(end);
				// return filename.includes(suggest.value);
				// return filename;
			});
			var html = '';
			for (let file_id in filenames) {
				let filename = filenames[file_id];
				// console.log("filename");
				// console.log(filename);
				// console.log("output_file");
				// console.log(output_file.value);
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
			// console.log(commonPattern);

			var output_value = commonPattern[0] ? commonPattern[0] : '';
			if (output_file.value != output_value) {
				output_file.value = output_value;
				// // this.out_files = [consens.value];
				output_file.onchange();
			}

			if (typeof gui_file_updater != "undefined") {
				gui_file_updater.file_trigger();
			}
		};
		suggest.oninput = suggest.onchange;

		if (suggest.value) {
			suggest.onchange();
		}

		setTimeout(() => {
			if (suggest.value) {
				suggest.onchange();
			} else {
				that.update_input_lists();
			}
		}, 0);

		file_manager.register_observer(() => {
			if (suggest.value) {
				suggest.onchange();
			}
		});

	}
	update_input_lists () {
		var input_lists = this.dom.getElementsByClassName('input_list_suggest');

		// console.log("wildcardcreator.js: update_input_lists_suggest");

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
			let filenames = file_manager.getFilesBeforeElement(classes, this.dom);
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
		var suggest = this.dom.getElementsByClassName('input_text_suggest')[0];

		if (!config.params) {
			config.params = {};
		}

		if (suggest) {
			config.params.suggestion = suggest.value;
		}

		if (config.outputs && config.outputs.joker) {
			config.params.archive_joker = config.outputs.joker;
		}

		config.inputs = {};

		return config;
	}



	

};


module_manager.moduleCreators['wildcard-creator'] = (params) => {
	return new wildcardcreatorModule(params);
};
