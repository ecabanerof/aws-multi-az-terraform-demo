#!/bin/bash
# Demo SSL Certificate Setup 
set -e

echo "=== Demo Certificate Setup ==="

CERT_DIR="/tmp/demo-certificates"
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo "Certificate directory: $CERT_DIR"

# Generate CA private key
echo "1. Generating CA private key..."
openssl genrsa -out demo-ca-key.pem 4096

# Generate CA certificate
echo "2. Generating CA certificate..."
openssl req -new -x509 -days 365 -key demo-ca-key.pem -sha256 -out demo-ca.pem -subj "/C=ES/ST=Madrid/L=Madrid/O=TechCorp-Demo/OU=IT Department/CN=Demo Certificate Authority"

# Generate server private key
echo "3. Generating server private key..."
openssl genrsa -out demo-server-key.pem 4096

# Generate server certificate signing request
echo "4. Generating server certificate request..."
openssl req -subj "/C=ES/ST=Madrid/L=Madrid/O=TechCorp-Demo/OU=IT Department/CN=demo.techcorp-example.com" -sha256 -new -key demo-server-key.pem -out demo-server.csr

# Create extensions file for server certificate
cat > demo-server-extfile.cnf << EOF
subjectAltName = DNS:demo.techcorp-example.com,DNS:*.demo.techcorp-example.com,IP:172.20.10.21,IP:172.20.10.22,IP:172.20.20.21,IP:172.20.20.22
extendedKeyUsage = serverAuth
EOF

# Generate server certificate
echo "5. Generating server certificate..."
openssl x509 -req -days 365 -sha256 -in demo-server.csr -CA demo-ca.pem -CAkey demo-ca-key.pem -out demo-server-cert.pem -CAcreateserial -extfile demo-server-extfile.cnf

# Generate client private key
echo "6. Generating client private key..."
openssl genrsa -out demo-client-key.pem 4096

# Generate client certificate signing request
echo "7. Generating client certificate request..."
openssl req -subj "/C=ES/ST=Madrid/L=Madrid/O=TechCorp-Demo/OU=IT Department/CN=demo-client" -new -key demo-client-key.pem -out demo-client.csr

# Create extensions file for client certificate
cat > demo-client-extfile.cnf << EOF
extendedKeyUsage = clientAuth
EOF

# Generate client certificate
echo "8. Generating client certificate..."
openssl x509 -req -days 365 -sha256 -in demo-client.csr -CA demo-ca.pem -CAkey demo-ca-key.pem -out demo-client-cert.pem -CAcreateserial -extfile demo-client-extfile.cnf

# Set proper permissions
echo "9. Setting certificate permissions..."
chmod 400 demo-*-key.pem
chmod 444 demo-*.pem

# Clean up CSR and extension files
rm -f demo-server.csr demo-client.csr demo-*-extfile.cnf

echo "=== Certificate Files Generated ==="
ls -la demo-*
echo ""

echo "=== Certificate Information ==="
echo "CA Certificate:"
openssl x509 -in demo-ca.pem -text -noout | grep -E "(Subject|Validity)"

echo ""
echo "Server Certificate:"
openssl x509 -in demo-server-cert.pem -text -noout | grep -E "(Subject|Subject Alternative Name|Validity)" -A 1

echo ""
echo "Client Certificate:"
openssl x509 -in demo-client-cert.pem -text -noout | grep -E "(Subject|Validity)"

echo ""
echo "=== Usage Instructions ==="
echo "Copy certificates to your servers:"
echo "  scp demo-ca.pem demo-server-cert.pem demo-server-key.pem ubuntu@SERVER_IP:/etc/ssl/certs/"
echo ""
echo "For web servers (nginx configuration):"
echo "  ssl_certificate     /etc/ssl/certs/demo-server-cert.pem;"
echo "  ssl_certificate_key /etc/ssl/certs/demo-server-key.pem;"
echo ""
echo "For client authentication:"
echo "  ssl_client_certificate /etc/ssl/certs/demo-ca.pem;"
echo "  ssl_verify_client on;"

echo "=== Demo Certificate Setup Complete ==="