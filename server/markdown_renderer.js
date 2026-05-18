const fs = require('fs');
const path = require('path');

const man_root = '/app/man';

var escape_html = (txt) => {
	return String(txt)
		.replace(/&/g, '&amp;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;')
		.replace(/"/g, '&quot;')
		.replace(/'/g, '&#039;');
};

var escape_attr = (txt) => {
	return escape_html(txt).replace(/`/g, '&#096;');
};

var inline_markdown = (txt) => {
	let html = escape_html(txt);

	html = html.replace(/`([^`]+)`/g, '<code>$1</code>');
	html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
	html = html.replace(/__([^_]+)__/g, '<strong>$1</strong>');
	html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, function(_, label, href) {
		return '<a href="' + escape_attr(href) + '">' + label + '</a>';
	});

	return html;
};

var close_list = (state, html) => {
	if (state.in_list) {
		html.push('</ul>');
		state.in_list = false;
	}
};

var is_table_separator = (line) => {
	return /^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$/.test(line);
};

var table_cells = (line) => {
	return line.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((cell) => {
		return cell.trim();
	});
};

var render_table = (lines, start_idx) => {
	let html = [];
	let header = table_cells(lines[start_idx]);
	let idx = start_idx + 2;

	html.push('<table>');
	html.push('<thead><tr>');
	for (let cell of header)
		html.push('<th>' + inline_markdown(cell) + '</th>');
	html.push('</tr></thead>');
	html.push('<tbody>');

	while (idx < lines.length && lines[idx].includes('|') && lines[idx].trim() != '') {
		html.push('<tr>');
		for (let cell of table_cells(lines[idx]))
			html.push('<td>' + inline_markdown(cell) + '</td>');
		html.push('</tr>');
		idx += 1;
	}

	html.push('</tbody></table>');
	return {html: html.join('\n'), next_idx: idx};
};

var render_markdown = (markdown) => {
	let lines = markdown.replace(/\r\n/g, '\n').split('\n');
	let html = [];
	let state = {in_list: false, in_code: false, code_lines: []};

	for (let idx=0 ; idx<lines.length ; idx++) {
		let line = lines[idx];

		if (line.trim().startsWith('```')) {
			if (state.in_code) {
				html.push('<pre><code>' + escape_html(state.code_lines.join('\n')) + '</code></pre>');
				state.in_code = false;
				state.code_lines = [];
			} else {
				close_list(state, html);
				state.in_code = true;
				state.code_lines = [];
			}
			continue;
		}

		if (state.in_code) {
			state.code_lines.push(line);
			continue;
		}

		if (line.trim() == '') {
			close_list(state, html);
			continue;
		}

		if (idx + 1 < lines.length && line.includes('|') && is_table_separator(lines[idx + 1])) {
			close_list(state, html);
			let table = render_table(lines, idx);
			html.push(table.html);
			idx = table.next_idx - 1;
			continue;
		}

		let heading = line.match(/^(#{1,6})\s+(.*)$/);
		if (heading) {
			close_list(state, html);
			let level = heading[1].length;
			html.push('<h' + level + '>' + inline_markdown(heading[2]) + '</h' + level + '>');
			continue;
		}

		if (/^\s*---+\s*$/.test(line)) {
			close_list(state, html);
			html.push('<hr>');
			continue;
		}

		let blockquote = line.match(/^\s*>\s?(.*)$/);
		if (blockquote) {
			close_list(state, html);
			html.push('<blockquote><p>' + inline_markdown(blockquote[1]) + '</p></blockquote>');
			continue;
		}

		let list_item = line.match(/^\s*[*-]\s+(.*)$/);
		if (list_item) {
			if (!state.in_list) {
				html.push('<ul>');
				state.in_list = true;
			}
			html.push('<li>' + inline_markdown(list_item[1]) + '</li>');
			continue;
		}

		close_list(state, html);
		html.push('<p>' + inline_markdown(line) + '</p>');
	}

	close_list(state, html);
	if (state.in_code)
		html.push('<pre><code>' + escape_html(state.code_lines.join('\n')) + '</code></pre>');

	return html.join('\n');
};

var render_page = (file_path, markdown) => {
	let title = path.basename(file_path).replace(/\.md$/, '').replace(/[-_]/g, ' ');
	let body = render_markdown(markdown);
	let style = `
		*{box-sizing:border-box}
		body{
			margin:0;
			background:#ffffff;
			color:#1f2328;
			font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","Noto Sans",Helvetica,Arial,sans-serif,"Apple Color Emoji","Segoe UI Emoji";
			font-size:16px;
			line-height:1.5;
			word-wrap:break-word;
		}
		.markdown-body{
			max-width:1012px;
			margin:0 auto;
			padding:45px;
		}
		.markdown-body::before,
		.markdown-body::after{
			display:table;
			content:"";
		}
		.markdown-body::after{
			clear:both;
		}
		.markdown-body>*:first-child{
			margin-top:0!important;
		}
		.markdown-body>*:last-child{
			margin-bottom:0!important;
		}
		.markdown-body a{
			color:#0969da;
			text-decoration:none;
		}
		.markdown-body a:hover{
			text-decoration:underline;
		}
		.markdown-body p,
		.markdown-body blockquote,
		.markdown-body ul,
		.markdown-body ol,
		.markdown-body dl,
		.markdown-body table,
		.markdown-body pre{
			margin-top:0;
			margin-bottom:16px;
		}
		.markdown-body h1,
		.markdown-body h2,
		.markdown-body h3,
		.markdown-body h4,
		.markdown-body h5,
		.markdown-body h6{
			margin-top:24px;
			margin-bottom:16px;
			font-weight:600;
			line-height:1.25;
			color:#1f2328;
		}
		.markdown-body h1{
			padding-bottom:.3em;
			font-size:2em;
			border-bottom:1px solid #d8dee4;
		}
		.markdown-body h2{
			padding-bottom:.3em;
			font-size:1.5em;
			border-bottom:1px solid #d8dee4;
		}
		.markdown-body h3{font-size:1.25em}
		.markdown-body h4{font-size:1em}
		.markdown-body h5{font-size:.875em}
		.markdown-body h6{font-size:.85em;color:#656d76}
		.markdown-body ul,
		.markdown-body ol{
			padding-left:2em;
		}
		.markdown-body li+li{
			margin-top:.25em;
		}
		.markdown-body blockquote{
			padding:0 1em;
			color:#656d76;
			border-left:.25em solid #d0d7de;
		}
		.markdown-body blockquote>:first-child{
			margin-top:0;
		}
		.markdown-body blockquote>:last-child{
			margin-bottom:0;
		}
		.markdown-body hr{
			height:.25em;
			padding:0;
			margin:24px 0;
			background-color:#d8dee4;
			border:0;
		}
		.markdown-body code,
		.markdown-body tt{
			padding:.2em .4em;
			margin:0;
			font-size:85%;
			white-space:break-spaces;
			background-color:rgba(175,184,193,.2);
			border-radius:6px;
			font-family:ui-monospace,SFMono-Regular,SFMono-Regular,Consolas,"Liberation Mono",Menlo,monospace;
		}
		.markdown-body pre{
			padding:16px;
			overflow:auto;
			font-size:85%;
			line-height:1.45;
			background-color:#f6f8fa;
			border-radius:6px;
		}
		.markdown-body pre code{
			display:inline;
			max-width:auto;
			padding:0;
			margin:0;
			overflow:visible;
			line-height:inherit;
			word-wrap:normal;
			white-space:pre;
			background-color:transparent;
			border:0;
		}
		.markdown-body table{
			display:block;
			width:max-content;
			max-width:100%;
			overflow:auto;
			border-spacing:0;
			border-collapse:collapse;
		}
		.markdown-body table th{
			font-weight:600;
		}
		.markdown-body table th,
		.markdown-body table td{
			padding:6px 13px;
			border:1px solid #d0d7de;
		}
		.markdown-body table tr{
			background-color:#ffffff;
			border-top:1px solid #d8dee4;
		}
		.markdown-body table tr:nth-child(2n){
			background-color:#f6f8fa;
		}
		@media (max-width:767px){
			.markdown-body{
				padding:15px;
			}
		}
	`;

	return '<!doctype html>\n' +
		'<html><head><meta charset="utf-8">' +
		'<meta name="viewport" content="width=device-width, initial-scale=1">' +
		'<title>' + escape_html(title) + '</title>' +
		'<style>' + style + '</style></head><body><main class="markdown-body">' + body + '</main></body></html>';
};

exports.expose = (app) => {
	app.get(/^\/man\/(.+\.md)$/, function(req, res) {
		let rel_path = path.normalize('/' + req.params[0]).replace(/^\/+/, '');
		let file_path = path.join(man_root, rel_path);

		if (!file_path.startsWith(man_root + path.sep)) {
			res.status(403).send('Invalid documentation path');
			return;
		}

		if (!fs.existsSync(file_path)) {
			res.status(404).send('Documentation page not found');
			return;
		}

		res.type('html').send(render_page(file_path, fs.readFileSync(file_path, 'utf8')));
	});
};
