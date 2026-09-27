#!/usr/bin/env python3
"""Read-only DNS transport probes; TLS certificate verification stays enabled."""
import base64
import argparse
import socket
import ssl
import struct
import subprocess

QUERY = struct.pack('!6H', 0xAA10, 0x0100, 1, 0, 0, 0) + b'\x07example\x03com\x00' + struct.pack('!2H', 1, 1)


def validate(data, label):
    transaction, flags, _, answers, _, _ = struct.unpack('!6H', data[:12])
    assert transaction == 0xAA10 and flags & 0x8000 and flags & 15 == 0 and answers > 0, label
    print('PASS ' + label)


def receive(stream, size):
    result = b''
    while len(result) < size:
        chunk = stream.recv(size - len(result))
        if not chunk:
            raise RuntimeError('DNS connection closed before response completed')
        result += chunk
    return result


def tcp(stream, label):
    stream.sendall(struct.pack('!H', len(QUERY)) + QUERY)
    length = struct.unpack('!H', receive(stream, 2))[0]
    validate(receive(stream, length), label)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dns-port', type=int, default=53)
    parser.add_argument('--tls-port', type=int, default=853)
    parser.add_argument('--doh-port', type=int, default=443)
    parser.add_argument('--doh-host', default='audit.dns.yusoofsh.id')
    args = parser.parse_args()
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as stream:
        stream.settimeout(8)
        stream.sendto(QUERY, ('127.0.0.1', args.dns_port))
        validate(stream.recv(4096), 'UDP DNS answer')
    with socket.create_connection(('127.0.0.1', args.dns_port), timeout=8) as stream:
        tcp(stream, 'TCP DNS answer')
    with socket.create_connection(('127.0.0.1', args.tls_port), timeout=8) as plain:
        with ssl.create_default_context().wrap_socket(plain, server_hostname='dns.yusoofsh.id') as stream:
            tcp(stream, 'DNS-over-TLS answer and verified certificate')
    encoded = base64.urlsafe_b64encode(QUERY).decode().rstrip('=')
    reply = subprocess.check_output(['curl', '-fsS', '--max-time', '12', '--resolve',
        f'{args.doh_host}:{args.doh_port}:127.0.0.1', '-H', 'Accept: application/dns-message',
        f'https://{args.doh_host}:{args.doh_port}/dns-query?dns=' + encoded])
    validate(reply, 'DNS-over-HTTPS answer and verified certificate')


if __name__ == '__main__':
    main()
