// This file contains the code to upload files to the server
var up_formData;
var up_filenames = [];
var up_processing_interval = null;

var upload_html_escape = (txt) => {
	if (typeof html_escape != "undefined")
		return html_escape(txt);

	return String(txt)
		.replace(/&/g, '&amp;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;')
		.replace(/"/g, '&quot;')
		.replace(/'/g, '&#039;');
};

var set_upload_message = (message, is_error=false) => {
	$('.progress-bar').html(message);

	let warnings_areas = document.getElementsByClassName("gui_warnings");
	let html = is_error ? '<p>' + upload_html_escape(message) + '</p>' : '';
	for (let idx=0 ; idx<warnings_areas.length ; idx++)
		warnings_areas[idx].innerHTML = html;
};

var clear_upload_processing_interval = () => {
	if (up_processing_interval) {
		clearInterval(up_processing_interval);
		up_processing_interval = null;
	}
};

var set_start_disabled = (disabled) => {
	let start = document.querySelector('#start');
	if (start)
		start.disabled = disabled;
};

// this will select the files to upload
document.querySelector("#up_files").onchange = function (event) {
	var files = event.target.files;
	up_filenames = [];
	
	if (files.length > 0){
		// One or more files selected, process the file upload

		// create a FormData object which will be sent as the data payload in the
		// AJAX request
		up_formData = new FormData();
		up_formData.append('token', exec_token);

		// loop through all the selected files
		for (var i = 0; i < files.length; i++) {
		  var file = files[i];

		  // add the files to up_formData object for the data payload
		  up_formData.append('uploads[]', file, file.name);
		  up_filenames.push(file.name);
		}

	  }

}



// this seems to be submiting the files from the up_files 
document.querySelector("#up_submit").onclick = function (event) {
	// Stop stuff happening
	event.stopPropagation();
	event.preventDefault();

	// Read the file content if it's a CSV and store it on the client side
	var file_selector = document.getElementById('up_files');

	// Upload the file
	clear_upload_processing_interval();
	if (!up_formData) {
		set_upload_message('Please select one or more files before uploading.', true);
		return;
	}

	set_upload_message('');
	set_start_disabled(true);
	$.ajax({
		url: '/upload',
		type: 'POST',
		data: up_formData,
		cache:false,
		processData: false, // Don't process the files
		contentType: false, // Set content type to false as jQuery will tell the server its a query string request
		
		success: function(data, textStatus, jqXHR)
		{
				clear_upload_processing_interval();
				if(typeof data.error === 'undefined') {
					set_upload_message('Done');
					set_start_disabled(false);
					file_manager.load_from_server();
				} else {
					// Handle errors here
					set_upload_message('Upload failed: ' + data.error, true);
					set_start_disabled(false);
				}
			},
		error: function(jqXHR, textStatus, errorThrown) {
			// Handle errors here
			clear_upload_processing_interval();
			let message = jqXHR.responseText || errorThrown || textStatus || 'Upload failed';
			set_upload_message('Upload failed: ' + message, true);
			set_start_disabled(false);
		},
		xhr: function() {
			// create an XMLHttpRequest
			let xhr = new XMLHttpRequest();
			let num_wait_files = 0;

			// listen to the 'progress' event
			xhr.upload.addEventListener('progress', function(evt) {

				if (evt.lengthComputable) {
					// calculate the percentage of upload completed
					var percentComplete = evt.loaded / evt.total;
					percentComplete = parseInt(percentComplete * 100);

					// update the Bootstrap progress bar with the new percentage
					$('.progress-bar').text('uploading: ' + percentComplete + '%');
					// $('.progress-bar').width(percentComplete + '%');

					// once the upload reaches 100%, set the progress bar text to done
					if (percentComplete === 100) {
						$('.progress-bar').html('Processing file(s)');

						var event = new Event('new_file');
						event.files = [];
						document.dispatchEvent(event);

						// Verify files that have been converted to linux format
						up_processing_interval = setInterval(
							// Get the file list to process
							()=>{$.get('/convertion?token=' + exec_token).done((data) => {
								data = JSON.parse(data);

								// Update the status
								if (data.length > 0) {
									$('.progress-bar').html('Processing file(s): ' + data.length + ' remaining');
									} else {
										clear_upload_processing_interval();
										$('.progress-bar').html('Done');
										set_start_disabled(false);

										file_manager.load_from_server();
									}
								}).fail(() => {
									clear_upload_processing_interval();
									set_upload_message('Upload processing status is unavailable. The server may be restarting.', true);
									set_start_disabled(false);
								})}
							, 1000
						);
					}
				}

			}, false);

			return xhr;
		}
	});
}



// Print the file list
file_manager.register_observer((manager) => {
	var up_list = document.querySelector("#up_list");
	up_list.innerHTML = '';

	var filenames = [].concat(... Object.values(file_manager.server_files));
	if (filenames.length > 0) {
		up_list.innerHTML = '';
		var ul = document.createElement("ul");
		
		for (var idx in filenames) {
			var filename = filenames[idx];

			var li = document.createElement("li");
			li.innerHTML = '<a href="/data/' + exec_token + '/' + filename + '" download>\
			<img src="/imgs/download.png" class="download"/></a>  ' + filename;
			ul.appendChild(li);
		}
		up_list.appendChild(ul);
	}
});
