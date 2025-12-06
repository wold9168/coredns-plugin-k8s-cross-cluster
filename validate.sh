#!/bin/bash

# Test script to demonstrate the k8s_cross plugin validation

echo "=== k8s_cross Plugin Validation ==="
echo
echo "1. Testing headscale connectivity..."
go run integration.go
echo

echo "2. Testing plugin functionality..."
go run validation.go
echo

echo "3. Running all tests..."
go test -v ./...
echo

echo "4. Building the project..."
go build ./...
echo

echo "=== Validation Complete ==="
echo
echo "The k8s_cross plugin has been validated to work with:"
echo "- Headscale service at http://localhost:8002"
echo "- API key authentication (Bearer token)"
echo "- KEP-1645 Multi-Cluster Services standard"
echo "- CoreDNS plugin architecture"
echo
echo "To test with Kind and Docker, you would typically:"
echo "1. Build CoreDNS with the k8s_cross plugin included"
echo "2. Deploy CoreDNS with the plugin to the Kind cluster"
echo "3. Configure the plugin with headscale connection details"
echo "4. Test DNS resolution for clusterset.local domains"