const fs = require('fs');
const si = require('systeminformation');

const crash_file = '/app/runtime/server_crash.json';
let job_status_provider = () => null;

exports.crash_file = crash_file;

exports.set_job_status_provider = (provider) => {
	job_status_provider = provider;
};

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
		let token = req.query.token ? String(req.query.token) : null;

		Promise.all([
			si.currentLoad(),
			si.mem()
		]).then(([cpu, mem]) => {
			res.send(JSON.stringify({
				alive: true,
				last_crash: exports.read_last_crash(),
				jobs: job_status_provider(token),
				load: {
					cpu_percent: Math.round(cpu.currentLoad * 10) / 10,
					cpu_cores: cpu.cpus ? cpu.cpus.length : null,
					ram_percent: Math.round((mem.active / mem.total) * 1000) / 10,
					ram_used: mem.active,
					ram_total: mem.total
				}
			}));
		}).catch((err) => {
			res.send(JSON.stringify({
				alive: true,
				last_crash: exports.read_last_crash(),
				jobs: job_status_provider(token),
				load_error: err.message
			}));
		});
	});
};
