
class FileManager {
	constructor () {
		this.server_files = {};
		this.futur_files = {};

		this.addObs = [];
		this.rmvObs = [];

		this.eventListeners();

		this.timeout_add = null;
		this.timeout_rmv = null;
	}

	load_from_server () {
		var that = this;
		$.get('/list?token=' + exec_token, (data) => {
			// Get alll values in an array of array
			var previous_files = Object.values(that.server_files);
			// Reduce array dimentions
			if (previous_files.length > 1)
				previous_files = previous_files.reduce((a, b) => {return a.concat(b)});
			else if (previous_files.length == 1)
				previous_files = previous_files[0];
			// Transform into set for set operations
			
			// Compute intersection
			previous_files = new Set(previous_files);
			var current_files = new Set(data);
			var intersection = new Set([...previous_files].filter(x => current_files.has(x)));

			// Compute added files
			var added = new Set([...current_files].filter(x => !intersection.has(x)));
			var event = new Event('new_file');
			event.files = [...added];
			if (event.files.length > 0)
				document.dispatchEvent(event);

			// Compute removed files
			var removed = new Set([...previous_files].filter(x => !intersection.has(x)));
			var event = new Event('rmv_file');
			event.files = [...removed];
			if (event.files.length > 0)
				document.dispatchEvent(event);
		});
	}

	get_download_link (filename) {
		var link = '/data/' + exec_token + '/' + filename;
		if (filename.includes('*'))
			link += '.tar.gz';

		return link;
	}

	get_autocomplete_format (files) {
		var formated = [];

		for (var idx in files) {
			var filename = files[idx];
			formated.push({value:filename, data:filename});
		}

		return formated;
	}

	getFiles (extentions = []) {
		extentions = Array.from(extentions);

		var files = this.getUploadedFiles();
		for (var futur_ext in this.futur_files) {
			files = files.concat(this.futur_files[futur_ext]);
		}

		files = files.concat(this.getCurrentOutputFiles());

		if (extentions.length == 0)
			return Array.from(new Set(files));

		files = files.filter((filename) => {
			return this.fileMatchesExtentions(filename, extentions);
		});

		return Array.from(new Set(files));
	}

	getFilesBeforeElement (extentions = [], element) {
		extentions = Array.from(extentions);

		var files = this.getUploadedFiles();
		files = files.concat(this.getPreviousOutputFiles(element));

		if (extentions.length == 0)
			return Array.from(new Set(files));

		files = files.filter((filename) => {
			return this.fileMatchesExtentions(filename, extentions);
		});

		return Array.from(new Set(files));
	}

	getUploadedFiles () {
		var files = [];

		for (var server_ext in this.server_files) {
			files = files.concat(this.server_files[server_ext]);
		}

		return files;
	}

	getPreviousOutputFiles (element) {
		if (typeof document == "undefined" || !element)
			return [];

		var modules = document.querySelectorAll('#modules > .module');
		var files = [];

		for (let idx=0 ; idx<modules.length ; idx++) {
			if (modules[idx] == element)
				break;

			let outputs = modules[idx].querySelectorAll('.output_zone input');
			for (let out_idx=0 ; out_idx<outputs.length ; out_idx++) {
				let filename = outputs[out_idx].value;

				if (filename)
					files.push(filename);
			}
		}

		return files;
	}

	getCurrentOutputFiles () {
		if (typeof document == "undefined")
			return [];

		var outputs = document.querySelectorAll('.output_zone input');
		var files = [];

		for (let idx=0 ; idx<outputs.length ; idx++) {
			let filename = outputs[idx].value;

			if (filename)
				files.push(filename);
		}

		return files;
	}

	fileMatchesExtentions (filename, extentions) {
		var requested = extentions.map((extention) => {
			return extention.toLowerCase();
		});
		var aliases = this.getFileExtentionAliases(filename);

		for (let idx=0 ; idx<aliases.length ; idx++) {
			if (requested.includes(aliases[idx].toLowerCase()))
				return true;
		}

		return false;
	}

	getFileExtentionAliases (filename) {
		var lower = filename.toLowerCase();
		var aliases = [];

		if (lower.endsWith('.fastq.gz')) {
			aliases.push('fastq', 'fq', 'gz');
		} else if (lower.endsWith('.fq.gz')) {
			aliases.push('fastq', 'fq', 'gz');
		} else if (lower.endsWith('.fasta.gz')) {
			aliases.push('fasta', 'fa', 'gz');
		} else if (lower.endsWith('.fa.gz')) {
			aliases.push('fasta', 'fa', 'gz');
		} else if (filename.includes('.')) {
			aliases.push(filename.substr(filename.lastIndexOf('.') + 1));
		}

		if (aliases.includes('fq') && !aliases.includes('fastq'))
			aliases.push('fastq');
		if (aliases.includes('fastq') && !aliases.includes('fq'))
			aliases.push('fq');
		if (aliases.includes('fa') && !aliases.includes('fasta'))
			aliases.push('fasta');
		if (aliases.includes('fasta') && !aliases.includes('fa'))
			aliases.push('fa');

		return aliases;
	}

	register_observer (callback) {
		this.addObs.push(callback);
		this.rmvObs.push(callback);
	}

	register_add_observer (callback) {
		this.addObs.push(callback);
	}

	register_rmv_observer (callback) {
		this.rmvObs.push(callback);
	}

	effective_add_notification () {
		let event = new Event('new_file');
		event.files = Array.from(new Set(this.new_files));

		for (let idx in this.addObs) {
			let callback = this.addObs[idx];
			callback(this, event);
		}
	}

	notifyAdd (params) {
		var that = this;

		if (this.timeout_add == null) {
			this.new_files = [];

			this.timeout_add = setTimeout(function() {
				that.effective_add_notification();
				that.timeout_add = null;
			}, 10);
		} else {
			clearTimeout(this.timeout_add);
			this.timeout_add = setTimeout(function() {
				that.effective_add_notification();
				that.timeout_add = null;
			}, 10);
		}
		this.new_files = this.new_files.concat(params.files);
	}

	effective_rmv_notification () {
		let event = new Event('rmv_file');
		event.files = Array.from(new Set(this.rmv_files));

		for (let idx in this.rmvObs) {
			let callback = this.rmvObs[idx];
			callback(this, event);
		}
	}

	notifyRmv (params) {
		var that = this;

		if (this.timeout_rmv == null) {
			this.rmv_files = [];

			this.timeout_rmv = setTimeout(function() {
				that.effective_rmv_notification();
				that.timeout_rmv = null;
			}, 10);
		} else {
			clearTimeout(this.timeout_rmv);
			this.timeout_rmv = setTimeout(function() {
				that.effective_rmv_notification();
				that.timeout_rmv = null;
			}, 10);
		}
		this.rmv_files = this.rmv_files.concat(params.files);
	}

	eventListeners () {
		var that = this;

		// When a file is uploaded
		document.addEventListener('new_file', (event) => {
			for (var idx in event.files) {
				var filename = event.files[idx];
				var extention = filename.substr(filename.lastIndexOf('.')+1);

				// Create new array if doesn't exist
				if (that.server_files[extention] == undefined)
					that.server_files[extention] = [];

				if (that.server_files[extention].indexOf(filename) == -1) {
					that.server_files[extention].push(filename);
				}
			}
			that.notifyAdd(event);
		});

		// When a file is deleted
		document.addEventListener('rmv_file', (event) => {
			for (var idx in event.files) {
				var filename = event.files[idx];
				var extention = filename.substr(filename.lastIndexOf('.')+1);

				if (that.server_files[extention] != undefined) {
					var file_idx = that.server_files[extention].indexOf(filename);
					if (file_idx != -1) {
						that.server_files[extention].splice(file_idx, 1);
					}
				}
			}
			that.notifyRmv(event);
		});

		// When an output is defined
		document.addEventListener('new_output', (event) => {
			for (var idx in event.files) {
				var filename = event.files[idx];
				var extention = filename.substr(filename.lastIndexOf('.')+1);

				// Create new array if doesn't exist
				if (that.futur_files[extention] == undefined)
					that.futur_files[extention] = [];

				if (that.futur_files[extention].indexOf(filename) == -1)
					that.futur_files[extention].push(filename);
			}
			that.notifyAdd(event);
		});

		// When a file is undefined
		document.addEventListener('rmv_output', (event) => {
			for (var idx in event.files) {
				var filename = event.files[idx];
				var extention = filename.substr(filename.lastIndexOf('.')+1);

				if (that.futur_files[extention] != undefined) {
					var file_idx = that.futur_files[extention].indexOf(filename);
					if (file_idx != -1)
						that.futur_files[extention].splice(file_idx, 1);
				}
			}
			that.notifyRmv(event);
		});
	}
}

var file_manager = new FileManager ();
