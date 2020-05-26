# Vamos preparar nossos arquivos Go

Primeiro vamos criar nosso diretório para nosso aplicativo Go. No m eu caso eu criei um diretórico com o nome `mygoapp` dentro de `/app`, mas nesse caso fica livre a escolha do nome.
```
 $ sudo mkdir /app/mygoapp
```
Entre no diretório:
```
$ cd /app/mygoapp
```

Após isso deve-se inicializar o módulos de dependencias, para isso execute:
```
$ go mod init github.com/mcsnicolete/GoWithDocker
```

 Após isso vamos criar nosso arquivo `main.go`.
 
```
$ nano main.go
```

conteudo do inicial do nosso `main.go`:

```
package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"strconv"


	"github.com/gorilla/mux"
	"gopkg.in/natefinch/lumberjack.v2"
	_ "github.com/mattn/go-sqlite3"
	log "github.com/sirupsen/logrus"
)

func main() {
	r := mux.NewRouter()

	r.HandleFunc("/", hellouser)
	r.HandleFunc("/hu", hellouser)
	r.HandleFunc("/users", getUsers).Methods("GET")
	r.HandleFunc("/healthz", healthzHandler).Methods("GET")
	r.HandleFunc("/users/{id:[0-9]+}", getUser).Methods("GET")
	r.HandleFunc("/users", createUser).Methods("POST")
	r.HandleFunc("/users/{id:[0-9]+}", deleteUser).Methods("DELETE")

	log.SetFormatter(&log.JSONFormatter{})
	log.Info("Starting backend")

	http.ListenAndServe(":8080", r)

	LOG_FILE := os.Getenv("LOG_FILE_LOCATION")
	if LOG_FILE != "" {
	log.SetOutput(&lumberjack.Logger{
		Filename:   LOG_FILE,
		MaxSize:    500, // megabytes
		MaxBackups: 3,
		MaxAge:     28,   //days
		Compress:   true, // disabled by default
	})
}

}

func hellouser(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	n := q.Get("name")
	if n == "" {
		n = "World"
	}
	log.Printf("requestc for %s\n", n)
	w.Write([]byte(fmt.Sprintf("Hello, %s\n", n)))
}

func init() {
	log.SetFormatter(&log.JSONFormatter{})
	log.SetOutput(os.Stdout)
	os.Remove("./backend.db")
	db, err := sql.Open("sqlite3", "./backend.db")
	if err != nil {
		log.WithError(err).Error("Sql open database error")
	}
	defer db.Close()

	sqlDdl := `
	create table users (id integer not null primary key, name text);
	delete from users;
	`

	_, err = db.Exec(sqlDdl)
	if err != nil {
		log.WithError(err).Error(sqlDdl)
		return
	}
}

type User struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

func healthzHandler(w http.ResponseWriter, r *http.Request) {
	log.Info(r)
	w.WriteHeader(200)
	w.Write([]byte("ok"))
}

func getUsers(w http.ResponseWriter, r *http.Request) {
	log.Info(r)
	log.Info("Getting users")

	db, err := sql.Open("sqlite3", "./backend.db")
	db.Begin()
	if err != nil {
		log.WithError(err).Error("Database begin error")
	}

	statement := "select id, name from users"
	rows, err := db.Query(statement)
	if err != nil {
		log.WithError(err).Error(statement)
	}

	var users []User

	for rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Name); err != nil {
			log.WithError(err).Error("No users found")
		}
		users = append(users, u)
	}

	output, err := json.Marshal(users)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.Header().Set("content-type", "application/json")
	w.Write(output)

	defer db.Close()
	defer rows.Close()
}

func getUser(w http.ResponseWriter, r *http.Request) {
	log.Info(r)
	log.Info("Getting user")

	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])

	db, err := sql.Open("sqlite3", "./backend.db")
	db.Begin()
	if err != nil {
		log.WithError(err).Error("Database begin error")
	}

	statement, err := db.Prepare("select id, name from users where id = ?")
	if err != nil {
		log.WithError(err).Error(statement)
	}

	u := User{}
	err = statement.QueryRow(id).Scan(&u.ID, &u.Name)
	if err != nil {
		log.WithError(err).Error(statement)
	}

	output, err := json.Marshal(u)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.Header().Set("content-type", "application/json")
	w.Write(output)

	defer db.Close()
}

func createUser(w http.ResponseWriter, r *http.Request) {
	log.Info(r)
	log.Info("Creating user")
	b, err := ioutil.ReadAll(r.Body)
	defer r.Body.Close()
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}

	// Unmarshal
	var u User
	err = json.Unmarshal(b, &u)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}

	db, err := sql.Open("sqlite3", "./backend.db")
	transaction, err := db.Begin()
	if err != nil {
		log.WithError(err).Error("Database begin error")
	}

	statement := "insert into users (id, name) values ($1, $2)"
	_, err = transaction.Exec(statement, u.ID, u.Name)
	if err != nil {
		log.WithError(err).Error(statement)
		http.Error(w, err.Error(), 500)
	}
	log.Infof("Created user '%d'.", u.ID)

	output, err := json.Marshal(u)
	if err != nil {
		log.WithError(err).Error(output)
		http.Error(w, err.Error(), 500)
	}
	w.Header().Set("content-type", "application/json")
	w.Write(output)

	defer db.Close()
	transaction.Commit()
}

func deleteUser(w http.ResponseWriter, r *http.Request) {
	log.Info(r)
	log.Info("Deleting user")
	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])

	db, err := sql.Open("sqlite3", "./backend.db")
	transaction, err := db.Begin()
	if err != nil {
		log.WithError(err).Error("Database begin error")
	}

	statement := "delete from users where id = $1"
	_, err = transaction.Exec(statement, id)
	if err != nil {
		log.WithError(err).Error(statement)
	}
	log.Infof("Created user '%d'.", id)

	defer db.Close()
	transaction.Commit()
}
```
Note que esse código usa o gorilla mux para criar a rota http, o server passa a ouvir chamadas na porta `8080`.

Agora que o conteúdo do nosso arquivo está ok, vamos rodar o build do nosso app:

```
$ go build
```
No meu caso o arquivo gerado foi um `GoWithDocker`, vamos executar ele, e o retorno deve ser algo semelhando ao mostrado abaixo:

```
./GoWithDocker 
2020/05/26 13:16:14 Starting Server
```

Podemos fazer um teste da seguinte maneira efetuando uma chamada via curl:


```
$ curl http://localhost:8080
Hello, world

$ curl http://localhost:8080?name=Dockerfile
Hello, Dockerfile
```



## Rodando um aplicativo Go com docker:

A principio, vamos criar 2 arquivos, o `Dockerfile` e um `run.sh`, para que possamos rodar nossa implantação no Docker. O `Dockerfile`  nada mais é que que um arquivo de texto que contém os comandos necessários para a execução da montagem da imagem. Já no arquivo `run.sh` teremos um script que irá construir uma imagem e criará um container do `Dockerfile`.

Tenho um diretório com meu aplicativo Go `/app/mygoapp`, precisamos criar o `Dockerfile` lá dentro.

Vou até meu diretório, que no caso o seu pode ser diferente, mas tem que ser o caminho do seu GoApp.
```
cd /app/mygoapp
```

vou criar o arquivo docker file:

```
$ nano Dockerfile
```

Dentro do `Dockerfile`, adicionaremos os comando necessários para construção da imagem, juntamente com os requisitos extras a serem incluídos dentro da imagem.
Utilizaremos a imagem oficial de `golang` que está no **Dockerhub**, para contruir nossa imagem.

Exemplo do Dockerfile abaixo:
```
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
```
Agora que temos um Dockerfile funcional, precisamos avançar para a proxima etapa, que é a criação do nosso `run.sh`, que tera como objetivo criar o nosso contêiner do Docker. Mas antes, precisamos verificarmos uma porta disponível, no meu caso vou escolher a porta `8080`. O comando para que possamos ver se uma porta está livre é:

```
$ sudo nc localhost 8080 < /dev/null; echo $?
$ 1
```
Após a execução ele deve retornar `1`, isso significa que a porta está disponível para uso. Caso retorne algo diferente disso, deverá selecionar outras porta.
docker container ls
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS                    NAMES
e0ee5ad55f14        mygoapp             "./main"            3 minutes ago       Up 3 minutes        0.0.0.0:8080->8080/tcp   mygoapp
 Dentro do arquivo, deve conter:

```
app1="mygoapp"
docker container rm -f ${app1}
docker build -t ${app1} .
docker run -d -p 8080:8080 \
  --name=${app1} \
  -v $PWD/logs/godocker:/app/logs ${app1}
```

Após isso executar o arquivo run.sh:

```
$ bash run.sh
```

Após isso executar verificar o container deve ser executar o seguinte comando:
```
docker container ls
```

E o retorno deve ser esse aqui:

```
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS                    NAMES
e0ee5ad55f14        mygoapp             "./main"            3 minutes ago       Up 3 minutes        0.0.0.0:8080->8080/tcp   mygoapp
```