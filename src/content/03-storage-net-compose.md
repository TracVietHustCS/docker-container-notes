=== volumes | Lưu trữ và mạng | Volume, bind mount và tmpfs
>> Lớp ghi của container mất khi container bị xoá. Dữ liệu cần giữ phải nằm ở nơi khác: volume do Docker quản lý, thư mục của host gắn vào (bind mount), hoặc RAM (tmpfs).

## Ba cách lưu dữ liệu

| Loại | Dữ liệu nằm ở đâu | Dùng khi | Lưu ý |
|---|---|---|---|
| **Volume** (named) | `/var/lib/docker/volumes/NAME/_data`, Docker quản lý | Dữ liệu ứng dụng cần giữ (database, upload) | Cách được khuyên cho dữ liệu bền; độc lập với đường dẫn host |
| **Bind mount** | Thư mục bạn chỉ định trên host | Mã nguồn khi phát triển, file cấu hình | Phụ thuộc cấu trúc thư mục host; vấn đề quyền; có thể sửa file host từ container |
| **tmpfs** | RAM | Dữ liệu tạm, nhạy cảm, không cần giữ | Mất khi container dừng; tốn RAM |

```
docker volume create pgdata
docker run -d --name db -v pgdata:/var/lib/postgresql/data -e POSTGRES_PASSWORD=secret postgres:16
docker run -d -v "$PWD/conf":/etc/app:ro myorg/app           # bind mount chỉ đọc
docker run -d --tmpfs /tmp:rw,size=64m myorg/app
```

Hai cú pháp:

```
-v pgdata:/var/lib/postgresql/data                         # ngắn gọn
--mount type=volume,source=pgdata,target=/var/lib/postgresql/data     # tường minh
--mount type=bind,source="$PWD/conf",target=/etc/app,readonly
```

`--mount` báo lỗi nếu đường dẫn nguồn của bind mount không tồn tại, còn `-v` sẽ **tự tạo thư mục rỗng** (thường là thư mục thuộc root), nguồn gốc của nhiều lỗi quyền khó hiểu.

## Vòng đời và các cái bẫy

- **Volume tồn tại sau khi xoá container** (trừ volume ẩn danh khi dùng `docker rm -v`). Để dọn: `docker volume ls`, `docker volume rm NAME`, `docker volume prune` (xoá volume không có container nào dùng: cẩn thận).
- **Volume ẩn danh** sinh ra từ lệnh `VOLUME` trong Dockerfile khi bạn không gắn volume có tên: chúng chất đống theo từng lần `docker run`. Nên gắn volume có tên cho dữ liệu cần giữ.
- **Khởi tạo nội dung**: khi gắn volume **trống** vào một thư mục đã có dữ liệu trong image, Docker chép dữ liệu image vào volume lần đầu. Bind mount thì **che** nội dung của image bằng nội dung thư mục host.
- **Quyền và UID**: file do process trong container tạo ra mang UID của process đó (thường không trùng user trên host). Bind mount thư mục mà UID không khớp sẽ lỗi `permission denied`. Cách xử lý: chạy container với `--user "$(id -u):$(id -g)"`, hoặc `chown` thư mục cho UID của ứng dụng, hoặc dùng volume có tên.
- **SELinux** (RHEL, Fedora): thêm hậu tố `:z` (chia sẻ) hoặc `:Z` (riêng) vào bind mount, ví dụ `-v $PWD/conf:/etc/app:ro,z`.
- **Hiệu năng trên Docker Desktop**: bind mount qua VM chậm hơn volume; ưu tiên volume cho thư mục nặng I/O (node_modules, database).

## Sao lưu và khôi phục volume

```
# Sao lưu volume ra tệp tar
docker run --rm -v pgdata:/data:ro -v "$PWD":/backup alpine tar czf /backup/pgdata.tgz -C /data .
# Khôi phục vào volume mới
docker volume create pgdata2
docker run --rm -v pgdata2:/data -v "$PWD":/backup alpine tar xzf /backup/pgdata.tgz -C /data
```

Chép file của database đang chạy cho bản sao **không nhất quán**: với database, dùng công cụ riêng (`pg_dump`, `mysqldump`) hoặc dừng container trước khi sao lưu. Xem thêm [Backup, rsync](https://tracviethustcs.github.io/linux-network-notes/#lx-backup).

## Dung lượng

```
docker system df                 # image, container, volume, build cache
docker system df -v
docker volume ls -f dangling=true
```

::: lab Dữ liệu sống sót, lớp ghi thì không
```
docker volume create demo
docker run --rm -v demo:/d alpine sh -c 'echo "trong volume" > /d/a.txt'
docker run --rm -v demo:/d alpine cat /d/a.txt                       # còn
docker run --rm alpine sh -c 'echo "trong lớp ghi" > /tmp/b.txt'
docker run --rm alpine cat /tmp/b.txt                                # lỗi: container mới, lớp ghi mới
sudo ls /var/lib/docker/volumes/demo/_data
docker volume rm demo
```
Giải thích vì sao lần đọc thứ hai thất bại còn lần đầu thì không.
:::

=== networking | Lưu trữ và mạng | Mạng Docker
>> Mạng Docker là bridge Linux, cặp veth và luật iptables do Docker dựng sẵn. Hiểu các mảnh đó giúp bạn giải thích được vì sao container gọi nhau bằng tên, và vì sao một cổng "mở ra ngoài" đôi khi mở quá tay.

## Các driver mạng

| Driver | Mô tả | Dùng khi |
|---|---|---|
| `bridge` | Mạng ảo riêng trên một máy, container có IP riêng và ra ngoài qua NAT | Mặc định và phổ biến nhất |
| `host` | Container dùng thẳng mạng của host (không cô lập mạng) | Cần hiệu năng mạng tối đa, hoặc nhiều cổng; mất cô lập |
| `none` | Chỉ có loopback | Container không cần mạng |
| `overlay` | Nối nhiều máy Docker (Swarm) | Cụm nhiều máy; Kubernetes dùng CNI thay thế |
| `macvlan` | Container có MAC và IP ngang hàng với mạng vật lý | Cần xuất hiện như thiết bị thật trên LAN |

## Bridge mặc định và bridge người dùng tạo

| | Bridge mặc định (`bridge`, `docker0`) | Bridge do bạn tạo |
|---|---|---|
| Phân giải tên | **Không**, chỉ dùng IP (hoặc `--link` đã lỗi thời) | **Có**: container gọi nhau bằng tên (DNS nhúng tại `127.0.0.11`) |
| Cô lập | Mọi container không chỉ định mạng đều ở chung | Chỉ container nối cùng mạng mới thấy nhau |
| Gắn/gỡ khi chạy | Không linh hoạt | `docker network connect/disconnect` |

Vì vậy hãy luôn tạo mạng riêng cho mỗi ứng dụng (Compose làm việc này tự động):

```
docker network create appnet
docker run -d --name db --network appnet -e POSTGRES_PASSWORD=secret postgres:16
docker run --rm --network appnet alpine ping -c1 db            # gọi bằng tên "db"
docker network inspect appnet
```

## Dưới nắp: bridge, veth và iptables

```ascii
   container A (netns)         container B (netns)
     eth0 172.18.0.2             eth0 172.18.0.3
        |  (cặp veth)               |  (cặp veth)
   vethXXXX -----+-------------+---- vethYYYY
                 |    br-xxxx   |            <- bridge Linux (switch ảo), 172.18.0.1
                 +------+-------+
                        |
                  iptables NAT  (MASQUERADE cho gói đi ra, DNAT cho cổng publish)
                        |
                      eth0 của host  --->  mạng ngoài
```

Đây chính là mạng bạn có thể tự dựng bằng `ip netns`, veth và bridge, xem [Mạng trong Linux](https://tracviethustcs.github.io/linux-network-notes/#net-linux) và [NAT](https://tracviethustcs.github.io/linux-network-notes/#net-nat). Docker chỉ tự động hoá nó.

## Publish cổng

Container ở bridge có IP riêng, bên ngoài không truy cập được. `-p` thiết lập luật **DNAT** để chuyển cổng của host vào container:

```
docker run -d -p 8080:80 nginx                    # mọi giao diện của host, cổng 8080 -> 80
docker run -d -p 127.0.0.1:8080:80 nginx          # chỉ truy cập từ chính máy
docker run -d -p 8080:80/udp myorg/dns            # UDP
docker run -d -P nginx                            # cổng host ngẫu nhiên cho mọi cổng EXPOSE
docker port NAME
```

::: warn Publish cổng mà không chỉ định địa chỉ là mở ra mọi giao diện
`-p 5432:5432` cho phép **cả mạng** kết nối vào database, và vì Docker tự chèn luật iptables riêng, nó **bỏ qua `ufw`** và nhiều cấu hình firewall bạn tưởng đang bảo vệ. Với dịch vụ chỉ dùng nội bộ: không publish, hoặc bind `127.0.0.1`, hoặc nối qua mạng Docker. Luật tuỳ chỉnh đặt ở chain `DOCKER-USER`.
:::

`EXPOSE` trong Dockerfile **không mở cổng**, chỉ là ghi chú.

## Truy cập host và DNS

- Từ container gọi ra máy chủ: trên Docker Desktop dùng `host.docker.internal`; trên Linux thêm `--add-host=host.docker.internal:host-gateway`.
- DNS của container lấy từ cấu hình của host, hoặc đặt riêng: `--dns 10.0.0.2`, `--dns-search example.internal`.
- Trong mạng người dùng tạo, `127.0.0.11` là resolver nhúng của Docker: tên container và alias (`--network-alias`) được phân giải ở đó, các tên khác chuyển cho DNS ngoài.

## Sự cố thường gặp

| Triệu chứng | Nguyên nhân thường gặp |
|---|---|
| Container này không gọi được container kia bằng tên | Đang ở bridge mặc định, hoặc khác mạng |
| Từ máy khác không truy cập được cổng đã publish | Ứng dụng trong container chỉ lắng nghe `127.0.0.1` thay vì `0.0.0.0`, hoặc firewall của host/cloud chặn |
| Truy cập được từ ngoài dù tưởng đã chặn | `-p` bỏ qua `ufw` |
| Mạng chậm hoặc treo với gói lớn | MTU khác nhau (VPN, overlay) |
| Hai mạng Docker xung đột với mạng văn phòng | Dải IP mặc định của Docker trùng: đổi `default-address-pools` trong `daemon.json` |

```
docker network ls
docker network inspect appnet --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{"\n"}}{{end}}'
sudo iptables -t nat -L -n | grep -E "DOCKER|MASQUERADE"
sudo nsenter -t "$(docker inspect -f '{{.State.Pid}}' web)" -n ss -tlnp
```

::: lab Quan sát mạng thật bên dưới
```
docker network create labnet
docker run -d --name n1 --network labnet nginx:alpine
docker run --rm --network labnet alpine sh -c 'ping -c1 n1; cat /etc/resolv.conf'
ip -br link | grep -E "br-|veth"
docker run -d --name n2 -p 127.0.0.1:8081:80 nginx:alpine
sudo iptables -t nat -L DOCKER -n | grep 8081
curl -sI localhost:8081 | head -1
docker rm -f n1 n2 && docker network rm labnet
```
Vẽ sơ đồ: bridge nào, veth nào, và luật DNAT chuyển cổng 8081 tới địa chỉ nào.
:::

=== compose | Compose | Docker Compose cơ bản
>> Compose mô tả cả một ứng dụng nhiều container (dịch vụ, mạng, volume) trong một file YAML và điều khiển nó bằng vài lệnh. Phù hợp để phát triển, kiểm thử và chạy trên một máy.

## Một file compose.yaml

```
services:
  web:
    image: nginx:1.27-alpine
    ports:
      - "127.0.0.1:8080:80"
    depends_on:
      app:
        condition: service_healthy
  app:
    build: ./app
    environment:
      DATABASE_URL: postgres://app:${DB_PASSWORD}@db:5432/app
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"]
      interval: 10s
      timeout: 3s
      retries: 5
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: app
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d app"]
      interval: 5s
      retries: 10

volumes:
  pgdata:
```

Các khoá cấp cao nhất: `services`, `networks`, `volumes`, `configs`, `secrets`. Khoá `version:` ở đầu file đã lỗi thời trong Compose hiện nay và có thể bỏ. Compose tự tạo một **mạng riêng** cho dự án (nên các dịch vụ gọi nhau bằng tên: `db`, `app`) và đặt tên tài nguyên theo `TÊNDỰÁN-dịch-vụ-số` (tên dự án mặc định là tên thư mục).

## Lệnh hay dùng

| Lệnh | Tác dụng |
|---|---|
| `docker compose up -d` | Tạo và chạy mọi dịch vụ (build nếu cần) |
| `docker compose up -d --build` | Build lại image trước khi chạy |
| `docker compose ps` | Trạng thái dịch vụ |
| `docker compose logs -f app` | Theo dõi log một dịch vụ |
| `docker compose exec app sh` | Vào container đang chạy |
| `docker compose run --rm app pytest` | Chạy một lệnh một lần trong container mới |
| `docker compose stop` / `start` / `restart` | Dừng, chạy lại |
| `docker compose down` | Dừng và **xoá** container và mạng (giữ volume) |
| `docker compose down -v` | Xoá cả volume: **mất dữ liệu** |
| `docker compose config` | In cấu hình đã ghép và thay biến để kiểm tra |
| `docker compose pull` | Tải image mới |

Compose V2 là plugin của Docker (`docker compose`, có dấu cách); lệnh `docker-compose` kiểu cũ (V1) đã bị thay thế.

## Biến và file môi trường

- **Thay thế biến trong chính file YAML**: `${DB_PASSWORD}` lấy từ môi trường shell hoặc từ file `.env` cùng thư mục với `compose.yaml`. Giá trị mặc định: `${PORT:-8080}`, bắt buộc: `${DB_PASSWORD:?cần đặt DB_PASSWORD}`.
- **Biến cho container**: `environment:` (khai báo trực tiếp) hoặc `env_file: [app.env]` (nạp từ file).

Hai thứ này khác nhau: `.env` phục vụ việc **thay thế trong YAML**, còn `env_file` đưa biến **vào container**. Đừng commit file chứa bí mật; xem [Compose thực tế](#compose-patterns) về `secrets`.

## depends_on và healthcheck

`depends_on` mặc định chỉ bảo đảm **thứ tự khởi động**, không phải "đã sẵn sàng". Muốn đợi dịch vụ phụ thuộc thật sự sẵn sàng, đặt `healthcheck` cho nó và dùng `condition: service_healthy`. Ứng dụng vẫn nên tự thử kết nối lại khi database chưa sẵn sàng, vì database có thể khởi động lại sau này.

## Profiles

Gom dịch vụ phụ (công cụ debug, seed dữ liệu) vào profile để không chạy mặc định:

```
services:
  adminer:
    image: adminer
    profiles: ["debug"]
    ports: ["127.0.0.1:8081:8080"]
```
```
docker compose --profile debug up -d
```

::: lab Dựng và phá một stack
```
mkdir -p ~/cp && cd ~/cp
cat > compose.yaml <<'EOF'
services:
  web:
    image: nginx:1.27-alpine
    ports: ["127.0.0.1:8080:80"]
    depends_on:
      cache: {condition: service_healthy}
  cache:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 3s
      retries: 10
    volumes: [cachedata:/data]
volumes:
  cachedata:
EOF
docker compose config | head -20
docker compose up -d && docker compose ps
curl -sI localhost:8080 | head -1
docker compose exec cache redis-cli set k v
docker compose down                       # volume còn
docker compose up -d && docker compose exec cache redis-cli get k
docker compose down -v
```
Quan sát: sau `down` rồi `up`, khoá `k` còn hay mất, và vì sao? Điều gì khác đi khi dùng `down -v`?
:::

=== compose-patterns | Compose | Compose trong thực tế: dev, prod và bí mật
>> Một file Compose dùng được cho cả phát triển lẫn triển khai nhỏ nếu bạn tách phần khác nhau, quản lý bí mật đúng cách và hiểu giới hạn của Compose.

## Tách cấu hình theo môi trường

Compose tự đọc `compose.yaml` rồi **gộp** `compose.override.yaml` nếu có (thường dùng cho dev). Với các môi trường khác, chỉ định rõ các file:

```
# compose.yaml : phần chung
services:
  app:
    image: registry.example.com/team/app:${TAG:-dev}
    restart: unless-stopped

# compose.override.yaml : chỉ cho dev, tự gộp
services:
  app:
    build: ./app
    volumes: ["./app:/src"]
    environment: {DEBUG: "1"}
    ports: ["127.0.0.1:8000:8000"]

# compose.prod.yaml : cho production
services:
  app:
    deploy:
      resources:
        limits: {cpus: "1.0", memory: 512M}
    logging:
      driver: json-file
      options: {max-size: "10m", max-file: "3"}
```
```
docker compose up -d                                            # dev: compose.yaml + override
docker compose -f compose.yaml -f compose.prod.yaml up -d       # prod
```

Dùng `docker compose config` để xem kết quả gộp. Khi gộp, giá trị đơn bị ghi đè và danh sách được nối thêm.

## Tái sử dụng bằng YAML anchor và extension field

```
x-common: &common
  restart: unless-stopped
  logging: {driver: json-file, options: {max-size: "10m", max-file: "3"}}
  security_opt: ["no-new-privileges:true"]

services:
  api:    {<<: *common, image: myorg/api:1.4.2}
  worker: {<<: *common, image: myorg/worker:1.4.2}
```

## Bí mật

Biến môi trường dễ lộ (`docker inspect`, log, file crash). Compose hỗ trợ `secrets`, gắn dưới dạng **file** trong `/run/secrets/TÊN`:

```
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets: [db_password]
secrets:
  db_password:
    file: ./secrets/db_password.txt        # đặt ngoài Git, quyền 600
```

Nhiều image chính thức hỗ trợ hậu tố `_FILE` cho các biến nhạy cảm. Với bí mật thật của production, dùng công cụ quản lý bí mật (Vault, dịch vụ của cloud) thay vì file trên đĩa.

## Giới hạn và an toàn

```
services:
  app:
    image: myorg/app:1.4.2
    init: true                    # tini làm PID 1
    read_only: true
    tmpfs: ["/tmp"]
    cap_drop: ["ALL"]
    user: "10001:10001"
    security_opt: ["no-new-privileges:true"]
    pids_limit: 200
    networks: [backend]
networks:
  backend: {internal: true}       # không ra internet
```

Dùng nhiều mạng để cô lập: ví dụ `frontend` (proxy và ứng dụng) và `backend` (ứng dụng và database), cho database chỉ ở `backend`.

## Một stack hoàn chỉnh

```
services:
  proxy:
    image: nginx:1.27-alpine
    ports: ["80:80"]
    volumes: ["./nginx.conf:/etc/nginx/nginx.conf:ro"]
    networks: [frontend]
    depends_on: {app: {condition: service_healthy}}
  app:
    image: registry.example.com/team/app:1.4.2
    environment: {REDIS_URL: "redis://cache:6379/0", DATABASE_HOST: db}
    secrets: [db_password]
    networks: [frontend, backend]
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://127.0.0.1:8000/health"]
      interval: 10s
      retries: 5
    depends_on:
      db: {condition: service_healthy}
      cache: {condition: service_started}
  cache:
    image: redis:7-alpine
    networks: [backend]
  db:
    image: postgres:16
    environment: {POSTGRES_PASSWORD_FILE: /run/secrets/db_password}
    secrets: [db_password]
    volumes: [pgdata:/var/lib/postgresql/data]
    networks: [backend]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      retries: 10
networks: {frontend: {}, backend: {internal: true}}
volumes: {pgdata: {}}
secrets: {db_password: {file: ./secrets/db_password.txt}}
```

## Compose không phải là gì

Compose chạy trên **một máy**: không có tự phục hồi khi máy chết, không tự rải container qua nhiều máy, không rolling update đúng nghĩa. Dùng cho phát triển, CI, và dịch vụ nhỏ chấp nhận được rủi ro một máy. Khi cần nhiều máy, tự phục hồi và triển khai không gián đoạn, chuyển sang [Kubernetes](https://tracviethustcs.github.io/k8s-study-notes/) (công cụ `kompose` giúp chuyển file Compose thành manifest, nhưng kết quả cần được rà soát và sửa tay).

::: lab Gộp cấu hình hai môi trường
```
mkdir -p ~/cp2 && cd ~/cp2
printf 'services:\n  app:\n    image: nginx:1.27-alpine\n    restart: unless-stopped\n' > compose.yaml
printf 'services:\n  app:\n    ports: ["127.0.0.1:8090:80"]\n    environment: {DEBUG: "1"}\n' > compose.override.yaml
printf 'services:\n  app:\n    deploy:\n      resources:\n        limits: {memory: 128M}\n' > compose.prod.yaml
docker compose config
docker compose -f compose.yaml -f compose.prod.yaml config
```
So sánh hai kết quả: file override tự được gộp khi nào, và không được gộp khi nào?
:::
