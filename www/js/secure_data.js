var secure_data_status_html = (html) => {
	let status = document.getElementById('secure_data_status');
	if (status)
		status.innerHTML = html;
};

var secure_data_message = (message, is_error=false) => {
	secure_data_status_html('<p>' + html_escape(message) + '</p>');

	if (is_error) {
		let warnings = document.getElementsByClassName('gui_warnings');
		for (let idx=0 ; idx<warnings.length ; idx++)
			warnings[idx].innerHTML = '<p>' + html_escape(message) + '</p>';
	}
};

var get_secure_uploaded_files = () => {
	let files = file_manager.getUploadedFiles();

	return files.filter((filename) => {
		return !filename.includes('*') && !filename.includes('€');
	});
};

var refresh_secure_data_status = () => {
	if (!exec_token)
		return;

	$.get('/secure-data/status?token=' + exec_token)
	.done((data) => {
		let status = typeof data == 'string' ? JSON.parse(data) : data;
		let del = document.getElementById('delete_secure_data');
		let secure = document.getElementById('secure_data');

		if (status.secured) {
			if (del)
				del.style.display = 'inline-block';
			if (secure)
				secure.disabled = true;

			secure_data_status_html('<p>This uploaded-data page is secured and excluded from automatic housekeeping.</p>');
		} else {
			if (del)
				del.style.display = 'none';
			if (secure)
				secure.disabled = false;
			secure_data_status_html('');
		}
	})
	.fail(() => {
		let del = document.getElementById('delete_secure_data');
		if (del)
			del.style.display = 'none';
	});
};

var setup_secure_data_controls = () => {
	let secure = document.getElementById('secure_data');
	let del = document.getElementById('delete_secure_data');

	if (!secure || !del)
		return;

	secure.onclick = () => {
		let job_title = get_job_title_value();
		let mail = get_mail_value();

		if (job_title == '') {
			secure_data_message('Please enter a job title before securing uploaded data.', true);
			document.getElementById('job_title').focus();
			return;
		}
		if (mail == '' || mail.length <= 5 || !mail.includes('@')) {
			secure_data_message('Please enter a valid email address before securing uploaded data.', true);
			document.getElementById('mail').focus();
			return;
		}

		let files = get_secure_uploaded_files();
		secure.disabled = true;
		secure_data_message('Securing uploaded data…');

		$.ajax({
			url: '/secure-data',
			type: 'POST',
			contentType: 'application/json',
			data: JSON.stringify({
				token: exec_token,
				job_title: job_title,
				mail: mail,
				files: files
			}),
			success: (data) => {
				let response = typeof data == 'string' ? JSON.parse(data) : data;
				let secure_url = html_escape(response.url);
				let msg = 'Secured copy ready: <a href="' + secure_url + '" target="_blank" rel="noopener noreferrer">' + secure_url + '</a>';
				if (!response.mail_sent)
					msg += '<br>No email was sent because the SLIM mailer is not configured.';
				secure_data_status_html('<p>' + msg + '</p>');
				secure.disabled = false;
			},
			error: (jqXHR) => {
				let message = 'Unable to secure uploaded data.';
				try {
					let response = JSON.parse(jqXHR.responseText);
					if (response.error)
						message = response.error;
				} catch (err) {
					if (jqXHR.responseText)
						message = jqXHR.responseText;
				}
				secure_data_message(message, true);
				secure.disabled = false;
			}
		});
	};

	del.onclick = () => {
		if (!confirm('Delete this secured uploaded-data page permanently?'))
			return;

		del.disabled = true;
		$.ajax({
			url: '/secure-data/delete',
			type: 'POST',
			contentType: 'application/json',
			data: JSON.stringify({token: exec_token}),
			success: () => {
				secure_data_message('Secured uploaded data deleted.');
				setTimeout(() => {
					window.location = window.location.href.split('?')[0];
				}, 1000);
			},
			error: (jqXHR) => {
				let message = jqXHR.responseText || 'Unable to delete secured uploaded data.';
				try {
					let response = JSON.parse(jqXHR.responseText);
					if (response.error)
						message = response.error;
				} catch (err) {}
				secure_data_message(message, true);
				del.disabled = false;
			}
		});
	};
};

setup_secure_data_controls();
