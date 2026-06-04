const fs = require('fs');
const storage_errors = require('./storage_errors.js');


exports.tokens = {};

exports.token_generation = function (app) {
	app.get('/token_generation', function (req, res) {
		if ((!req.query.token) || (!fs.existsSync('/app/data/' + req.query.token))) {
			var possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

			var token = '';
			for (var i=0 ; i<30 ; i++) {
				token += possible.charAt(Math.floor(Math.random() * possible.length));
			}

			fs.mkdir("/app/data/" + token, function(err){
				if (err) {
					let message = storage_errors.message_for_error(err, 'Unable to create a new SLIM session.');
					let status = storage_errors.is_storage_full_error(err) ? 507 : 500;
					console.log('Token generation failed: ' + message);
					res.status(status).send(message);
					return;
				}

				exports.tokens[token] = token;
				res.send(token);
			});
		} else {
			exports.tokens[req.query.token] = req.query.token;
			res.send(req.query.token);
		}
	});
	
}
