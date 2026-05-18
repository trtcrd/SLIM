const fs = require('fs');

const crash_file = '/app/runtime/server_crash.json';

exports.crash_file = crash_file;

exports.read_last_crash = () => {
	if (!fs.existsSync(crash_file))
		return null;

	try {
		return JSON.parse(fs.readFileSync(crash_file, 'utf8'));
	} catch (err) {
		return {
			timestamp: null,
			exit_code: null,
			snippet: 'Unable to read server crash log: ' + err.message
		};
	}
};

exports.expose = (app) => {
	app.get('/server_status', function (req, res) {
		res.send(JSON.stringify({
			alive: true,
			last_crash: exports.read_last_crash()
		}));
	});
};
