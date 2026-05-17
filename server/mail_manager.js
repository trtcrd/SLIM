const nodemailer = require('nodemailer');
const fs = require('fs');

const config = require ('./config.js');


let transporter = null

if (!config.mailer.__enabled) {
	console.warn('\nWarning: Mailer not configured. Set SLIM_MAIL_USER and SLIM_MAIL_PASSWORD to enable email notifications.\n');
} else {
	let mailer_options = Object.assign({}, config.mailer);
	delete mailer_options.__address;
	delete mailer_options.__enabled;
	transporter = nodemailer.createTransport(mailer_options);
}

exports.is_configured = () => {
	return transporter != null;
};



let send_mail = (token, subject, text, files=[]) => {
	if (transporter == null) {
		console.warn(token + ": email not sent: mailer not configured");
		return;
	}

	if (!exports.mails[token]) {
		console.log(token + ": email not sent: no recipient registered");
		return;
	}

	let mail = exports.mails[token];
	if (!mail.includes('@')) {
		console.warn(token + ": email not sent: invalid address: " + mail);
		return;
	}

	if (mail == 'aaa') {
		console.warn(token + ": email not sent: fake debug address");
		return;
	}

	let mailOptions = {
		from: 'SLIM <' + config.mailer.__address + '>', // sender address
		to: mail, // list of receivers
		subject: '[No reply] ' + subject, // Subject line
		text: text
	};

	if (files.length > 0) {
		let attachments = [];
		for (let idx=0 ; idx<files.length ; idx++) {
			let name = files[idx];
			if (!fs.existsSync(name))
				continue;

			let short_name = name.split('/');
			short_name = short_name[short_name.length - 1]

			attachments.push({
				filename: short_name,
				path: name
			});
		}

		if (attachments.length > 0)
			mailOptions.attachments = attachments;
	}

	// send mail with defined transport object
	transporter.sendMail(mailOptions, (error, info) => {
		if (error) {
			console.log(token + ': email failed: ' + error.message);
			return;
		}

		console.log(token + ': email sent to ' + mail + (info && info.messageId ? ' (' + info.messageId + ')' : ''));
	});
};


exports.mails = {};
exports.urls = {};


exports.send_address = (token) => {
	send_mail(
		token,
		'Your job ' + token,
		'Here is the link to follow the execution process.\n' +
		exports.urls[token] + '\n\n' +
		'The SLIM pipeline staff',
		['/app/data/' + token + '/pipeline.conf', '/app/versions.tsv']
	);
};


exports.send_end_mail = (token) => {
	send_mail(
		token,
		'Your job ' + token + ' is over',
		'Your results are available at this address:\n' +
		exports.urls[token] + '\n\n' +
		'Your session will automatically be deleted in 24h. Don\'t forget to download your results\n\n' +
		'You can use the .conf attached file to reload all your pipeline in the future.\n' +
		'For used software versions, please look at the attached version.tsv file.\n\n' +
		'The SLIM pipeline staff',
		['/app/data/' + token + '/pipeline.conf', '/app/versions.tsv']
	);
}

exports.send_crash_email = (token) => {
	send_mail(
		token,
		'Your job ' + token + ' crashed :(',
		'Your partial results are available at this address:\n' +
		exports.urls[token] + '\n' +
		'Please check all your configuration before another submission.\n\n' +
		'Your session will automatically be deleted in 24h.\n\n' +
		'The SLIM pipeline staff'	
	);
}

exports.send_delete_reminder = (token) => {
	send_mail(
		token,
		'Your job ' + token + ' will be deleted in 3 hours',
		'Your results are still available at this address for only 3 more hours:\n' +
		exports.urls[token] + '\n\n' +
		'The SLIM pipeline staff'
	);
}
