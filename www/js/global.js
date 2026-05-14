

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

	// // Reload mail address
	// document.getElementById('mail').value = log.mail;
	// delete log.mail;

	// For each module in the log file
	for (let idx in log) {
		let soft = log[idx];
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
	console.log("pipeline.conf wildcard suggestions:",
		Object.values(conf)
			.filter((module) => module.name == 'wildcard-creator')
			.map((module) => module.params.params.suggestion));
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
