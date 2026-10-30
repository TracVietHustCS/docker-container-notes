=== overview | Bắt đầu | Tổng quan và cách học
>> Bộ ghi chú về Docker và container cho người làm DevOps: từ khái niệm, build image, chạy container, mạng, lưu trữ, Compose đến bảo mật và xử lý sự cố. Đọc theo thứ tự thì mỗi trang dựa trên trang trước; cũng có thể tra riêng từng trang.

::: warn Đọc trước khi dùng
Đây là ghi chú **tự học, tự soạn**, không phải tài liệu chính thức của Docker, Inc. Tuỳ chọn dòng lệnh, giá trị mặc định và tính năng thay đổi theo phiên bản Docker Engine, Docker Desktop và BuildKit. Ghi chú không tra cứu trực tuyến nên có thể lỗi thời: hãy đối chiếu **docs.docker.com** và `docker <lệnh> --help` trước khi áp dụng, đặc biệt với lệnh có thể xoá dữ liệu.
:::

## Bạn sẽ làm được gì sau khi học xong

- Giải thích container là gì ở mức Linux (namespace, cgroup, filesystem phân lớp) và khác máy ảo ở đâu.
- Viết Dockerfile nhỏ, build nhanh nhờ cache, an toàn (multi-stage, non-root, không lộ bí mật).
- Chạy, giới hạn, debug container; hiểu volume, bind mount và mạng bridge.
- Dựng một stack nhiều dịch vụ bằng Compose, có healthcheck và tách môi trường dev/prod.
- Áp dụng các biện pháp bảo mật cơ bản và xử lý được các sự cố hay gặp.

## Cấu trúc

| Nhóm | Trang | Nội dung |
|---|---|---|
| Khái niệm | [Container là gì](#why-containers) | Cơ chế, kiến trúc Docker, OCI |
| Image | [Image và layer](#images), [Dockerfile](#dockerfile), [Dockerfile tốt](#build-best), [Registry](#registry) | Tạo, tối ưu, phân phối image |
| Container | [docker run](#run), [Giới hạn tài nguyên](#resources) | Chạy và kiểm soát container |
| Lưu trữ và mạng | [Volume](#volumes), [Mạng](#networking) | Dữ liệu bền và kết nối |
| Compose | [Compose cơ bản](#compose), [Compose thực tế](#compose-patterns) | Nhiều dịch vụ trên một máy |
| Bảo mật | [Bảo mật container](#security) | Giảm rủi ro khi chạy |
| Vận hành | [Daemon và log](#daemon-logs), [Xử lý sự cố](#troubleshooting), [Hệ sinh thái](#ecosystem) | Vận hành hằng ngày |
| Tham chiếu | [Cheat sheet](#cli-ref), [Luyện tập 1](#quiz-1), [Luyện tập 2](#quiz-2) | Tra nhanh và tự kiểm tra |

## Cài đặt môi trường lab

| Cách | Hợp với | Ghi chú |
|---|---|---|
| Docker Engine trên Linux | Học đúng như production | Cài theo hướng dẫn của docs.docker.com cho distro của bạn; thêm user vào group `docker` hoặc dùng `sudo` |
| Docker Desktop (Windows, macOS) | Máy cá nhân | Chạy Docker Engine trong một VM nhẹ; có điều khoản cấp phép cho tổ chức lớn, hãy kiểm tra |
| WSL2 (Windows) | Học dòng lệnh | Docker Desktop tích hợp WSL2, hoặc cài Engine trực tiếp trong bản Linux của WSL2 |
| Multipass hoặc VM Ubuntu | Lab về mạng, cgroup | Có kernel Linux thật, hợp với các lab sâu |

```
docker version
docker info
docker run --rm hello-world
```

::: tip Group docker tương đương quyền root
Người thuộc group `docker` điều khiển được daemon, mà daemon chạy bằng root: họ có thể mount cả hệ thống file của máy vào một container. Chỉ thêm người bạn tin, và xem [Bảo mật](#security) về chế độ rootless.
:::

## Liên quan tới các ghi chú khác

Docker dựa hoàn toàn vào các cơ chế của Linux: xem [namespace](https://tracviethustcs.github.io/linux-network-notes/#os-namespace), [cgroups](https://tracviethustcs.github.io/linux-network-notes/#os-cgroup), [dựng container từ đầu](https://tracviethustcs.github.io/linux-network-notes/#os-container) và [mạng Linux](https://tracviethustcs.github.io/linux-network-notes/#net-linux) trong ghi chú Linux. Khi cần chạy nhiều container trên nhiều máy, bước tiếp theo là [Kubernetes](https://tracviethustcs.github.io/k8s-study-notes/).

=== why-containers | Khái niệm | Container là gì và kiến trúc Docker
>> Container là process Linux bị giới hạn về những gì nó thấy và dùng được, chạy từ một image chứa sẵn mọi thứ nó cần. Docker là bộ công cụ làm việc đó dễ dùng.

## Vấn đề container giải quyết

"Chạy được trên máy tôi" xảy ra vì ứng dụng phụ thuộc vào hệ điều hành, thư viện, phiên bản runtime và cấu hình của máy. Container đóng gói ứng dụng cùng toàn bộ phụ thuộc userspace vào một **image** bất biến, để cùng một image chạy giống nhau trên laptop, CI và production.

## Container ở mức Linux

Một container không phải là một "thứ" mà kernel biết. Nó là một process thông thường được bọc bởi:

- **Namespace**: giới hạn những gì process nhìn thấy (cây PID, mount, mạng, hostname, user...). Xem [Namespace](https://tracviethustcs.github.io/linux-network-notes/#os-namespace).
- **cgroup**: giới hạn những gì process dùng được (CPU, RAM, I/O, số process). Xem [cgroups v2](https://tracviethustcs.github.io/linux-network-notes/#os-cgroup).
- **Filesystem phân lớp** (overlayfs): các lớp chỉ đọc của image cộng một lớp ghi riêng của container.
- **Capabilities, seccomp, AppArmor/SELinux**: giới hạn những gì process được phép làm.

Kết quả quan trọng: container **dùng chung kernel** với máy chủ. Vì vậy container Linux cần kernel Linux, khởi động trong mili giây, nhưng cô lập yếu hơn máy ảo.

| | Máy ảo | Container |
|---|---|---|
| Kernel | Mỗi VM một kernel riêng | Dùng chung kernel máy chủ |
| Khởi động | Giây đến phút | Mili giây đến giây |
| Kích thước | Hàng GB (cả hệ điều hành) | Hàng chục đến vài trăm MB |
| Cô lập | Mạnh (ranh giới hypervisor) | Yếu hơn (ranh giới kernel) |
| Mật độ trên một máy | Thấp hơn | Cao hơn |

## Kiến trúc Docker

```ascii
  docker CLI  ----REST API qua /var/run/docker.sock---->  dockerd (Docker daemon)
                                                             |  quản lý image, mạng, volume, build
                                                             v
                                                        containerd           quản lý vòng đời container
                                                             |
                                                       containerd-shim       giữ container chạy khi daemon restart
                                                             |
                                                           runc              tạo namespace + cgroup, chạy process (chuẩn OCI)
                                                             |
                                                       process container     (ứng dụng của bạn)
```

- **Docker CLI** chỉ là client gọi API. Biến `DOCKER_HOST` quyết định daemon nào nó nói chuyện.
- **dockerd** lo phần "nền tảng": build, mạng, volume, API. Nó giao việc chạy container cho **containerd**.
- **runc** là runtime tham chiếu theo chuẩn OCI: thực sự tạo ra container.
- Docker Desktop trên Windows và macOS chạy daemon trong một VM Linux nhẹ, nên "localhost" và đường dẫn file có khác biệt so với Linux.

### Chuẩn OCI

Open Container Initiative định nghĩa ba chuẩn: **image spec** (định dạng image), **runtime spec** (cách chạy container) và **distribution spec** (API của registry). Nhờ đó image build bằng Docker chạy được trên Podman, containerd, Kubernetes và ngược lại.

## Từ vựng

| Thuật ngữ | Nghĩa |
|---|---|
| Image | Gói chỉ đọc gồm các lớp filesystem và metadata (lệnh chạy, biến môi trường) |
| Container | Một lần chạy của image: process cộng lớp ghi riêng |
| Registry | Nơi lưu và phân phối image (Docker Hub, GHCR, ECR, Harbor...) |
| Dockerfile | Tệp mô tả cách build image |
| Volume | Nơi lưu dữ liệu bền ngoài vòng đời container |
| Network | Mạng ảo nối các container |
| Compose | Công cụ mô tả và chạy nhiều container cùng nhau bằng một file YAML |

::: lab Nhìn container ở dưới nắp
```
docker run -d --name web nginx:alpine
ps -ef --forest | grep -B2 -A2 "nginx: master"        # chuỗi containerd-shim -> nginx
PID=$(docker inspect -f '{{.State.Pid}}' web); echo $PID
ls -l /proc/$PID/ns                                     # các namespace của container
cat /proc/$PID/cgroup
sudo nsenter -t $PID -n ip -br addr                     # mạng bên trong container
docker rm -f web
```
Trả lời: PID của nginx trên máy chủ khác PID 1 bên trong container thế nào? Namespace nào khác với shell của bạn?
:::

=== images | Image | Image, layer và digest
>> Image là chuỗi các lớp chỉ đọc cộng metadata, nhận diện bằng digest. Hiểu layer giải thích vì sao build nhanh hay chậm, vì sao image nặng, và vì sao tag không đáng tin.

## Layer

Mỗi lệnh thay đổi filesystem trong Dockerfile (`RUN`, `COPY`, `ADD`) tạo một **layer**: một bản diff so với layer trước. Image là chồng các layer; container thêm một lớp **ghi** (writable) lên trên cùng. Docker dùng một storage driver (phổ biến nhất là `overlay2`, dựa trên overlayfs của Linux, xem [Dựng container từ đầu](https://tracviethustcs.github.io/linux-network-notes/#os-container)) để hợp nhất các lớp thành một cây thư mục duy nhất.

```ascii
   Container (lớp ghi)   <- thay đổi lúc chạy, mất khi xoá container
   ----------------------
   Layer 4: COPY app/ /app          } các lớp image:
   Layer 3: RUN pip install ...     } chỉ đọc,
   Layer 2: RUN apt-get install ... } chia sẻ giữa nhiều image
   Layer 1: base (debian-slim)      } và nhiều container
```

Hệ quả:

- **Chia sẻ**: nhiều image dùng chung base chỉ lưu và tải layer chung một lần.
- **Copy-on-write**: sửa một file ở lớp dưới thì file được sao chép lên lớp ghi rồi mới sửa. Ghi nhiều vào lớp ghi của container chậm và mất khi xoá container: dữ liệu bền phải ở [volume](#volumes).
- **Layer không bao giờ co lại**: xoá file ở layer sau không làm image nhỏ đi, vì file vẫn nằm ở layer trước. Đây là lý do cần gom lệnh và dùng [multi-stage](#build-best).
- **Bí mật lộ trong layer**: một file bí mật đã `COPY` vào rồi `rm` ở lệnh sau vẫn lấy ra được từ layer cũ.

## Tag và digest

- **Tag** (`nginx:1.27`) là tên có thể đọc được, nhưng **có thể bị đổi** để trỏ sang image khác (`latest`, thậm chí `1.27` khi có bản vá).
- **Digest** (`nginx@sha256:3f1a...`) là mã băm của manifest: **bất biến**, nên đảm bảo chạy đúng image bạn đã thử.

Một tag đa kiến trúc trỏ tới một **manifest list** (index) gồm nhiều manifest, mỗi cái cho một nền tảng (`linux/amd64`, `linux/arm64`); Docker chọn đúng cái hợp với máy. Lỗi `exec format error` khi chạy thường do image sai kiến trúc.

## Lệnh cần nhớ

```
docker pull nginx:1.27
docker image ls                              # image đã có; thêm --digests để thấy digest
docker image inspect nginx:1.27              # cấu hình: Env, Cmd, Entrypoint, danh sách layer
docker history nginx:1.27                    # từng layer: lệnh tạo ra và kích thước
docker image ls --filter dangling=true       # image không còn tag
docker image prune                           # xoá image dangling
docker save -o nginx.tar nginx:1.27          # xuất image (kèm layer) ra file
docker load -i nginx.tar
docker diff CONTAINER                        # các file đã đổi trong lớp ghi
docker export CONTAINER > fs.tar             # filesystem phẳng của container (không phải image)
```

`docker save`/`load` làm việc với **image** (giữ layer và tag, dùng để chuyển image sang máy không có mạng), còn `docker export` chỉ lấy filesystem phẳng của một **container**.

::: tip Đừng dùng docker commit để làm image
`docker commit` đóng băng container thành image, nhưng không ai biết nó được tạo thế nào và không tái tạo được. Hãy luôn mô tả bằng Dockerfile, để image có thể build lại từ mã nguồn.
:::

::: lab Nhìn layer và lớp ghi
```
docker pull alpine:3.20
docker history alpine:3.20
docker image inspect alpine:3.20 --format '{{json .RootFS.Layers}}'
docker run -d --name t alpine:3.20 sleep 300
docker exec t sh -c 'echo hi > /tmp/new.txt; rm /etc/motd'
docker diff t                                # A = thêm, C = đổi, D = xoá
docker rm -f t
docker image ls --digests alpine
```
Câu hỏi: lệnh nào trong `docker history` tạo ra lớp lớn nhất? Sau `docker rm`, tệp `/tmp/new.txt` còn không?
:::

=== dockerfile | Image | Dockerfile: tham chiếu các lệnh
>> Dockerfile là công thức build image. Trang này tóm tắt các lệnh, và những cặp dễ nhầm: CMD với ENTRYPOINT, COPY với ADD, ARG với ENV.

## Ví dụ tối thiểu

```
# syntax=docker/dockerfile:1
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
USER 10001
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request,sys; urllib.request.urlopen('http://127.0.0.1:8000/health')" || exit 1
CMD ["python", "-m", "app"]
```

## Các lệnh

| Lệnh | Tác dụng | Ghi chú |
|---|---|---|
| `FROM` | Chọn image nền; có thể nhiều `FROM` (multi-stage) | Ghim phiên bản, tốt hơn là digest |
| `RUN` | Chạy lệnh lúc build, tạo layer mới | Gom các lệnh liên quan trong một `RUN` |
| `COPY` | Chép file từ build context vào image | Ưu tiên hơn `ADD` |
| `ADD` | Như `COPY` nhưng giải nén tar cục bộ và tải URL | Chỉ dùng khi cần giải nén tar |
| `WORKDIR` | Đặt thư mục làm việc (tạo nếu chưa có) | Dùng thay cho `RUN cd` |
| `ENV` | Biến môi trường, tồn tại cả lúc chạy | Không đặt bí mật ở đây |
| `ARG` | Biến chỉ có lúc build (`--build-arg`) | Hiện trong `docker history`: không dùng cho bí mật |
| `USER` | Chạy các lệnh sau (và container) bằng user này | Luôn đặt user non-root |
| `EXPOSE` | Ghi chú cổng ứng dụng lắng nghe | **Không** mở cổng, chỉ là tài liệu |
| `VOLUME` | Khai báo mount point; tạo volume ẩn danh | Thường nên tránh, khai báo ở `docker run` hoặc Compose |
| `CMD` | Lệnh mặc định khi chạy | Bị ghi đè bởi tham số sau tên image |
| `ENTRYPOINT` | Chương trình chính, cố định | `CMD` thành tham số của nó |
| `HEALTHCHECK` | Lệnh kiểm tra container khoẻ | Trạng thái xem ở `docker ps` |
| `STOPSIGNAL` | Signal dừng (mặc định `SIGTERM`) | Đặt khi ứng dụng cần signal khác |
| `LABEL` | Metadata (chuẩn OCI: `org.opencontainers.image.*`) | Ghi nguồn, phiên bản, giấy phép |
| `SHELL` | Đổi shell cho dạng shell form | Hiếm dùng |

## CMD, ENTRYPOINT và hai dạng viết

Mỗi lệnh `RUN`, `CMD`, `ENTRYPOINT` có hai dạng:

- **Exec form**: `CMD ["python", "app.py"]`. Chạy chương trình **trực tiếp**, nó là PID 1 và nhận signal trực tiếp.
- **Shell form**: `CMD python app.py`. Docker chạy `/bin/sh -c "python app.py"`: PID 1 là `sh`, và nhiều shell **không chuyển tiếp signal**, nên `docker stop` không tắt êm được ứng dụng (xem [Process và PID 1](https://tracviethustcs.github.io/linux-network-notes/#os-process)).

Cách dùng thường gặp:

| Mục đích | Viết |
|---|---|
| Chạy một ứng dụng, cho phép ghi đè lệnh khi debug | `CMD ["app", "--port", "8000"]` |
| Image hoạt động như một công cụ (`docker run img arg1 arg2`) | `ENTRYPOINT ["tool"]` và `CMD ["--help"]` |
| Cần xử lý biến môi trường rồi mới chạy | Script `entrypoint.sh` kết thúc bằng `exec "$@"` |

`exec "$@"` ở cuối script rất quan trọng: nó **thay** shell bằng ứng dụng, để ứng dụng trở thành PID 1 và nhận signal.

## ARG và ENV

`ARG` chỉ tồn tại lúc build; `ENV` tồn tại cả trong image và container lúc chạy. Cả hai đều **để lộ** giá trị qua `docker history` và `docker inspect`, nên đừng truyền token hay mật khẩu bằng hai cách này (xem [Dockerfile tốt](#build-best) về `--mount=type=secret`).

## Build context và .dockerignore

`docker build .` gửi toàn bộ thư mục hiện tại (**build context**) cho daemon. Context lớn làm build chậm và dễ chép nhầm file nhạy cảm vào image. Tạo `.dockerignore`:

```
.git
node_modules
*.log
.env
**/__pycache__
dist
```

```
docker build -t web:dev .
docker build -t web:dev -f docker/Dockerfile.prod .
docker build --build-arg VERSION=1.4.2 --target runtime -t web:1.4.2 .
```

::: lab Hiểu PID 1 qua hai dạng viết
```
mkdir -p ~/df && cd ~/df
cat > app.py <<'EOF'
import signal, sys, time
signal.signal(signal.SIGTERM, lambda *a: (print("nhận SIGTERM, thoát", flush=True), sys.exit(0)))
print("đã khởi động", flush=True)
while True: time.sleep(1)
EOF
printf 'FROM python:3.12-alpine\nCOPY app.py .\nCMD python app.py; echo bye\n' > Dockerfile.shell
printf 'FROM python:3.12-alpine\nCOPY app.py .\nCMD ["python","app.py"]\n' > Dockerfile.exec
docker build -q -t t-shell -f Dockerfile.shell . && docker build -q -t t-exec -f Dockerfile.exec .
docker run -d --name a t-shell && docker run -d --name b t-exec
docker exec a ps; docker exec b ps            # a: PID 1 là "sh -c ...", b: PID 1 là python
time docker stop a; time docker stop b        # a mất ~10 giây (bị SIGKILL), b dừng ngay
docker logs b                                 # có dòng "nhận SIGTERM, thoát"
docker rm -f a b
```
Giải thích vì sao `docker stop a` chậm: signal tới PID 1 là `sh`, không có handler nên bị bỏ qua. (Dùng `;` trong shell form để shell không tối ưu hoá thành `exec`.)
:::
