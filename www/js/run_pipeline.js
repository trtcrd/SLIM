
// --- Modules additions/deletions ---
var add_button = document.querySelector('#add_module');
var modules_div = document.querySelector('#modules');

add_button.onclick = function () {
	var modules_list = document.querySelector('#module_list');
	module_manager.createModule(modules_list.value, {});
};


// --- Pipeline execution ---
var run = document.querySelector('#start');

var get_mail_value = () => {
	var mail_area = document.getElementById('mail');
	return mail_area ? mail_area.value.trim() : "";
};

var get_job_title_value = () => {
	var job_title_area = document.getElementById('job_title');
	return job_title_area ? job_title_area.value.trim() : "";
};

var get_job_title_config_filename = (job_title) => {
	let safe = String(job_title || "")
		.trim()
		.toLowerCase()
		.replace(/[^a-z0-9._-]+/g, "_")
		.replace(/^_+|_+$/g, "")
		.substring(0, 80);

	return safe == "" ? "pipeline.conf" : safe + "_pipeline.conf";
};

var get_config = () => {
	var config = {
		token:exec_token
	};

	let mail_value = get_mail_value();
	if (mail_value != "")
		config.mail = mail_value;

	let job_title_value = get_job_title_value();
	if (job_title_value != "")
		config.job_title = job_title_value;

	for (var idx in module_manager.modules) {
		var module = module_manager.modules[idx];
		var module_config = module.getConfiguration();

		if (module.name == 'wildcard-creator') {
			let suggest = module.dom.getElementsByClassName('input_text_suggest')[0];

			if (!module_config.params)
				module_config.params = {};

			module_config.params.suggestion = suggest ? suggest.value : "";
		}

		config[module.id] = {
			name: module.name,
			params: module_config
		};
	}

	return config;
};

var status_interval;
run.onclick = function () {
	// Verify mail address
	let mail_value = get_mail_value();
	if (mail_value == "" || (mail_value.length > 5 && mail_value.includes('@')))
		document.getElementsByClassName('gui_warnings')[1].innerHTML = '';
	else {
		document.getElementsByClassName('gui_warnings')[1].innerHTML = '<p>A valid mail address should be entered</p>';
		return;
	}

	// Get config
	var config = get_config();
	if (typeof store_wildcard_creator_suggestions != "undefined")
		store_wildcard_creator_suggestions(config);
	var file = new File([JSON.stringify(config)], "config.log", {
		type: "text/plain",
	});

	// Form
	var formData = new FormData();
	formData.append("config", file);
	formData.append("token", exec_token);
	if (mail_value != "")
		formData.append("mail", mail_value);

	// Request sender
	var request = new XMLHttpRequest();
	request.open("POST", "/run");
	request.onload = function () {
		if (request.status < 200 || request.status >= 300) {
			document.getElementsByClassName('gui_warnings')[1].innerHTML =
				'<p>' + (request.responseText || 'Unable to start pipeline') + '</p>';
			run.disabled = false;
			clearInterval(status_interval);
		}
	};
	request.send(formData);
	run.disabled = true;
	
	status_interval = setInterval(()=>{update_run_status(exec_token);}, 5000);
	// Timeout added to wait for the server updated status
	setTimeout(() => {update_run_status(exec_token);}, 100);
};


// --- Status update ---

var update_run_status = (token, callback=(status)=>{}) => {
	let warnings_areas = document.getElementsByClassName("gui_warnings");

	$.get('/status?token=' + token).done((data) => {
		var server_status = JSON.parse(data);

		if (!server_status.global || !server_status.messages)
			return;

		// Print the messages from the server.
		msgs = "";
		for (let idx=0 ; idx<server_status.messages.length ; idx++) {
			let msg = server_status.messages[idx];
			msgs += '<p>' + html_escape(msg) + '</p>';
		}
		if (server_status.msg)
			msgs += '<pre>' + html_escape(server_status.msg) + '</pre>';

		for (let idx=0 ; idx<warnings_areas.length ; idx++) {
			warnings_areas[idx].innerHTML = msgs;
		}

		// Stop the update when the run is over
		if (server_status.global == 'ended' || server_status.global == 'aborted') {
			clearInterval(status_interval);
			run.disabled = false;

			for (var key in server_status.jobs)
				if (!['ended', 'warnings'].includes(server_status.jobs[key]))
					server_status.jobs[key] = 'aborted'
		}

		// Update the GUI
		for (var idx in modules_div.children) {
			var element = modules_div.children[idx];
			if (element.tagName != 'DIV')
				continue;

			var divIdx = element.idx;

			// Remove previous class values
			var possible_status = ['waiting', 'running', 'ready', 'ended', 'aborted', 'warnings'];
			for (var sIdx in possible_status) {
				element.classList.remove(possible_status[sIdx]);
			}

			// Add the new status
			if (server_status.jobs[divIdx]) {
				element.classList.add(server_status.jobs[divIdx]);
				var status = element.getElementsByClassName('status')[0];
				status.innerHTML = server_status.jobs[divIdx];

				if (server_status.sub_jobs && server_status.sub_ended &&
						server_status.jobs[divIdx] == "running") {
					status.innerHTML += ' (' + server_status.sub_ended;
					status.innerHTML += '/' + server_status.sub_jobs + ')';
				}
			}
		}

		callback(server_status);
	}).fail(() => {
		if (typeof show_server_health_alert != "undefined") {
			show_server_health_alert(
				'SLIM server is not responding',
				'The server may be restarting. Pipeline status will refresh when it comes back.',
				''
			);
		}
	});
}
