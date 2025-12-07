package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
)

// MockHeadscaleServer 模拟Headscale服务器
type MockHeadscaleServer struct {
	server *http.Server
}

// Node 模拟Headscale节点数据
type Node struct {
	ID            string    `json:"id"`
	MachineKey    string    `json:"machineKey"`
	NodeKey       string    `json:"nodeKey"`
	DiscoKey      string    `json:"discoKey"`
	IPAddresses   []string  `json:"ipAddresses"`
	Name          string    `json:"name"`
	LastSeen      time.Time `json:"lastSeen"`
	Expiry        time.Time `json:"expiry"`
	CreatedAt     time.Time `json:"createdAt"`
	RegisterMethod string   `json:"registerMethod"`
	Online        bool      `json:"online"`
}

// User 模拟Headscale用户数据
type User struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	CreatedAt   time.Time `json:"createdAt"`
	DisplayName string    `json:"displayName"`
	Email       string    `json:"email"`
}

// HealthResponse 健康检查响应
type HealthResponse struct {
	DatabaseConnectivity bool `json:"databaseConnectivity"`
}

// ListNodesResponse 列出节点响应
type ListNodesResponse struct {
	Nodes []Node `json:"nodes"`
}

// GetNodeResponse 获取节点响应
type GetNodeResponse struct {
	Node Node `json:"node"`
}

// CreateUserResponse 创建用户响应
type CreateUserResponse struct {
	User User `json:"user"`
}

// NewMockHeadscaleServer 创建新的模拟Headscale服务器
func NewMockHeadscaleServer(port string) *MockHeadscaleServer {
	addr := ":" + port
	server := &http.Server{Addr: addr}
	
	mux := http.NewServeMux()
	server.Handler = mux
	
	// 创建一些模拟节点
	now := time.Now()
	nodes := []Node{
		{
			ID:            "node1",
			MachineKey:    "machine-key-1",
			NodeKey:       "node-key-1",
			DiscoKey:      "disco-key-1",
			IPAddresses:   []string{"10.0.0.1", "fd11::1"},
			Name:          "web-service.default",
			LastSeen:      now,
			Expiry:        now.Add(24 * time.Hour),
			CreatedAt:     now.Add(-24 * time.Hour),
			RegisterMethod: "authkey",
			Online:        true,
		},
		{
			ID:            "node2",
			MachineKey:    "machine-key-2",
			NodeKey:       "node-key-2",
			DiscoKey:      "disco-key-2",
			IPAddresses:   []string{"10.0.0.2", "fd11::2"},
			Name:          "api-service.production",
			LastSeen:      now,
			Expiry:        now.Add(24 * time.Hour),
			CreatedAt:     now.Add(-24 * time.Hour),
			RegisterMethod: "authkey",
			Online:        true,
		},
		{
			ID:            "node3",
			MachineKey:    "machine-key-3",
			NodeKey:       "node-key-3",
			DiscoKey:      "disco-key-3",
			IPAddresses:   []string{"10.0.0.3", "fd11::3"},
			Name:          "database-service.default",
			LastSeen:      now,
			Expiry:        now.Add(24 * time.Hour),
			CreatedAt:     now.Add(-24 * time.Hour),
			RegisterMethod: "authkey",
			Online:        false, // 这个节点是离线的
		},
	}
	
	// 添加API端点
	mux.HandleFunc("/api/v1/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		healthResp := HealthResponse{DatabaseConnectivity: true}
		json.NewEncoder(w).Encode(healthResp)
	})
	
	mux.HandleFunc("/api/v1/node", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		listResp := ListNodesResponse{Nodes: nodes}
		json.NewEncoder(w).Encode(listResp)
	})
	
	mux.HandleFunc("/api/v1/node/", func(w http.ResponseWriter, r *http.Request) {
		// 提取节点ID
		nodeID := r.URL.Path[len("/api/v1/node/"):]
		var foundNode *Node
		
		for i := range nodes {
			if nodes[i].ID == nodeID {
				foundNode = &nodes[i]
				break
			}
		}
		
		if foundNode == nil {
			http.Error(w, "Node not found", http.StatusNotFound)
			return
		}
		
		w.Header().Set("Content-Type", "application/json")
		getResp := GetNodeResponse{Node: *foundNode}
		json.NewEncoder(w).Encode(getResp)
	})
	
	mux.HandleFunc("/api/v1/user", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "POST" {
			// 解析请求体
			var createUserReq struct {
				Name        string `json:"name"`
				DisplayName string `json:"displayName"`
				Email       string `json:"email"`
			}
			
			if err := json.NewDecoder(r.Body).Decode(&createUserReq); err != nil {
				http.Error(w, "Invalid request", http.StatusBadRequest)
				return
			}
			
			// 创建新用户
			newUser := User{
				ID:          "user-" + fmt.Sprintf("%d", time.Now().Unix()),
				Name:        createUserReq.Name,
				CreatedAt:   time.Now(),
				DisplayName: createUserReq.DisplayName,
				Email:       createUserReq.Email,
			}
			
			w.Header().Set("Content-Type", "application/json")
			createUserResp := CreateUserResponse{User: newUser}
			json.NewEncoder(w).Encode(createUserResp)
		} else {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})
	
	return &MockHeadscaleServer{server: server}
}

// Start 启动模拟服务器
func (m *MockHeadscaleServer) Start() error {
	log.Printf("Starting mock Headscale server on %s", m.server.Addr)
	return m.server.ListenAndServe()
}

// Stop 停止模拟服务器
func (m *MockHeadscaleServer) Stop(ctx context.Context) error {
	log.Printf("Stopping mock Headscale server")
	return m.server.Shutdown(ctx)
}

func main() {
	// 创建并启动模拟Headscale服务器
	mockServer := NewMockHeadscaleServer("8002")
	
	// 启动服务器
	go func() {
		if err := mockServer.Start(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start mock server: %v", err)
		}
	}()
	
	// 等待服务器启动
	time.Sleep(2 * time.Second)
	log.Println("Mock Headscale server is running")
	
	// 等待中断信号
	select {}
}