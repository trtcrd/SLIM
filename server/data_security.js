const fs = require('fs');
const path = require('path');

const accounts = require('./accounts.js');
const mailer = require('./mail_manager.js');

const DATA_DIR = '/app/data';
const SECURE_MARKER = '.secured_uploads.json';
const UPLOAD_MANIFEST = '.uploaded_files.json';

let safe_title = (value) => {
	return String(value || '').trim().replace(/[\r\n]+/g, ' ').substring(0, 120);
};

let valid_token = (token) => {
	return /^[A-Za-z0-9]{30}$/.test(String(token || ''));
};

let token_dir = (token) => {
	return path.join(DATA_DIR, token);
};

let read_json = (filename, fallback) => {
	try {
		if (!fs.existsSync(filename))
			return fallback;

		return JSON.parse(fs.readFileSync(filename, 'utf8'));
	} catch (err) {
		return fallback;
	}
};

let write_json = (filename, value) => {
	fs.writeFileSync(filename, JSON.stringify(value, null, 2));
};

let sanitize_relative_path = (filename) => {
	if (typeof filename != 'string')
		return null;
	if (filename.includes('\0') || filename.includes('*') || filename.includes('€'))
		return null;

	let normalized = path.normalize(filename);
	if (normalized == '.' || path.isAbsolute(normalized) || normalized.startsWith('..') || normalized.includes('/../') || normalized.includes('\\..\\'))
		return null;

	return normalized;
};

let unique_files = (files) => {
	let out = [];
	let seen = new Set();

	for (let idx=0 ; idx<files.length ; idx++) {
		let filename = sanitize_relative_path(files[idx]);
		if (!filename || seen.has(filename))
			continue;

		seen.add(filename);
		out.push(filename);
	}

	return out;
};

let list_visible_files = (token) => {
	let directory = token_dir(token);
	if (!fs.existsSync(directory))
		return [];

	return fs.readdirSync(directory, {withFileTypes: true})
		.filter((entry) => entry.isFile())
		.map((entry) => entry.name)
		.filter((name) => {
			if (name.endsWith('.log') || name.endsWith('.conf'))
				return false;
			if (name.startsWith('.'))
				return false;
			if (!name.includes('.'))
				return false;
			if (/^[a-f0-9]{24,}$/i.test(name))
				return false;
			if (/^upload_[A-Za-z0-9_-]+$/.test(name))
				return false;
			return true;
		});
};

let generate_token = () => {
	let possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

	while (true) {
		let token = '';
		for (let idx=0 ; idx<30 ; idx++)
			token += possible.charAt(Math.floor(Math.random() * possible.length));

		if (!fs.existsSync(token_dir(token)))
			return token;
	}
};

exports.is_secured = (token) => {
	return valid_token(token) && fs.existsSync(path.join(token_dir(token), SECURE_MARKER));
};

exports.read_upload_manifest = (token) => {
	if (!valid_token(token))
		return [];

	let files = read_json(path.join(token_dir(token), UPLOAD_MANIFEST), []);
	return Array.isArray(files) ? unique_files(files) : [];
};

exports.write_upload_manifest = (token, files) => {
	if (!valid_token(token) || !fs.existsSync(token_dir(token)))
		return;

	write_json(path.join(token_dir(token), UPLOAD_MANIFEST), unique_files(files));
};

exports.record_uploaded_file = (token, filename) => {
	if (!valid_token(token) || !fs.existsSync(token_dir(token)))
		return;

	let file = sanitize_relative_path(filename);
	if (!file)
		return;

	let files = exports.read_upload_manifest(token);
	if (!files.includes(file)) {
		files.push(file);
		exports.write_upload_manifest(token, files);
	}
};

let copy_initial_files = (source_token, destination_token, requested_files) => {
	let source_dir = token_dir(source_token);
	let destination_dir = token_dir(destination_token);
	let manifest_files = exports.read_upload_manifest(source_token);
	let candidates = manifest_files.length > 0 ? manifest_files : requested_files;

	if (candidates.length == 0)
		candidates = list_visible_files(source_token);

	let copied = [];
	let files = unique_files(candidates);

	for (let idx=0 ; idx<files.length ; idx++) {
		let filename = files[idx];
		let source = path.resolve(source_dir, filename);
		let destination = path.resolve(destination_dir, filename);

		if (!source.startsWith(path.resolve(source_dir) + path.sep))
			continue;
		if (!destination.startsWith(path.resolve(destination_dir) + path.sep))
			continue;
		if (!fs.existsSync(source) || !fs.statSync(source).isFile())
			continue;

		fs.mkdirSync(path.dirname(destination), {recursive: true});
		fs.copyFileSync(source, destination);
		copied.push(filename);
	}

	return copied;
};

exports.expose = function (app) {
	app.get('/secure-data/status', function (req, res) {
		let token = String(req.query.token || '');
		if (!valid_token(token) || !fs.existsSync(token_dir(token))) {
			res.status(404).send(JSON.stringify({secured: false}));
			return;
		}

		let marker = read_json(path.join(token_dir(token), SECURE_MARKER), {});
		res.send(JSON.stringify({
			secured: exports.is_secured(token),
			job_title: marker.job_title || '',
			files: exports.read_upload_manifest(token)
		}));
	});

	app.post('/secure-data', function (req, res) {
		let source_token = String(req.body.token || '').trim();
		let job_title = safe_title(req.body.job_title);
		let mail = String(req.body.mail || '').trim();
		let requested_files = Array.isArray(req.body.files) ? req.body.files : [];

		if (!valid_token(source_token) || !fs.existsSync(token_dir(source_token))) {
			res.status(403).send(JSON.stringify({error: 'Invalid token'}));
			return;
		}
		if (job_title == '') {
			res.status(400).send(JSON.stringify({error: 'A job title is required to secure uploaded data.'}));
			return;
		}
		if (mail == '' || !mail.includes('@')) {
			res.status(400).send(JSON.stringify({error: 'A valid email address is required to secure uploaded data.'}));
			return;
		}

		let secure_token = generate_token();
		let secure_dir = token_dir(secure_token);
		fs.mkdirSync(secure_dir, {recursive: true});

		let copied_files = copy_initial_files(source_token, secure_token, requested_files);
		if (copied_files.length == 0) {
			fs.rmSync(secure_dir, {recursive: true, force: true});
			res.status(400).send(JSON.stringify({error: 'No uploaded files were found to secure.'}));
			return;
		}

		let url = req.protocol + '://' + req.get('host') + '/?token=' + secure_token;
		let marker = {
			secured: true,
			source_token: source_token,
			job_title: job_title,
			created_at: new Date().toISOString(),
			copied_files: copied_files
		};

		write_json(path.join(secure_dir, SECURE_MARKER), marker);
		exports.write_upload_manifest(secure_token, copied_files);
		write_json(path.join(secure_dir, 'pipeline.conf'), {job_title: job_title});

		accounts.tokens[secure_token] = secure_token;
		mailer.mails[secure_token] = mail;
		mailer.urls[secure_token] = url;
		mailer.job_titles[secure_token] = job_title;
		mailer.send_secured_data_link(secure_token);

		res.send(JSON.stringify({
			token: secure_token,
			url: url,
			files: copied_files,
			mail_sent: mailer.is_configured()
		}));
	});

	app.post('/secure-data/delete', function (req, res) {
		let token = String(req.body.token || '').trim();
		if (!valid_token(token) || !fs.existsSync(token_dir(token))) {
			res.status(404).send(JSON.stringify({error: 'Invalid token'}));
			return;
		}
		if (!exports.is_secured(token)) {
			res.status(400).send(JSON.stringify({error: 'This token does not contain secured uploaded data.'}));
			return;
		}

		fs.rmSync(token_dir(token), {recursive: true, force: true});
		delete accounts.tokens[token];
		delete mailer.mails[token];
		delete mailer.urls[token];
		delete mailer.job_titles[token];

		res.send(JSON.stringify({deleted: true}));
	});
};
