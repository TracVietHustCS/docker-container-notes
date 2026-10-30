=== build-best | Image | Viết Dockerfile tốt: cache, multi-stage và buildx
>> Image tốt build nhanh, nhỏ, chạy bằng user thường và không chứa bí mật. Bốn kỹ thuật làm nên phần lớn khác biệt: thứ tự layer để tận dụng cache, multi-stage, BuildKit và quản lý bí mật.

## Thứ tự layer và cache

Docker dùng lại một layer từ cache nếu lệnh **và mọi thứ nó đọc** không đổi. Khi một layer bị vô hiệu, **mọi layer sau nó** đều phải build lại. Vì vậy: đặt thứ **ít đổi** lên trên, thứ **hay đổi** (mã nguồn) xuống dưới.

```
# Xấu: sửa một dòng code là cài lại toàn bộ thư viện
COPY . .
RUN pip install -r requirements.txt

# Tốt: chỉ cài lại thư viện khi requirements.txt đổi
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
```

Gom các lệnh dọn dẹp **cùng một `RUN`** với lệnh tạo ra rác, vì xoá ở layer sau không thu nhỏ image:

```
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
```

## Multi-stage build

Dùng nhiều `FROM`: giai đoạn build có đầy đủ compiler, chỉ **chép kết quả** sang giai đoạn runtime nhỏ gọn.

```
# syntax=docker/dockerfile:1
FROM golang:1.23 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /out/app ./cmd/app

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
USER nonroot
ENTRYPOINT ["/app"]
```

Ví dụ Node.js (giai đoạn runtime dùng image nhỏ và user không phải root):

```
FROM node:22-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps /app/node_modules ./node_modules
COPY . .
USER node
CMD ["node", "server.js"]
```

`docker build --target build .` dừng ở một giai đoạn cụ thể (ví dụ để chạy test hoặc debug). Tên image nền (`golang:1.23`, `distroless`...) chọn phiên bản bạn dùng thật, đây chỉ là ví dụ.

## Chọn image nền

| Loại | Ưu | Nhược |
|---|---|---|
| `debian`/`ubuntu` (đầy đủ) | Tương thích tốt, nhiều công cụ | Lớn, nhiều thành phần |
| `-slim` | Nhỏ hơn, vẫn dùng glibc | Thiếu một số công cụ |
| `alpine` | Rất nhỏ | Dùng musl thay glibc: một số phần mềm biên dịch sẵn hoặc native extension gặp lỗi tương thích |
| distroless | Chỉ có ứng dụng và runtime, ít bề mặt tấn công | Không có shell nên khó debug |
| `scratch` | Rỗng, cho file nhị phân tĩnh (Go, Rust) | Không có gì, kể cả chứng chỉ CA và múi giờ nếu bạn không chép vào |

## BuildKit: cache mount, secret và buildx

**BuildKit** là engine build mặc định của Docker hiện nay (`docker build` và `docker buildx build` đều dùng nó). Một số tính năng cần dòng `# syntax=docker/dockerfile:1` ở đầu Dockerfile.

**Cache mount**: giữ cache của trình quản lý gói giữa các lần build, mà không đưa vào image.

```
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

**Secret mount**: dùng bí mật lúc build (token tải thư viện riêng) mà không để lại trong layer hay `docker history`.

```
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) npm ci
```
```
docker build --secret id=npm_token,src=$HOME/.npm_token -t web:dev .
```

**Build đa nền tảng** với `buildx`:

```
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -t registry.example.com/web:1.4.2 --push .
```

**Chia sẻ cache giữa các máy CI** qua registry:

```
docker buildx build \
  --cache-from type=registry,ref=registry.example.com/web:buildcache \
  --cache-to   type=registry,ref=registry.example.com/web:buildcache,mode=max \
  -t registry.example.com/web:1.4.2 --push .
```

`--progress=plain` in toàn bộ output để xem lệnh nào chậm hay lỗi.

## Danh sách kiểm tra

| Việc | Vì sao |
|---|---|
| Ghim phiên bản (hoặc digest) của image nền | Build lặp lại được, tránh bị đổi ngầm |
| Multi-stage; runtime chỉ chứa thứ cần để chạy | Nhỏ và ít lỗ hổng |
| `.dockerignore` | Context nhỏ, không chép nhầm `.git`, `.env` |
| Thư viện cài trước, mã nguồn chép sau | Tận dụng cache |
| `USER` non-root | Giảm tác hại nếu bị xâm nhập |
| Không đặt bí mật vào `ARG`, `ENV`, `COPY` | Lộ qua layer và `docker history` |
| Exec form cho `CMD`/`ENTRYPOINT` | Ứng dụng là PID 1 và nhận signal |
| Có `HEALTHCHECK` (nếu không chạy dưới Kubernetes) | Biết container khoẻ hay không |
| Một tiến trình chính mỗi container | Dễ giám sát, dễ scale |
| Gắn `LABEL` nguồn gốc (OCI) | Truy ngược được image từ repo nào |

Phân tích image: `docker history IMAGE`, và công cụ `dive` cho phép duyệt từng layer để tìm file thừa. Chuỗi cung ứng (quét, SBOM, ký image): xem [Bảo mật chuỗi cung ứng image](https://tracviethustcs.github.io/k8s-study-notes/#adv-supply-chain).

::: lab So sánh hai cách build
```
mkdir -p ~/bb && cd ~/bb
cat > main.go <<'EOF'
package main
import "fmt"
func main() { fmt.Println("xin chào từ container") }
EOF
printf 'module demo\ngo 1.22\n' > go.mod
printf 'FROM golang:1.23\nWORKDIR /src\nCOPY . .\nRUN CGO_ENABLED=0 go build -o /app .\nCMD ["/app"]\n' > Dockerfile.single
printf 'FROM golang:1.23 AS build\nWORKDIR /src\nCOPY . .\nRUN CGO_ENABLED=0 go build -o /app .\nFROM scratch\nCOPY --from=build /app /app\nCMD ["/app"]\n' > Dockerfile.multi
docker build -q -t go-single -f Dockerfile.single . && docker build -q -t go-multi -f Dockerfile.multi .
docker image ls | grep go-
docker run --rm go-multi
```
So sánh kích thước hai image, và giải thích vì sao bản multi-stage không cần shell hay compiler.
:::

=== registry | Image | Registry, tag và chiến lược đặt tên
>> Registry là nơi image được lưu và phân phối. Cách bạn đặt tag quyết định việc triển khai có truy vết, lặp lại và quay lui được hay không.

## Tên đầy đủ của một image

```
registry.example.com:5000 / team / web : 1.4.2
\_______ registry ______/   \ngăn/  \tên/ \tag/
```

- Không ghi registry thì mặc định là Docker Hub (`docker.io`).
- Không ghi tag thì mặc định là `latest`, **không có nghĩa là bản mới nhất**, chỉ là một tag tên như vậy.
- Có thể thay tag bằng digest: `web@sha256:...`.

## Các loại registry

| Loại | Ví dụ | Ghi chú |
|---|---|---|
| Công cộng | Docker Hub | Có giới hạn số lần pull cho tài khoản ẩn danh và miễn phí, xem chính sách hiện hành; không nên phụ thuộc trực tiếp trong CI production |
| Đi kèm nền tảng | GHCR (GitHub), GitLab Registry, ECR, ACR, GAR | Tích hợp xác thực và quyền với nền tảng |
| Tự dựng | Harbor, Nexus, Artifactory, `registry:2` | Kiểm soát hoàn toàn, có thể quét và sao chép image |

## Thao tác cơ bản

```
docker login registry.example.com
docker tag web:dev registry.example.com/team/web:1.4.2
docker push registry.example.com/team/web:1.4.2
docker pull registry.example.com/team/web:1.4.2
docker logout registry.example.com
```

Thông tin đăng nhập lưu ở `~/.docker/config.json`. Mặc định có thể chỉ mã hoá base64, **không phải mã hoá thật**: dùng credential helper (`credsStore`) của hệ điều hành, và trong CI dùng token ngắn hạn thay vì mật khẩu cá nhân.

## Chiến lược đặt tag

| Tag | Dùng để | Cẩn thận |
|---|---|---|
| `1.4.2` (semver) | Phát hành chính thức | Coi là **bất biến**: không bao giờ push đè |
| `1.4`, `1` | Tiện cho người dùng muốn nhận bản vá | Là tag di động, đừng triển khai production bằng nó |
| `git-3f1a9c2` (git SHA) | Truy ngược chính xác commit | Rất tốt để triển khai: một SHA một image |
| `main`, `dev` | Môi trường thử | Di động, có thể đổi bất kỳ lúc nào |
| `latest` | Gần như không nên dùng để triển khai | Không biết đang chạy bản nào, không quay lui được |

Quy tắc thực tế: CI build **một lần**, gắn tag theo git SHA (và semver khi release), rồi **đưa chính image đó** qua các môi trường (build once, deploy many) thay vì build lại cho từng môi trường. Triển khai bằng digest để không bị đổi ngầm. Xem thêm trong ghi chú [CI/CD](https://tracviethustcs.github.io/cicd-release-notes/).

## Mirror, cache và dọn dẹp

- **Pull-through cache / mirror**: registry nội bộ trung gian giảm tải ra ngoài, tránh giới hạn pull và vẫn chạy được khi registry công cộng gặp sự cố. Cấu hình `registry-mirrors` trong `daemon.json` (xem [Daemon và log](#daemon-logs)).
- **Retention**: đặt chính sách xoá image cũ (theo tuổi, số lượng), nếu không registry đầy dần. Với `registry:2` cần chạy garbage collect.
- **Quét lỗ hổng** ở registry (Harbor tích hợp Trivy) và quét lại định kỳ.
- **Sao chép giữa các registry** (`crane copy`, `skopeo copy`) để mirror image đã duyệt.

```
docker run -d -p 127.0.0.1:5000:5000 --name registry registry:2
docker tag alpine:3.20 localhost:5000/lab/alpine:3.20
docker push localhost:5000/lab/alpine:3.20
curl -s http://localhost:5000/v2/_catalog
curl -s http://localhost:5000/v2/lab/alpine/tags/list
```

::: lab Chạy registry riêng và thử tag bất biến
```
docker run -d -p 127.0.0.1:5000:5000 --name registry registry:2
docker pull alpine:3.20 && docker tag alpine:3.20 localhost:5000/lab/app:1.0
docker push localhost:5000/lab/app:1.0
docker image ls --digests localhost:5000/lab/app
docker rmi localhost:5000/lab/app:1.0 && docker pull localhost:5000/lab/app:1.0
curl -s http://localhost:5000/v2/_catalog
docker rm -f registry
```
Ghi lại digest trước và sau khi pull. Chúng có giống nhau không, và điều đó cho biết gì về digest?
:::

=== run | Container | Chạy container: docker run và vòng đời
>> `docker run` là lệnh dùng nhiều nhất. Nắm các tuỳ chọn chính và vòng đời container giúp bạn điều khiển và debug mà không phải đoán.

## Vòng đời

```ascii
   docker create            docker start          docker stop / kill, hoặc tiến trình tự thoát
 (image) ---------> created ------------> running ------------------------------------> exited
                                            |   ^                                         |
                                  pause     |   | unpause                                 | docker start
                                            v   |                                         | (chạy lại)
                                            paused                                        v
                                                                                       running
                    docker rm: xoá container (từ created hoặc exited) -> mất lớp ghi và log
```

`docker run` = `docker create` + `docker start` (+ attach nếu không có `-d`). Container đã thoát (`exited`) **vẫn còn** trên đĩa cùng lớp ghi và log cho tới khi `docker rm`; vì thế `docker ps -a` hiện cả container đã dừng.

## Các tuỳ chọn hay dùng

| Tuỳ chọn | Tác dụng |
|---|---|
| `-d` | Chạy nền (detached) |
| `-it` | Giao tiếp tương tác: `-i` giữ stdin, `-t` cấp terminal (dùng cho shell) |
| `--name web` | Đặt tên (tên không được trùng) |
| `--rm` | Tự xoá container khi thoát (cho lệnh chạy một lần) |
| `-p 8080:80` | Publish cổng host:container (xem [Mạng](#networking)) |
| `-e KEY=value`, `--env-file f` | Biến môi trường |
| `-v name:/path`, `--mount` | Gắn volume hoặc bind mount (xem [Volume](#volumes)) |
| `--network net` | Nối mạng người dùng tạo |
| `--restart unless-stopped` | Chính sách tự khởi động lại |
| `--user 1000:1000` | Chạy bằng user chỉ định |
| `--init` | Dùng init nhỏ (tini) làm PID 1: xử lý signal và dọn zombie |
| `--read-only`, `--cap-drop`, `--security-opt` | Giảm quyền (xem [Bảo mật](#security)) |
| `-m`, `--cpus`, `--pids-limit` | Giới hạn tài nguyên (xem [trang riêng](#resources)) |
| `--entrypoint` | Ghi đè entrypoint (hay dùng để vào `sh` debug) |

Mọi thứ sau tên image là **tham số cho container**, không phải cho Docker: `docker run -it alpine sh -c "echo hi"`.

## Restart policy

| Giá trị | Hành vi |
|---|---|
| `no` (mặc định) | Không tự khởi động lại |
| `on-failure[:N]` | Chỉ khi thoát với mã khác 0, tối đa N lần |
| `always` | Luôn khởi động lại, kể cả sau khi daemon khởi động |
| `unless-stopped` | Như `always`, nhưng không khởi động lại nếu bạn đã chủ động `docker stop` |

Khởi động lại tự động che lỗi: container crash liên tục sẽ lặp (Docker tăng dần khoảng chờ). Luôn kèm giám sát và xem `RestartCount`.

## Dừng container

`docker stop` gửi `SIGTERM` tới PID 1, chờ 10 giây (đổi bằng `-t`), rồi gửi `SIGKILL`. `docker kill` gửi `SIGKILL` ngay (hoặc `-s` signal khác). Muốn tắt êm thì ứng dụng phải nhận và xử lý `SIGTERM`: dùng exec form hoặc `--init` (xem [Dockerfile](#dockerfile)).

Mã thoát (`docker inspect -f '{{.State.ExitCode}}'`):

| Mã | Ý nghĩa |
|---|---|
| 0 | Thoát bình thường |
| 1 | Lỗi ứng dụng |
| 125 | Lỗi từ chính `docker run` (tuỳ chọn sai) |
| 126 | Lệnh có nhưng không thực thi được (thiếu quyền) |
| 127 | Không tìm thấy lệnh |
| 137 | Bị `SIGKILL` (thường do OOM, hoặc `docker kill`/hết thời gian stop) |
| 143 | Nhận `SIGTERM` và thoát |

## Quan sát và tương tác

```
docker ps                                   # đang chạy; -a: cả đã dừng
docker logs -f --tail 100 --since 10m web
docker exec -it web sh                      # chạy lệnh trong container đang chạy
docker cp web:/etc/nginx/nginx.conf .
docker inspect web                          # JSON đầy đủ
docker inspect -f '{{.State.Status}} {{.State.ExitCode}} {{.State.OOMKilled}}' web
docker top web                              # process bên trong
docker stats --no-stream                    # CPU, RAM, mạng, I/O
docker events --since 10m                   # sự kiện của daemon
docker ps -a --filter status=exited
```

::: lab Vòng đời bằng tay
```
docker create --name lc alpine:3.20 sh -c 'echo xong; exit 3'
docker ps -a --filter name=lc                    # created
docker start -a lc                               # in "xong"
docker inspect -f '{{.State.Status}} {{.State.ExitCode}}' lc    # exited 3
docker run -d --name loop --restart on-failure:3 alpine:3.20 sh -c 'exit 1'
sleep 12; docker inspect -f 'restart={{.RestartCount}} status={{.State.Status}}' loop
docker rm -f lc loop
```
Giải thích số lần restart bạn thấy và vì sao container cuối cùng dừng hẳn.
:::

=== resources | Container | Giới hạn tài nguyên
>> Không giới hạn thì một container hỏng có thể làm cạn CPU, RAM hay số process của cả máy. Docker dịch các tuỳ chọn thành cgroup, nên hành vi chính là hành vi của kernel.

## Các giới hạn

| Tuỳ chọn | Tác dụng |
|---|---|
| `-m 256m` (`--memory`) | Trần bộ nhớ; vượt thì OOM kill trong cgroup |
| `--memory-swap` | Trần RAM + swap (đặt bằng `--memory` để tắt swap cho container) |
| `--memory-reservation` | Mức "mềm", kernel thu hồi bộ nhớ khi máy thiếu |
| `--cpus 1.5` | Tối đa 1,5 core (throttle theo quota) |
| `--cpu-shares 512` | Trọng số tương đối khi tranh chấp (mặc định 1024) |
| `--cpuset-cpus 0,1` | Ghim vào các core cụ thể |
| `--pids-limit 200` | Giới hạn số process (chống fork bomb) |
| `--ulimit nofile=65536:65536` | Giới hạn số file descriptor |
| `--blkio-weight`, `--device-read-bps` | Giới hạn I/O đĩa |

```
docker run -d --name api -m 512m --memory-swap 512m --cpus 1 --pids-limit 200 myorg/api:1.4.2
```

## CPU và bộ nhớ vượt trần khác nhau

Giống phần giải thích ở [Tài nguyên trong Kubernetes](https://tracviethustcs.github.io/k8s-study-notes/#ops-resources): CPU vượt trần thì bị **throttle** (làm chậm), còn bộ nhớ vượt trần thì bị **OOM kill** (exit code 137). Một container OOM không phải máy hết RAM mà là chính cgroup của nó đầy.

```
docker inspect -f 'oom={{.State.OOMKilled}} exit={{.State.ExitCode}}' api
docker stats --no-stream api
ID=$(docker inspect -f '{{.Id}}' api)
cat /sys/fs/cgroup/system.slice/docker-$ID.scope/memory.max      # cgroup v2, driver systemd
cat /sys/fs/cgroup/system.slice/docker-$ID.scope/cpu.max
```

Đường dẫn cgroup phụ thuộc cgroup driver và phiên bản; xem [cgroups v2](https://tracviethustcs.github.io/linux-network-notes/#os-cgroup). Vài lưu ý:

- `docker stats` hiện `CPU %` theo core: 200% nghĩa là dùng hai core đầy. `MEM USAGE` thường **không tính page cache**, nên con số có thể thấp hơn những gì `memory.current` của cgroup báo.
- Ứng dụng có runtime tự quản lý bộ nhớ (JVM, Node, Go): đặt heap **thấp hơn** giới hạn container, vì còn bộ nhớ ngoài heap. Các bản runtime mới nhận biết giới hạn cgroup, nhưng nên kiểm chứng với phiên bản bạn dùng.
- Đặt giới hạn bộ nhớ quá sát mức dùng thật sẽ gây OOM vào lúc cao điểm; cần có đệm.

## Thói quen tốt

- Mọi container production đều có giới hạn bộ nhớ và `--pids-limit`.
- Đo mức dùng thật trước khi đặt số (`docker stats`, Prometheus + cAdvisor).
- Với Compose, giới hạn khai báo trong `deploy.resources.limits` (xem [Compose thực tế](#compose-patterns)).

::: lab Gây OOM có kiểm soát
```
docker run --rm --name oom -m 64m --memory-swap 64m python:3.12-alpine \
  python -c "b=[]; [b.append(bytearray(8*1024*1024)) for _ in range(100)]"
echo "exit=$?"                                    # 137
docker run -d --name oom2 -m 64m --memory-swap 64m python:3.12-alpine \
  python -c "b=[]; [b.append(bytearray(8*1024*1024)) for _ in range(100)]"
sleep 3; docker inspect -f 'oom={{.State.OOMKilled}} exit={{.State.ExitCode}}' oom2
dmesg -T | tail -5 | grep -i -E "memory cgroup|oom" ; docker rm -f oom2
```
Trả lời: dòng log kernel nói gì về cgroup nào bị OOM? Mã thoát 137 được tính ra sao?
:::
