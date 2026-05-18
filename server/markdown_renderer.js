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

	return '<!doctype html>\n' +
		'<html><head><meta charset="utf-8">' +
		'<meta name="viewport" content="width=device-width, initial-scale=1">' +
		'<title>' + escape_html(title) + '</title>' +
		'<style>' +
		'body{margin:0;background:#f5f5f5;color:#1f2933;font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;line-height:1.55;}' +
		'.doc{max-width:920px;margin:24px auto 48px;background:white;padding:32px 42px;box-shadow:3px 3px 15px #aaa;border-radius:3px;}' +
		'h1,h2,h3,h4,h5,h6{text-align:left;line-height:1.2;margin:1.2em 0 .5em;color:#111827;}' +
		'h1{margin-top:0;border-bottom:1px solid #ddd;padding-bottom:.35em;}' +
		'p,li,td,th{text-align:left;font-size:16px;}' +
		'p{margin:.6em 0;}' +
		'ul{margin:.5em 0 1em 1.4em;padding:0;}' +
		'code{background:#eef2f7;padding:1px 4px;border-radius:3px;font-family:Menlo,Consolas,monospace;font-size:.92em;}' +
		'pre{background:#111827;color:white;overflow:auto;padding:12px;border-radius:4px;}' +
		'pre code{background:transparent;color:inherit;padding:0;}' +
		'table{width:100%;border-collapse:collapse;margin:1em 0;}' +
		'th,td{border:1px solid #d0d7de;padding:7px 9px;vertical-align:top;}' +
		'th{background:#f3f4f6;font-weight:700;}' +
		'a{color:#0969da;text-decoration:none;}a:hover{text-decoration:underline;}' +
		'</style></head><body><main class="doc">' + body + '</main></body></html>';
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
