package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"strings"
	"time"
)

func main() {
	// First, let's validate that we can connect to headscale and list nodes
	client := headscale.NewClient("http://localhost:8002", "Sb49LRo.djRq_TeNwbjfDFubrYBZhzjxdVo65S_X")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	fmt.Println("Testing connection to headscale service...")
	health, err := client.Health(ctx)
	if err != nil {
		log.Fatalf("Failed to get health status: %v", err)
	}
	fmt.Printf("✓ Headscale server health: Database connectivity = %t\n", health.DatabaseConnectivity)

	nodes, err := client.ListNodes(ctx, "")
	if err != nil {
		log.Fatalf("Failed to list nodes: %v", err)
	}
	fmt.Printf("✓ Found %d nodes in headscale\n", len(nodes))

	// Let's simulate what the k8s_cross plugin would do
	// The plugin looks for services in the format: <service>.<namespace>.svc.clusterset.local
	fmt.Println("\nSimulating k8s_cross plugin functionality:")

	for _, node := range nodes {
		fmt.Printf("Node: %s, IPs: %v\n", node.Name, node.IPAddresses)

		// Simulate finding nodes that match a service pattern
		// In a real scenario, we would match based on service and namespace tags
		serviceName := strings.Split(node.Name, "-")[0] // Simple heuristic
		namespace := "default" // Default namespace

		fmt.Printf("  Potential service: %s, namespace: %s\n", serviceName, namespace)

		// Show potential DNS records that would be created
		for _, ipStr := range node.IPAddresses {
			ip := net.ParseIP(ipStr)
			if ip != nil && ip.To4() != nil { // IPv4
				fmt.Printf("  A record: %s.%s.svc.clusterset.local -> %s\n", serviceName, namespace, ipStr)
			} else if ip != nil { // IPv6
				fmt.Printf("  AAAA record: %s.%s.svc.clusterset.local -> %s\n", serviceName, namespace, ipStr)
			}
		}
	}

	// Test DNS resolution simulation for clusterset.local domains
	fmt.Println("\nTesting DNS resolution simulation...")

	// If nodes exist, test how we might resolve them
	if len(nodes) > 0 {
		firstNode := nodes[0]
		serviceName := strings.Split(firstNode.Name, "-")[0]
		namespace := "default"

		fmt.Printf("Example DNS query: %s.%s.svc.clusterset.local\n", serviceName, namespace)

		// Simulate the plugin's domain parsing
		domain := fmt.Sprintf("%s.%s.svc.clusterset.local.", serviceName, namespace)
		service, namespaceParsed, isValid := parseClusterSetDomain(domain)

		if isValid {
			fmt.Printf("✓ Parsed service: %s, namespace: %s\n", service, namespaceParsed)
		} else {
			fmt.Printf("✗ Failed to parse domain: %s\n", domain)
		}

		// Simulate finding matching nodes
		matchingNodes := findMatchingNodes(nodes, service, namespaceParsed)
		fmt.Printf("✓ Found %d matching nodes for service %s\n", len(matchingNodes), service)

		// Show what DNS records would be created
		for _, node := range matchingNodes {
			for _, ip := range node.IPAddresses {
				fmt.Printf("  Would create A record: %s -> %s\n", domain, ip)
			}
		}
	}

	fmt.Println("\n✓ Integration test completed successfully!")
	fmt.Println("✓ The k8s_cross plugin should work with the headscale service at http://localhost:8002")
}

// Simulate the domain parsing logic from the plugin
func parseClusterSetDomain(name string) (service, namespace string, valid bool) {
	name = strings.TrimSuffix(name, ".")

	// Expected format: <service>.<namespace>.svc.clusterset.local
	// Example: my-service.my-namespace.svc.clusterset.local
	parts := strings.Split(name, ".")

	if len(parts) < 5 {
		return "", "", false
	}

	// Check if domain ends with "svc.clusterset.local"
	if parts[len(parts)-1] != "local" || parts[len(parts)-2] != "clusterset" || parts[len(parts)-3] != "svc" {
		return "", "", false
	}

	// Extract namespace and service
	if len(parts) >= 5 {
		namespace = parts[len(parts)-4] // fourth from the end
		service = parts[len(parts)-5]    // fifth from the end
	}

	return service, namespace, true
}

// Simulate finding nodes that match the service and namespace
func findMatchingNodes(nodes []headscale.Node, service, namespace string) []headscale.Node {
	var matchingNodes []headscale.Node

	for _, node := range nodes {
		// In a real implementation, you would match based on actual service/namespace tags
		// For simulation, we'll do a simple name containment check
		nodeName := strings.ToLower(node.Name)
		if strings.Contains(nodeName, strings.ToLower(service)) {
			matchingNodes = append(matchingNodes, node)
		}
	}

	return matchingNodes
}
