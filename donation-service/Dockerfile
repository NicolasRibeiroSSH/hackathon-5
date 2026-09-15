FROM public.ecr.aws/docker/library/golang:1.24-alpine AS builder
WORKDIR /app
RUN apk add --no-cache git
COPY go.mod go.sum ./
RUN go mod tidy && go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o donation-service .

FROM public.ecr.aws/docker/library/alpine:3.20
WORKDIR /app
RUN apk add --no-cache ca-certificates tzdata
COPY --from=builder /app/donation-service .
EXPOSE 8082
CMD ["./donation-service"]
