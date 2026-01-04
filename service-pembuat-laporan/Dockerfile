# Build stage
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod ./
RUN go mod tidy
RUN go get github.com/lib/pq
RUN go get github.com/golang-jwt/jwt/v5
RUN go mod download

# Copy source code
COPY *.go ./

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o service-pembuat-laporan .

# Run stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder
COPY --from=builder /app/service-pembuat-laporan .

EXPOSE 8080

CMD ["./service-pembuat-laporan"]
