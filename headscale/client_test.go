// Package headscale provides tests for the Headscale API client.
package headscale

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestClient_ListNodes(t *testing.T) {
	// Create a test server to mock the Headscale API
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/node" {
			t.Errorf("Expected to request '/api/v1/node', got: %s", r.URL.Path)
		}
		
		authHeader := r.Header.Get("Authorization")
		if authHeader != "Bearer test-api-key" {
			t.Errorf("Expected Authorization header 'Bearer test-api-key', got: %s", authHeader)
		}

		// Return mock response
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{
			"nodes": [
				{
					"id": "1",
					"machineKey": "key1",
					"nodeKey": "node1",
					"discoKey": "",
					"ipAddresses": ["10.0.0.1", "2001:db8::1"],
					"name": "node1",
					"user": {
						"id": "1",
						"name": "user1"
					},
					"lastSeen": "2023-01-01T00:00:00Z",
					"expiry": "2024-01-01T00:00:00Z",
					"createdAt": "2022-01-01T00:00:00Z",
					"registerMethod": "REGISTER_METHOD_CLI",
					"online": true,
					"approvedRoutes": [],
					"availableRoutes": []
				}
			]
		}`))
	}))
	defer ts.Close()

	client := &Client{
		BaseURL: ts.URL,
		APIKey:  "test-api-key",
		HTTPClient: &http.Client{
			Timeout: 5 * time.Second,
		},
	}

	nodes, err := client.ListNodes(context.Background(), "")
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if len(nodes) != 1 {
		t.Errorf("Expected 1 node, got %d", len(nodes))
	}

	if nodes[0].ID != "1" {
		t.Errorf("Expected node ID '1', got '%s'", nodes[0].ID)
	}

	if nodes[0].Name != "node1" {
		t.Errorf("Expected node name 'node1', got '%s'", nodes[0].Name)
	}

	if len(nodes[0].IPAddresses) != 2 {
		t.Errorf("Expected 2 IP addresses, got %d", len(nodes[0].IPAddresses))
	}

	if nodes[0].IPAddresses[0] != "10.0.0.1" {
		t.Errorf("Expected IP '10.0.0.1', got '%s'", nodes[0].IPAddresses[0])
	}
}

func TestClient_GetNode(t *testing.T) {
	// Create a test server to mock the Headscale API
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		expectedPath := "/api/v1/node/123"
		if r.URL.Path != expectedPath {
			t.Errorf("Expected to request '%s', got: %s", expectedPath, r.URL.Path)
		}
		
		authHeader := r.Header.Get("Authorization")
		if authHeader != "Bearer test-api-key" {
			t.Errorf("Expected Authorization header 'Bearer test-api-key', got: %s", authHeader)
		}

		// Return mock response
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{
			"node": {
				"id": "123",
				"machineKey": "key123",
				"nodeKey": "node123",
				"discoKey": "",
				"ipAddresses": ["10.0.0.123"],
				"name": "node123",
				"user": {
					"id": "1",
					"name": "user1"
				},
				"lastSeen": "2023-01-01T00:00:00Z",
				"expiry": "2024-01-01T00:00:00Z",
				"createdAt": "2022-01-01T00:00:00Z",
				"registerMethod": "REGISTER_METHOD_CLI",
				"online": true,
				"approvedRoutes": [],
				"availableRoutes": []
			}
		}`))
	}))
	defer ts.Close()

	client := &Client{
		BaseURL: ts.URL,
		APIKey:  "test-api-key",
		HTTPClient: &http.Client{
			Timeout: 5 * time.Second,
		},
	}

	node, err := client.GetNode(context.Background(), "123")
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if node.ID != "123" {
		t.Errorf("Expected node ID '123', got '%s'", node.ID)
	}

	if node.Name != "node123" {
		t.Errorf("Expected node name 'node123', got '%s'", node.Name)
	}

	if len(node.IPAddresses) != 1 {
		t.Errorf("Expected 1 IP address, got %d", len(node.IPAddresses))
	}

	if node.IPAddresses[0] != "10.0.0.123" {
		t.Errorf("Expected IP '10.0.0.123', got '%s'", node.IPAddresses[0])
	}
}

func TestClient_Health(t *testing.T) {
	// Create a test server to mock the Headscale API
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/health" {
			t.Errorf("Expected to request '/api/v1/health', got: %s", r.URL.Path)
		}
		
		authHeader := r.Header.Get("Authorization")
		if authHeader != "Bearer test-api-key" {
			t.Errorf("Expected Authorization header 'Bearer test-api-key', got: %s", authHeader)
		}

		// Return mock response
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{
			"databaseConnectivity": true
		}`))
	}))
	defer ts.Close()

	client := &Client{
		BaseURL: ts.URL,
		APIKey:  "test-api-key",
		HTTPClient: &http.Client{
			Timeout: 5 * time.Second,
		},
	}

	health, err := client.Health(context.Background())
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if !health.DatabaseConnectivity {
		t.Error("Expected database connectivity to be true")
	}
}

func TestClient_CreateUser(t *testing.T) {
	// Create a test server to mock the Headscale API
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/user" {
			t.Errorf("Expected to request '/api/v1/user', got: %s", r.URL.Path)
		}
		
		authHeader := r.Header.Get("Authorization")
		if authHeader != "Bearer test-api-key" {
			t.Errorf("Expected Authorization header 'Bearer test-api-key', got: %s", authHeader)
		}

		contentType := r.Header.Get("Content-Type")
		if contentType != "application/json" {
			t.Errorf("Expected Content-Type 'application/json', got: %s", contentType)
		}

		// Return mock response
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{
			"user": {
				"id": "5",
				"name": "testuser",
				"createdAt": "2023-01-01T00:00:00Z",
				"displayName": "Test User",
				"email": "test@example.com"
			}
		}`))
	}))
	defer ts.Close()

	client := &Client{
		BaseURL: ts.URL,
		APIKey:  "test-api-key",
		HTTPClient: &http.Client{
			Timeout: 5 * time.Second,
		},
	}

	req := &CreateUserRequest{
		Name:        "testuser",
		DisplayName: "Test User",
		Email:       "test@example.com",
	}

	user, err := client.CreateUser(context.Background(), req)
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if user.Name != "testuser" {
		t.Errorf("Expected username 'testuser', got '%s'", user.Name)
	}

	if user.Email != "test@example.com" {
		t.Errorf("Expected email 'test@example.com', got '%s'", user.Email)
	}
}

func TestClient_ErrorHandling(t *testing.T) {
	// Create a test server to return an error
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(`{"error": "internal server error"}`))
	}))
	defer ts.Close()

	client := &Client{
		BaseURL: ts.URL,
		APIKey:  "test-api-key",
		HTTPClient: &http.Client{
			Timeout: 5 * time.Second,
		},
	}

	// Test ListNodes error handling
	_, err := client.ListNodes(context.Background(), "")
	if err == nil {
		t.Error("Expected error, got nil")
	}

	// Test GetNode error handling
	_, err = client.GetNode(context.Background(), "123")
	if err == nil {
		t.Error("Expected error, got nil")
	}

	// Test Health error handling
	_, err = client.Health(context.Background())
	if err == nil {
		t.Error("Expected error, got nil")
	}

	// Test CreateUser error handling
	_, err = client.CreateUser(context.Background(), &CreateUserRequest{})
	if err == nil {
		t.Error("Expected error, got nil")
	}
}