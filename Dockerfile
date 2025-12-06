# Use the latest golang alpine image to build the plugin
FROM golang:1.24.10-alpine AS builder

# Install git and other dependencies
RUN apk add --no-cache git bash curl

# Set the working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the source code
COPY . .

# Build the plugin as part of CoreDNS
RUN go build -buildmode=plugin -o k8s_cross.so github.com/wold9168/k8s_cross

# Final stage: copy the plugin to a minimal image
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Install CoreDNS
RUN apk add --no-cache coredns

# Copy the plugin
COPY --from=builder /app/k8s_cross.so /root/k8s_cross.so

# Create the plugin directory
RUN mkdir -p /root/coredns_plugins

# Copy plugin
RUN cp /root/k8s_cross.so /root/coredns_plugins/

# Expose port 53
EXPOSE 53 53/udp

CMD ["coredns", "-conf", "/root/Corefile"]