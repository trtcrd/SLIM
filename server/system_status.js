const fs = require('fs');
const si = require('systeminformation');

const crash_file = '/app/runtime/server_crash.json';
const storage_path = '/app/data';
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

const get_storage_info = (filesystems) => {
	if (!Array.isArray(filesystems) || filesystems.length == 0)
		return null;

	let candidates = filesystems
		.filter((filesystem) => filesystem && filesystem.mount && (
			filesystem.mount == '/' ||
			storage_path == filesystem.mount ||
			storage_path.startsWith(filesystem.mount + '/')
		))
		.sort((left, right) => right.mount.length - left.mount.length);

	let filesystem = candidates[0] || filesystems[0];
	let total = filesystem.size || 0;
	let used = filesystem.used || 0;
	let available = filesystem.available || Math.max(total - used, 0);

	return {
		storage_path,
		storage_mount: filesystem.mount,
		storage_percent: total > 0 ? Math.round((used / total) * 1000) / 10 : null,
		storage_used: used,
		storage_available: available,
		storage_total: total
	};
};

exports.expose = (app) => {
	app.get('/server_status', function (req, res) {
		let token = req.query.token ? String(req.query.token) : null;

		Promise.all([
			si.currentLoad(),
			si.mem(),
			si.fsSize().catch(() => [])
		]).then(([cpu, mem, filesystems]) => {
			res.send(JSON.stringify({
				alive: true,
				last_crash: exports.read_last_crash(),
				jobs: job_status_provider(token),
				load: {
					cpu_percent: Math.round(cpu.currentLoad * 10) / 10,
					cpu_cores: cpu.cpus ? cpu.cpus.length : null,
					ram_percent: Math.round((mem.active / mem.total) * 1000) / 10,
					ram_used: mem.active,
					ram_total: mem.total,
					storage: get_storage_info(filesystems)
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
