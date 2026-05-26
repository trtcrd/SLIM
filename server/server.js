'use strict';

var secured_server = false;

const express = require('express');
const pug = require('pug');
const bodyParser = require('body-parser')
const fs = require('fs');


// Pug webpages pre-compilation
const pipeline_GUI = pug.compileFile('/app/www/pipeline.pug');

// Constants
const PORT = 80;

// App
const app = express();
app.use( bodyParser.json({limit: '10mb'}) );       // to support JSON-encoded bodies
app.use(bodyParser.urlencoded({     // to support URL-encoded bodies
  limit: '10mb',
  extended: true
}));

const system_status = require('./system_status.js');
system_status.expose(app);
const markdown_renderer = require('./markdown_renderer.js');
markdown_renderer.expose(app);

app.get('/', function (req, res) {
	res.send(pipeline_GUI());
});
app.use('/js', express.static('www/js'));
app.use('/css', express.static('www/css'));
app.use('/imgs', express.static('www/imgs'));
app.use('/modules', express.static('www/modules'));
app.use('/pipelines', express.static('www/pipelines'));
app.use('/man', express.static('/app/man'));

app.use('/data', express.static('/app/data'));

// app.use('/softwares', express.static("www/pipeline_modules.json"));
const sub_process = require('./sub_process.js');
sub_process.expose_modules(app);
sub_process.expose_logs(app);

var server = null;
if (secured_server) {
  server = require('https');
  var certOptions = {
    key: fs.readFileSync('/app/ssl/server.key'),
    cert: fs.readFileSync('/app/ssl/server.crt')
  }

  server = server.createServer(certOptions, app);
} else {
  server = require('http');
  server = server.createServer(app);
}

// Large sequence uploads can legitimately take longer than Node's default
// request timeout. Let Formidable enforce the explicit upload-size limits
// instead of having the HTTP server abort long transfers.
server.requestTimeout = 0;
server.headersTimeout = 0;
server.timeout = 0;

server.listen(PORT);

console.log('Running on http(s)://localhost:' + PORT);


// Accounts
const accounts = require('./accounts.js');
accounts.token_generation(app);

// Data exchanche
const filesIO = require("./files_upload.js");
filesIO.exposeDir(app);
filesIO.upload(app);
const dataSecurity = require("./data_security.js");
dataSecurity.expose(app);

// Start job scheduler
const scheduler = require('./scheduler.js');
system_status.set_job_status_provider(scheduler.get_job_capacity);
scheduler.start();
scheduler.listen_commands(app);
scheduler.expose_status(app);
