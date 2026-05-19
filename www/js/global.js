
var html_escape = (txt) => {
	return String(txt)
		.replace(/&/g, '&amp;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;')
		.replace(/"/g, '&quot;')
		.replace(/'/g, '&#039;');
};

var show_server_health_alert = (title, message, details) => {
	let alert = document.getElementById('server_health_alert');
	if (!alert)
		return;

	let html = '<strong>' + html_escape(title) + '</strong>';
	if (message)
		html += '<p>' + html_escape(message) + '</p>';
	if (details)
		html += '<pre>' + html_escape(details) + '</pre>';
	html += '<button type="button" onclick="dismiss_server_health_alert()">Dismiss</button>';

	alert.innerHTML = html;
	alert.style.display = 'block';
};

var dismiss_server_health_alert = () => {
	let alert = document.getElementById('server_health_alert');
	if (alert)
		alert.style.display = 'none';
};

var check_server_health = () => {
	$.get('/server_status')
	.done((data) => {
		let status = JSON.parse(data);
		if (!status.last_crash || !status.last_crash.timestamp)
			return;

		let seen_key = 'slim_server_crash_seen_' + status.last_crash.timestamp;
		if (localStorage.getItem(seen_key) == 'Y')
			return;

		localStorage.setItem(seen_key, 'Y');
		show_server_health_alert(
			'SLIM server restarted after a crash',
			'The web service has restarted. Any pipeline that was running at the time was marked as aborted.',
			status.last_crash.snippet
		);
	})
	.fail(() => {
		show_server_health_alert(
			'SLIM server is not responding',
			'The server may be restarting. This page will continue checking.',
			''
		);
	});
};

check_server_health();
setInterval(check_server_health, 10000);


// --- Actions on load ---
var on_token_generated = () => {
	// Files loading
	file_manager.load_from_server();

	// Delay the module reconstructions if they are not loaded
	if (module_manager.isLoading()) {
		setTimeout(on_token_generated, 100);
		return;
	}

	// Modules loading
	$.get('/data/' + exec_token + '/pipeline.conf')
	.done((data) => {
		if (data && data != '')
			load_modules(JSON.parse(data));
	});
}

var load_modules = (log) => {
	// Wait for modules loading
	if (module_manager.isLoading() || Object.keys(module_manager.moduleCreators).length == 0) {
		setTimeout(()=>{load_modules (log);}, 50);
		return;
	}

	// Loading a pipeline.conf should replace the current editor state. Keeping
	// previous modules leaves stale output files in autocomplete and can make
	// dependencies appear to exist before they are produced.
	let modules_div = document.querySelector('#modules');
	if (modules_div) {
		modules_div.innerHTML = '';
	}
	module_manager.modules = {};
	file_manager.futur_files = {};
	__next_id = 0;

	// Reload optional mail address when present, but do not treat it as a module.
	if (log.mail) {
		let mail = document.getElementById('mail');
		if (mail)
			mail.value = log.mail;
	}

	// For each module in the log file
	for (let idx in log) {
		let soft = log[idx];
		if (!soft || typeof soft != 'object' || !soft.name || !soft.params)
			continue;

		soft.params.idx = idx;

		// Create the module
		let module = module_manager.createModule (soft.name, soft.params, soft.status);
		if (!module && module_manager.modules[idx])
			module = module_manager.modules[idx];
		restore_wildcard_creator_suggestion(module, soft.params);
	}

	setTimeout(() => {
		restore_wildcard_creator_suggestions_from_log(log);
		if (typeof gui_file_updater != "undefined")
			gui_file_updater.file_trigger();
	}, 0);

	// Update status
	update_run_status(exec_token, (status)=> {
		if (['ready', 'running', 'waiting'].includes(status.global)) {
			// Set update interval
			let inter = setInterval(()=>{
				update_run_status(exec_token, (status) =>{
					if (['ended', 'aborted'].includes(status.global))
						clearInterval(inter);
				});
			}, 5000);

			// Froze the start button
			document.querySelector('#start').disabled = true;
		}
	});
}

var restore_wildcard_creator_suggestions_from_log = (log) => {
	let wildcard_configs = [];
	for (let idx in log) {
		if (log[idx].name == 'wildcard-creator')
			wildcard_configs.push(log[idx]);
	}

	let wildcard_modules = [];
	for (let idx in module_manager.modules) {
		if (module_manager.modules[idx].name == 'wildcard-creator')
			wildcard_modules.push(module_manager.modules[idx]);
	}

	for (let idx=0 ; idx<wildcard_configs.length ; idx++) {
		restore_wildcard_creator_suggestion(wildcard_modules[idx], wildcard_configs[idx].params);
	}
};

var restore_wildcard_creator_suggestion = (module, params) => {
	if (!module || module.name != 'wildcard-creator')
		return;

	if (!params || !params.params || params.params.suggestion === undefined)
		return;

	let suggest = module.dom.getElementsByClassName('input_text_suggest')[0];

	if (!suggest)
		return;

	suggest.value = params.params.suggestion;

	if (suggest.onchange)
		suggest.onchange();
};



// --- Token managment ---
var exec_token = '';

// Get token from url
var url = window.location.href;
var url_split = url.split('?')[1];
var url_params = {};
if (url_split) {
	var split = url_split.split('&');
	for (var idx=0 ; idx<split.length ; idx++) {
		var key_val = split[idx].split('=');
		url_params[key_val[0]] = key_val[1];
	}

	if (url_params.token)
		exec_token = url_params.token;
}

// Generate exec token
$.get('/token_generation' + (exec_token == '' ? '' : '?token=' + exec_token))
.done(function(data) {
	exec_token = data;
	history.pushState({urlPath:'/?token=' + data},'', '/?token=' + data);
	on_token_generated();
});



// --- Save/Upload config ---
var down_conf = document.getElementById("down_conf");
var reset_conf = document.getElementById("reset_conf");
var up_conf = document.getElementById("up_conf_hidden");

reset_conf.onclick = () => {
	window.location = window.location.href.split("?")[0];
}

document.getElementById("up_conf").onclick = () => {
	up_conf.click();
};

// Conf download
down_conf.onclick = () => {
	var conf = get_config();
	store_wildcard_creator_suggestions(conf);
	delete conf.token;
	var data = new Blob([JSON.stringify(conf)], {type: 'text/plain'});
	var textFile = window.URL.createObjectURL(data);
	var link = document.createElement('a');
	link.href = textFile;
	link.download = "pipeline.conf";
	link.click();
};

// Conf upload
up_conf.onchange = () => {
	var file = up_conf.files[0];
	var reader = new FileReader();

	reader.onload = function(e) {
		var json = JSON.parse(e.target.result);

		load_modules(json);
	};
	reader.readAsText(file);
};

var store_wildcard_creator_suggestions = (conf) => {
	for (let idx in module_manager.modules) {
		let module = module_manager.modules[idx];

		if (module.name != 'wildcard-creator' || !conf[module.id])
			continue;

		let suggest = module.dom.getElementsByClassName('input_text_suggest')[0];

		if (!conf[module.id].params)
			conf[module.id].params = {};
		if (!conf[module.id].params.params)
			conf[module.id].params.params = {};

		conf[module.id].params.params.suggestion = suggest ? suggest.value : "";
	}

	return conf;
};
