const get_env = (name, fallback) => {
    return process.env[name] || fallback;
};

const mail_user = get_env('SLIM_MAIL_USER', get_env('GMAIL_USER', 'username'));
const mail_pass = get_env('SLIM_MAIL_PASSWORD', get_env('GMAIL_APP_PASSWORD', get_env('GMAIL_PASS', 'password'))).replace(/\s/g, '');
const mail_from = get_env('SLIM_MAIL_FROM', mail_user);

exports.mailer = {
    __enabled: mail_user != 'username' && mail_pass != 'password',
    __address: mail_from,
    host: get_env('SLIM_MAIL_HOST', 'smtp.gmail.com'),
    port: parseInt(get_env('SLIM_MAIL_PORT', '465'), 10),
    secure: get_env('SLIM_MAIL_SECURE', 'true') != 'false',
    auth: {
        user: mail_user,
        pass: mail_pass
    }
}
