FROM golang:1.24-alpine AS builder

WORKDIR /app
COPY go.mod ./
RUN go mod tidy
RUN go get github.com/golang-jwt/jwt/v5
RUN go get github.com/lib/pq
RUN go get golang.org/x/crypto/bcrypt
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o service-auth-warga .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/service-auth-warga .
EXPOSE 8081
CMD ["./service-auth-warga"]
