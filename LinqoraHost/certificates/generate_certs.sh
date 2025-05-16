#!/bin/bash
# generate_certs.sh
openssl req -x509 -newkey rsa:4096 -keyout certs/key.pem -out certs/cert.pem -days 1000 -nodes