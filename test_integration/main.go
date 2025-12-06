package main

import (
	"context"
	"fmt"
	"log"
	"time"
)

// This is an integration test to verify the headscale client works with the real service
func main() {
	// Connect to the running headscale service
	client := headscale.NewClient("http://localhost:8002", "Sb49LRo.djRq_TeNwbjfDFubrYBZhzjxdVo65S_X")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Test connection by getting health status
	health, err := client.Health(ctx)
	if err != nil {
		log.Fatalf("Failed to get health status: %v", err)
	}

	fmt.Printf("Headscale server health: Database connectivity = %t\n", health.DatabaseConnectivity)

	// Test listing nodes
	nodes, err := client.ListNodes(ctx, "")
	if err != nil {
		log.Fatalf("Failed to list nodes: %v", err)
	}

	fmt.Printf("Found %d nodes in headscale:\n", len(nodes))
	for _, node := range nodes {
		fmt.Printf("  - ID: %s, Name: %s, IPs: %v, Online: %t\n",
			node.ID, node.Name, node.IPAddresses, node.Online)
	}

	fmt.Println("Headscale client integration test completed successfully!")
}
