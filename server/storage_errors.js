const fs = require('fs');

const storage_full_message = 'Storage is full, cannot upload more data.';

exports.storage_full_message = storage_full_message;

exports.is_storage_full_error = (err) => {
	if (!err)
		return false;

	let message = err.message ? err.message : String(err);
	message = message.toLowerCase();

	return err.code == 'ENOSPC' ||
		message.includes('enospc') ||
		message.includes('no space left') ||
		message.includes('not enough space');
};

exports.message_for_error = (err, fallback) => {
	if (exports.is_storage_full_error(err))
		return storage_full_message;

	return err && err.message ? err.message : fallback;
};

exports.is_storage_full = (path='/app/data') => {
	if (!fs.statfsSync)
		return false;

	try {
		let stats = fs.statfsSync(path);
		return stats && stats.bavail === 0;
	} catch (err) {
		return exports.is_storage_full_error(err);
	}
};
