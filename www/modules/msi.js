
class msiModule extends Module {
	constructor (params) {
		super ("msi", "https://github.com/nunofonseca/msi?tab=readme-ov-file#Overview");

		this.params = params;
	}

	onLoad () {

		this.defineIO();
		super.onLoad();
		gui_file_updater.file_trigger();
	}

	defineIO () {
		let input_text = this.dom.getElementsByClassName('fastq')[0];

		this.out_area = this.dom.getElementsByClassName('file_list')[0];
		// Reload outputs
		if (this.params.outputs) {
			var html = '';
			for (var filename in this.params.outputs) {
				this.out_files.push(filename)
				html += this.format_output(filename);
			}
			this.out_area.innerHTML = html;
		}

		// Change the output files using the tags file
		var that = this;
		input_text.onchange = () => {
			var idx = input_text.value.indexOf('.fastq');
			if (idx == -1)
				return;
			that.generate_outputfields(()=>{})
		};
	}

	generate_outputfields (callback) {
		var that = this;
		that.out_area.innerHTML = "";

		let runstats = 'running.stats.tsv.gz';
		let resultsfasta = 'results.fasta.gz';
		let sample_centroids = 'sample_centroids.tar.gz';
		// let resultstsv = 'results.tsv.gz';
		// let binrestsv = 'binres.tsv.gz';
		// let bintsv = 'bin.tsv.gz';

		let out_files = [runstats, resultsfasta]; //, resultstsv, binrestsv, bintsv];
		
		out_files.sort();
		for (let idx in out_files) {
			let filename = out_files[idx];
			that.out_area.innerHTML += that.format_output(filename);
		}
		that.out_area.innerHTML += '<p>centroids_of_samples_complesed' +
			'  <a href="' + file_manager.get_download_link(sample_centroids) +
			'" download><img src="/imgs/download.png" class="download"></a></p>';

		// Notify the file adds
		var event = new Event('new_output');
		event.files = out_files;
		document.dispatchEvent(event);

		that.out_files = out_files;
	}

	format_output(filename) {
		return '<p>' + filename +
		'  <a href="' + file_manager.get_download_link(filename) +
		'" download><img src="/imgs/download.png" class="download"></a></p>';
	}

};


module_manager.moduleCreators.msi = (params) => {
	return new msiModule(params);
};

