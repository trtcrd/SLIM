# HTTPS with Caddy

The simplest way to run SLIM over HTTPS is to give the server a DNS name and use Caddy as a reverse proxy. SLIM keeps serving plain HTTP inside the server, while Caddy receives public HTTPS traffic and forwards it locally to SLIM.

## Server Requirements

You need:

* a DNS name such as `slim.example.org`;
* a DNS `A` record pointing to the server public IPv4 address;
* optionally, a DNS `AAAA` record pointing to the server public IPv6 address;
* ports `80/tcp` and `443/tcp` open from the internet to the server;
* Caddy installed on the host server.

## Start SLIM Locally Only

Start SLIM with your DNS name. The start script writes a local `deployment/Caddyfile`, which is ignored by git, and binds SLIM to `127.0.0.1` so the raw HTTP service is not exposed directly on the public network:

```bash
bash start_slim_v1.0.0.sh --caddy-domain slim.example.org
```

With this setting, SLIM is reachable only from the server itself at:

```text
http://127.0.0.1:8080/
```

## Configure Caddy

The generated `deployment/Caddyfile` looks like this:

```text
slim.example.org {
    reverse_proxy 127.0.0.1:8080
}
```

The committed `deployment/Caddyfile.example` is only a template. Do not commit the generated `deployment/Caddyfile`, because it contains deployment-specific information.

If Caddy runs as a system service, copy the edited Caddyfile to the Caddy configuration location and reload Caddy:

```bash
sudo cp deployment/Caddyfile /etc/caddy/Caddyfile
sudo caddy fmt --overwrite /etc/caddy/Caddyfile
sudo systemctl reload caddy
sudo systemctl status caddy
```

After DNS resolves and Caddy is running, open:

```text
https://slim.example.org/
```

Caddy handles certificate request and renewal. The SLIM container does not need to know about the TLS certificate.

Do not use:

```text
http://slim.example.org:8080/
```

That address bypasses Caddy and goes directly to the SLIM container over plain HTTP, so browsers will correctly mark it as not secure.

## Troubleshooting

If HTTPS does not work:

* confirm the DNS name points to the server public IP address;
* confirm inbound ports `80` and `443` are open;
* if `http://slim.example.org/` shows nothing, public port `80` is not reaching Caddy;
* confirm no other service is already using ports `80` or `443`;
* confirm Caddy has been reloaded with `sudo systemctl reload caddy`;
* confirm Caddy is running with `sudo systemctl status caddy`;
* check Caddy logs for certificate or proxy errors;
* confirm SLIM is running locally with `curl http://127.0.0.1:8080/` on the server.
