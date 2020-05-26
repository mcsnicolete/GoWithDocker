# Imagem latest do golang
FROM golang:latest

# Isso é uma tag com informnações do maintainer da aplicação
LABEL maintainer="Marcos Nicolete <mcsnicolete@gmail.com>"

# Esse será o workdir do container
WORKDIR /app

# Build args
ARG LOG_DIR=/app/logs

# Create Log Directory
RUN mkdir -p ${LOG_DIR}

# Environment Variables
ENV LOG_FILE_LOCATION=${LOG_DIR}/app.log 

# Copy go mod and sum files
COPY go.mod go.sum ./

# Etapa de download de todas as dependencias
RUN go mod download

# Vamos efetuar uma copia do source para o nosso dir atual
COPY . .

# Etapa de build do nosso Go App
RUN go build -o main .

# Nosso Go App irá trabalhar na porta 8080
EXPOSE 8080

# Volumes que utilizaremos para o Log
VOLUME [${LOG_DIR}]

# local dos binarios do nosso Go App apoós o `go install`
CMD ["./main"]