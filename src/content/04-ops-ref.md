=== security | Bảo mật | Bảo mật container
>> Container cô lập yếu hơn máy ảo vì dùng chung kernel. Bảo mật nghĩa là thu hẹp những gì process trong container làm được và những gì nó chạm tới được, theo nhiều lớp, để một lớp hỏng không kéo theo cả máy chủ.

## Mô hình mối đe doạ

Giả sử kẻ tấn công **đã chạy được code** trong container của bạn (qua lỗ hổng ứng dụng hay thư viện). Câu hỏi là: họ làm gì được tiếp? Nếu container chạy root, có nhiều capability, mount `docker.sock` hay chạy `--privileged`, câu trả lời thường là "chiếm cả máy chủ". Mục tiêu của các biện pháp dưới đây là làm cho câu trả lời trở thành "gần như không gì cả".

## Các biện pháp theo thứ tự ưu tiên

| Biện pháp | Cách làm | Tác dụng |
|---|---|---|
| **Chạy non-root** | `USER 10001` trong Dockerfile, hoặc `--user 10001:10001` | Process bị xâm nhập không có quyền root trong container |
| **Bỏ capability** | `--cap-drop=ALL --cap-add=NET_BIND_SERVICE` (chỉ thêm cái cần) | Root truyền thống bị chia nhỏ, giữ tối thiểu |
| **Chặn nâng quyền** | `--security-opt no-new-privileges:true` | Chặn setuid biến thành root |
| **Filesystem chỉ đọc** | `--read-only --tmpfs /tmp` | Kẻ tấn công không ghi được công cụ, mã độc vào đĩa |
| **Giới hạn tài nguyên** | `-m`, `--pids-limit`, `--cpus` | Hạn chế tấn công cạn tài nguyên và fork bomb |
| **Giữ profile seccomp mặc định** | Đừng dùng `--security-opt seccomp=unconfined` | Chặn các syscall nguy hiểm |
| **AppArmor / SELinux** | Giữ bật, dùng profile mặc định của Docker | Lớp kiểm soát bắt buộc, xem [SELinux và AppArmor](https://tracviethustcs.github.io/linux-network-notes/#lx-selinux) |
| **Không privileged** | Tránh `--privileged` | Nó trả lại gần như mọi quyền của root trên host và gỡ nhiều lớp bảo vệ |
| **Không mount docker.sock** | Tránh `-v /var/run/docker.sock:...` | Truy cập socket gần như bằng quyền root trên host |
| **Tránh dùng namespace của host** | Tránh `--pid=host`, `--net=host`, `--ipc=host` trừ khi thật cần | Giữ cô lập |
| **Image tin cậy, đã quét** | Quét lỗ hổng, ghim digest, ký (xem bên dưới) | Giảm rủi ro từ chính image |

Lệnh chạy "cứng" điển hình:

```
docker run -d --name app \
  --user 10001:10001 \
  --cap-drop=ALL --security-opt no-new-privileges:true \
  --read-only --tmpfs /tmp \
  -m 256m --pids-limit 200 \
  --network appnet \
  registry.example.com/team/app@sha256:3f1a9c...
```

## Chế độ rootless và user namespace

Mặc định daemon chạy bằng root, nên thoát khỏi container thường nghĩa là có root trên host. Hai cách giảm rủi ro:

- **Rootless mode**: chạy cả daemon và container bằng một user thường (`dockerd-rootless-setuptool.sh install`). Đổi lại có một số hạn chế (mạng, cổng dưới 1024, một số storage driver).
- **userns-remap**: ánh xạ root trong container thành một UID không có quyền trên host (`"userns-remap": "default"` trong `daemon.json`).

Podman chạy rootless theo mặc định, xem [Hệ sinh thái](#ecosystem).

## Bí mật

- Không đặt bí mật vào image (`COPY`, `ENV`, `ARG`): chúng nằm vĩnh viễn trong layer và `docker history`.
- Biến môi trường dễ lộ qua `docker inspect`, `/proc/PID/environ`, log và báo cáo lỗi. Ưu tiên file bí mật (`/run/secrets`), và Vault hoặc dịch vụ bí mật của cloud cho production. Xem [Compose thực tế](#compose-patterns).
- Dùng secret mount của BuildKit cho bí mật lúc build ([Dockerfile tốt](#build-best)).

## Chuỗi cung ứng image

Chạy image là chạy code của người khác. Quét lỗ hổng (Trivy, Grype), sinh SBOM, ký image bằng cosign và xác minh khi triển khai, ghim digest, và dùng registry nội bộ làm nguồn duy nhất. Chi tiết và ví dụ ở trang [Bảo mật chuỗi cung ứng image](https://tracviethustcs.github.io/k8s-study-notes/#adv-supply-chain).

## Bảo vệ daemon và host

- Daemon lắng nghe qua Unix socket. **Không bao giờ** mở TCP `2375` không xác thực ra mạng: ai kết nối được đều chiếm được máy. Nếu bắt buộc phải truy cập từ xa, dùng TLS hai chiều (cổng `2376`) hoặc SSH (`DOCKER_HOST=ssh://user@host`).
- Group `docker` tương đương quyền root: cấp hạn chế.
- Cập nhật Docker, runc, và kernel: nhiều lỗ hổng thoát container nằm ở các thành phần này.
- Tham khảo **CIS Docker Benchmark**; công cụ `docker-bench-security` kiểm tra tự động nhiều mục.

::: lab So sánh mặc định và đã cứng hoá
```
docker run --rm alpine id                                   # uid=0(root)
docker run --rm alpine sh -c 'grep Cap /proc/self/status'   # capability mặc định
docker run --rm --user 10001:10001 --cap-drop=ALL --read-only alpine sh -c 'id; grep Cap /proc/self/status; touch /x'
docker run --rm --cap-drop=ALL alpine ping -c1 127.0.0.1    # ping cần CAP_NET_RAW: thất bại
docker run --rm --cap-drop=ALL --cap-add=NET_RAW alpine ping -c1 127.0.0.1
```
Trả lời: lệnh nào bị từ chối, và capability nào đã được trả lại để chạy được `ping`?
:::

=== daemon-logs | Vận hành | Daemon, log và dọn dẹp
>> Docker daemon cần cấu hình đúng để không đầy đĩa vì log, không khởi động lại làm sập container, và không xung đột mạng với văn phòng.

## daemon.json

Cấu hình daemon ở `/etc/docker/daemon.json` (Linux), cần `sudo systemctl restart docker` để áp dụng (hầu hết các mục).

```
{
  "log-driver": "json-file",
  "log-opts": {"max-size": "10m", "max-file": "3"},
  "live-restore": true,
  "registry-mirrors": ["https://mirror.example.com"],
  "default-address-pools": [{"base": "10.200.0.0/16", "size": 24}],
  "data-root": "/var/lib/docker"
}
```

| Khoá | Ý nghĩa |
|---|---|
| `log-opts` | **Bắt buộc nên đặt** với `json-file`: nếu không, log không bị xoay vòng và sẽ làm đầy đĩa |
| `live-restore` | Giữ container chạy khi daemon dừng hoặc khởi động lại (hữu ích khi nâng cấp Docker); có một số giới hạn khi nâng phiên bản lớn |
| `registry-mirrors` | Mirror cho Docker Hub: giảm tải và tránh giới hạn pull |
| `default-address-pools` | Dải IP cho mạng do Docker tạo, đổi nếu trùng với mạng nội bộ |
| `data-root` | Nơi lưu image, container, volume: đặt trên ổ đủ lớn |
| `storage-driver` | Mặc định `overlay2`, hiếm khi cần đổi |

```
sudo systemctl status docker
sudo journalctl -u docker -n 100 --no-pager
docker info                                 # storage driver, cgroup driver, runtime, root dir, mirror
```

## Log

Mỗi container có log là thứ ứng dụng ghi ra **stdout và stderr** (không phải file trong container). Docker thu và lưu theo **logging driver**:

| Driver | Ghi chú |
|---|---|
| `json-file` (mặc định) | Lưu file JSON trên host; **không xoay vòng nếu không đặt `max-size`**; `docker logs` đọc được |
| `local` | Định dạng gọn hơn, xoay vòng mặc định; `docker logs` đọc được |
| `journald` | Vào journal của systemd; `docker logs` đọc được |
| `syslog`, `fluentd`, `gelf`, `awslogs`, `splunk`... | Đẩy thẳng ra hệ thống ngoài; với một số driver `docker logs` không đọc được nữa |

Đặt theo từng container: `docker run --log-opt max-size=10m --log-opt max-file=3 ...`. Ứng dụng nên ghi log ra stdout/stderr, và dùng agent (Fluent Bit, Promtail, OTel) hoặc log driver để gom về nơi tập trung.

## Giám sát

```
docker stats                                 # CPU, RAM, mạng, I/O theo thời gian thực
docker events --filter event=die             # container nào vừa chết
docker ps --format '{{.Names}}: {{.Status}}' # có "(healthy)" hoặc "(unhealthy)" nếu có healthcheck
docker inspect -f '{{.State.Health.Status}}' web
```

Cho nhiều container: **cAdvisor** xuất metric từng container cho Prometheus; cảnh báo theo `container_memory_working_set_bytes`, số lần restart, và `oom_kill`.

## Dọn dẹp

```
docker system df                             # đang chiếm bao nhiêu
docker container prune                       # container đã dừng
docker image prune                           # image dangling; thêm -a để xoá mọi image không dùng
docker builder prune                         # cache build
docker volume prune                          # volume không có container nào dùng
docker system prune                          # gộp nhiều thứ ở trên (không gồm volume)
docker system prune -a --volumes             # rất mạnh: xoá cả volume không dùng
```

::: warn prune --volumes xoá dữ liệu
`docker volume prune` và `docker system prune --volumes` xoá **volume không có container nào đang dùng**: một volume của container đã dừng cũng bị tính là "không dùng" và mất dữ liệu. Kiểm tra bằng `docker volume ls` trước, và đặt lịch dọn image/cache (không phải volume) cho máy CI.
:::

::: lab Chặn log làm đầy đĩa
```
docker run -d --name noisy --log-opt max-size=1m --log-opt max-file=2 alpine sh -c 'while true; do echo "dòng log $(date)"; done'
sleep 5; docker inspect -f '{{.LogPath}}' noisy
sudo ls -lh "$(docker inspect -f '{{.LogPath}}' noisy)"*
docker rm -f noisy
docker info --format '{{.LoggingDriver}} {{.DockerRootDir}} {{.CgroupDriver}}'
```
Quan sát: kích thước file log dừng ở khoảng bao nhiêu, và có bao nhiêu file? Điều gì xảy ra nếu bỏ `--log-opt`?
:::

=== troubleshooting | Vận hành | Xử lý sự cố
>> Các sự cố Docker hay gặp, theo khung: triệu chứng, cách kiểm tra theo thứ tự, nguyên nhân, cách sửa. Hầu hết đều được trả lời bởi `docker logs`, `docker inspect` và hiểu biết về Linux bên dưới.

## Quy trình chung

1. `docker ps -a`: container ở trạng thái nào, thoát khi nào, mã thoát?
2. `docker logs --tail 100 NAME`: ứng dụng nói gì trước khi chết?
3. `docker inspect NAME`: `State` (ExitCode, OOMKilled, Error), cấu hình thật (Env, Mounts, Networks).
4. Tái hiện bằng tay: `docker run --rm -it --entrypoint sh IMAGE`.
5. Nếu liên quan tới Linux bên dưới: `docker events`, `dmesg`, `ss`, `nsenter`.

## Kịch bản 1: Container thoát ngay sau khi chạy

```
docker ps -a --filter name=app
docker logs app
docker inspect -f '{{.State.ExitCode}} {{.State.OOMKilled}} {{.State.Error}}' app
docker run --rm -it --entrypoint sh IMAGE
```

| Mã thoát và dấu hiệu | Nguyên nhân thường gặp |
|---|---|
| 0 | Tiến trình kết thúc bình thường: container chạy xong việc là dừng. Ứng dụng phải chạy ở **foreground** (đừng để chương trình tự daemonize) |
| 1 hoặc mã khác | Lỗi ứng dụng: thiếu biến môi trường, cấu hình, không kết nối được dịch vụ phụ thuộc |
| 126, 127 | Lệnh không thực thi được hoặc không tìm thấy: sai đường dẫn, thiếu quyền `x`, sai shebang, thiếu thư viện (ví dụ file nhị phân glibc trên alpine/musl) |
| 137 và `OOMKilled=true` | Vượt giới hạn bộ nhớ ([Tài nguyên](#resources)) |
| `exec format error` | Image sai kiến trúc CPU (arm64 và amd64) |

## Kịch bản 2: Cổng đã publish nhưng không truy cập được

```
docker port web
docker exec web ss -tlnp                      # (nếu image có ss) ứng dụng nghe trên địa chỉ nào?
sudo iptables -t nat -L DOCKER -n
curl -v http://127.0.0.1:8080
```

- Ứng dụng nghe `127.0.0.1` **bên trong** container thì luồng publish không tới được: phải nghe `0.0.0.0`.
- Sai thứ tự `host:container` trong `-p`.
- Firewall của host hoặc security group của cloud chặn; hoặc `-p 127.0.0.1:...` nên máy khác không vào được.
- Đang kiểm tra từ container khác nhưng dùng cổng host thay vì cổng container (trong cùng mạng Docker gọi thẳng `tên:cổng-container`).

## Kịch bản 3: Container không gọi được container khác bằng tên

```
docker network inspect appnet
docker exec app cat /etc/resolv.conf          # nameserver 127.0.0.11?
docker exec app getent hosts db
```

Thường do ở **bridge mặc định** (không có DNS theo tên) hoặc **khác mạng**; sửa bằng cách tạo mạng riêng và nối cả hai ([Mạng](#networking)). Trong Compose, hai dịch vụ chỉ thấy nhau nếu cùng một mạng.

## Kịch bản 4: Permission denied trên volume hoặc bind mount

```
docker exec app id
docker exec app ls -ln /data
ls -ln ./data                                  # UID/GID trên host
```

UID của ứng dụng trong container không có quyền trên thư mục. Sửa: `chown` thư mục cho đúng UID, chạy `--user` khớp, dùng volume có tên; trên RHEL/Fedora thêm `:z`/`:Z` cho SELinux ([Volume](#volumes)). Nếu thư mục bind mount chưa tồn tại và dùng `-v`, Docker tạo nó thuộc root.

## Kịch bản 5: no space left on device

```
docker system df
sudo du -xh --max-depth=1 /var/lib/docker | sort -h | tail
sudo ls -lh $(docker inspect -f '{{.LogPath}}' NAME)
df -h; df -i
```

Thủ phạm thường gặp: log `json-file` không xoay vòng, image và layer cũ, cache build, volume ẩn danh, container đã dừng. Dọn bằng `docker system prune` (xem cảnh báo về volume ở [Daemon và log](#daemon-logs)), và đặt `max-size` cho log. Kiểm tra cả `df -i` (hết inode).

## Kịch bản 6: Lỗi kéo image

| Thông báo | Nguyên nhân |
|---|---|
| `unauthorized` / `denied` | Chưa `docker login`, hoặc không có quyền với repo, hoặc sai tên repo |
| `manifest unknown` / `not found` | Sai tag hoặc tên image |
| `toomanyrequests` | Chạm giới hạn pull của Docker Hub: đăng nhập, dùng mirror, hoặc registry khác |
| `x509: certificate signed by unknown authority` | Registry dùng CA nội bộ: cài CA vào máy (`/etc/docker/certs.d/REGISTRY/ca.crt`) |
| `no matching manifest for linux/arm64` | Image không có bản cho nền tảng của máy: dùng `--platform` hoặc image đa kiến trúc |
| Treo hoặc rất chậm | Mạng, DNS, hoặc proxy: kiểm tra `docker info` mục Proxy, và cấu hình proxy của daemon |

## Kịch bản 7: Cannot connect to the Docker daemon

```
systemctl status docker
ls -l /var/run/docker.sock
echo $DOCKER_HOST
id                                              # có trong group docker?
```

Daemon chưa chạy, người dùng không có quyền với socket (thêm vào group `docker`, đăng nhập lại), hoặc `DOCKER_HOST` đang trỏ nhầm. Trên Docker Desktop, ứng dụng chưa khởi động xong.

## Công cụ debug thêm

```
# Dùng công cụ mạng mà không cần cài vào image
docker run --rm -it --network container:web --pid container:web nicolaka/netshoot
sudo nsenter -t "$(docker inspect -f '{{.State.Pid}}' web)" -n -m ss -tlnp
docker run --rm -it --entrypoint sh IMAGE
docker diff web
docker events --since 30m
```

Vì nhiều image tối giản (distroless) không có shell, hãy gắn một container debug dùng chung namespace mạng và PID của container cần xem, thay vì sửa image.

::: lab Chẩn đoán ba lỗi cài sẵn
```
docker run --name bug1 -d alpine sh -c 'echo "thiếu cấu hình" >&2; exit 1'
docker run --name bug2 -d -p 8082:80 python:3.12-alpine python -m http.server 80 --bind 127.0.0.1
docker run --name bug3 -d --user 10001 -v "$PWD/lab-data":/data alpine sh -c 'echo x > /data/f'
sleep 2; docker ps -a --format '{{.Names}} {{.Status}}'
docker logs bug1; curl -s -m 3 localhost:8082 || echo "bug2: không truy cập được"
ls -ld lab-data; docker logs bug3
docker rm -f bug1 bug2 bug3; sudo rm -rf lab-data
```
Với mỗi lỗi: triệu chứng là gì, nguyên nhân nào (đối chiếu các kịch bản trên), và cách sửa?
:::

=== ecosystem | Vận hành | Hệ sinh thái: Podman, containerd và Kubernetes
>> Docker không phải là cách duy nhất để chạy container. Biết bản đồ các thành phần giúp bạn đọc tài liệu Kubernetes, chọn công cụ phù hợp và không bị bất ngờ khi môi trường khác Docker.

## Các thành phần theo tầng

| Tầng | Vai trò | Ví dụ |
|---|---|---|
| Công cụ cho người dùng | Build, chạy, quản lý image và container | Docker CLI, Podman, nerdctl |
| Engine quản lý container | Vòng đời container, image, lưu trữ | dockerd, containerd, CRI-O, Podman |
| Runtime mức thấp (OCI) | Tạo container thật bằng namespace, cgroup | runc, crun |
| Runtime cô lập mạnh | Cô lập hơn bằng kernel userspace hoặc microVM | gVisor, Kata Containers, Firecracker (xem [Ảo hoá](https://tracviethustcs.github.io/linux-network-notes/#os-virt)) |
| Công cụ build | Build image không cần daemon | BuildKit, Buildah, Kaniko |

## Docker và Podman

| | Docker | Podman |
|---|---|---|
| Kiến trúc | Daemon chạy nền (thường root), CLI gọi API | **Không daemon**: mỗi lệnh là một tiến trình riêng |
| Rootless | Có, là chế độ tuỳ chọn | Mặc định và là điểm mạnh |
| Khái niệm Pod | Không | Có Pod giống Kubernetes (`podman pod`, `podman generate kube`) |
| Tích hợp systemd | Qua unit tự viết | Quadlet và `podman generate systemd` |
| CLI | `docker ...` | Gần như tương thích: `alias docker=podman` chạy được phần lớn lệnh |
| Compose | `docker compose` | `podman compose` hoặc `podman-compose` |

Cả hai dùng chung chuẩn OCI nên image có thể trao đổi. Chọn Podman nếu cần rootless và không muốn một daemon quyền cao; chọn Docker nếu bạn cần hệ sinh thái công cụ và tài liệu rộng nhất.

## Docker và Kubernetes

- Kubernetes không nói chuyện với Docker mà nói với một runtime qua **CRI** (Container Runtime Interface). Các runtime phổ biến là **containerd** và **CRI-O**. Từ Kubernetes 1.24, `dockershim` (lớp tích hợp trực tiếp Docker) đã bị gỡ.
- Điều này **không** làm image build bằng Docker ngừng chạy: image tuân thủ OCI nên chạy tốt trên mọi runtime.
- Điểm khác trong vận hành: trên node Kubernetes không còn lệnh `docker`; dùng `crictl` (hoặc `nerdctl`) để xem container trên node.

| Docker | Tương đương trên node Kubernetes |
|---|---|
| `docker ps` | `crictl ps` |
| `docker logs` | `crictl logs` hoặc `kubectl logs` |
| `docker exec` | `crictl exec` hoặc `kubectl exec` |
| `docker images` | `crictl images` |

Kiến thức về image, layer, mạng bridge, volume, giới hạn tài nguyên và bảo mật trong ghi chú này áp dụng trực tiếp ở Kubernetes: xem [Pod](https://tracviethustcs.github.io/k8s-study-notes/#pods), [Tài nguyên](https://tracviethustcs.github.io/k8s-study-notes/#ops-resources) và [Probe, tắt êm](https://tracviethustcs.github.io/k8s-study-notes/#ops-probes).

## Công cụ phát triển

- **Docker Desktop**: tiện (GUI, Kubernetes tích hợp, WSL2) nhưng có điều khoản cấp phép cho tổ chức lớn: hãy kiểm tra.
- Lựa chọn thay thế trên máy cá nhân: **Podman Desktop**, **Rancher Desktop**, **Colima** (macOS/Linux), hoặc cài Engine trong WSL2/VM.
- Cụm Kubernetes cục bộ: `kind`, `k3d`, `minikube`.

## Đi tiếp

Sau Docker: chạy trên nhiều máy với [Kubernetes](https://tracviethustcs.github.io/k8s-study-notes/), mô tả hạ tầng bằng mã ([IaC: Terraform và Ansible](https://tracviethustcs.github.io/iac-terraform-ansible-notes/)), và tự động hoá build và phát hành ([CI/CD](https://tracviethustcs.github.io/cicd-release-notes/)).

=== cli-ref | Tham chiếu | Cheat sheet lệnh và Dockerfile
>> Tra nhanh theo câu hỏi "tôi muốn làm gì". Mỗi lệnh đều có giải thích ở trang tương ứng.

## Image

| Muốn | Lệnh |
|---|---|
| Tải, liệt kê | `docker pull IMG`, `docker image ls --digests` |
| Xem layer, cấu hình | `docker history IMG`, `docker image inspect IMG` |
| Build | `docker build -t NAME:TAG .`, thêm `-f FILE`, `--target STAGE`, `--build-arg K=V`, `--progress=plain` |
| Build đa nền tảng | `docker buildx build --platform linux/amd64,linux/arm64 -t REG/NAME:TAG --push .` |
| Gắn tag, đẩy | `docker tag SRC DST`, `docker push DST` |
| Xuất, nhập | `docker save -o f.tar IMG`, `docker load -i f.tar` |
| Xoá | `docker rmi IMG`, `docker image prune`, `docker image prune -a` |

## Container

| Muốn | Lệnh |
|---|---|
| Chạy | `docker run -d --name N -p H:C -e K=V -v VOL:/path --restart unless-stopped IMG` |
| Chạy một lần | `docker run --rm -it IMG sh` |
| Danh sách | `docker ps`, `docker ps -a`, `docker ps -a --filter status=exited` |
| Dừng, chạy lại, xoá | `docker stop N`, `docker start N`, `docker restart N`, `docker rm -f N` |
| Vào trong | `docker exec -it N sh` |
| Log | `docker logs -f --tail 100 --since 10m N` |
| Chi tiết | `docker inspect -f '{{.State.ExitCode}} {{.State.OOMKilled}}' N` |
| Process, tài nguyên | `docker top N`, `docker stats --no-stream` |
| Chép file | `docker cp N:/path ./`, `docker cp ./f N:/path` |
| Thay đổi trong lớp ghi | `docker diff N` |
| Sự kiện | `docker events --since 30m` |

## Mạng, volume, dọn dẹp

| Muốn | Lệnh |
|---|---|
| Mạng | `docker network create NET`, `docker network ls`, `docker network inspect NET`, `docker network connect NET N` |
| Cổng đã publish | `docker port N` |
| Volume | `docker volume create V`, `docker volume ls`, `docker volume inspect V`, `docker volume rm V` |
| Dung lượng | `docker system df -v` |
| Dọn | `docker system prune`, `docker builder prune`, `docker volume prune` |

## Compose

| Muốn | Lệnh |
|---|---|
| Chạy, build lại | `docker compose up -d`, `docker compose up -d --build` |
| Trạng thái, log | `docker compose ps`, `docker compose logs -f SVC` |
| Vào, chạy một lần | `docker compose exec SVC sh`, `docker compose run --rm SVC CMD` |
| Dừng, xoá | `docker compose stop`, `docker compose down`, `docker compose down -v` |
| Kiểm tra cấu hình | `docker compose config` |
| Nhiều file | `docker compose -f a.yaml -f b.yaml up -d` |

## Dockerfile mẫu cho dịch vụ web

```
# syntax=docker/dockerfile:1
FROM python:3.12-slim AS base
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app

FROM base AS deps
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt

FROM base AS runtime
COPY --from=deps /usr/local /usr/local
COPY . .
RUN useradd -r -u 10001 app && chown -R app /app
USER 10001
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"
CMD ["python", "-m", "app"]
```

## Chuỗi định dạng hay dùng với `--format`

| Muốn lấy | Chuỗi |
|---|---|
| IP của container | `{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}` |
| PID trên host | `{{.State.Pid}}` |
| Trạng thái và mã thoát | `{{.State.Status}} {{.State.ExitCode}}` |
| Đường dẫn file log | `{{.LogPath}}` |
| Danh sách mount | `{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}` |

=== quiz-1 | Luyện tập | Luyện tập 1: Image, Dockerfile và registry
>> 6 câu về layer, cache, multi-stage, tag và digest. Chọn đáp án rồi bấm "Kiểm tra" để xem giải thích. Kết quả được lưu trong trình duyệt.

## Câu hỏi

@quiz
Q: Bạn thêm `RUN rm -rf /var/cache/*` ở một lệnh riêng sau lệnh `RUN apt-get install ...` nhưng kích thước image không giảm. Vì sao?
- Docker bỏ qua lệnh `rm` trong Dockerfile
+ Mỗi `RUN` tạo một layer chỉ đọc; xoá file ở layer sau không làm layer trước nhỏ đi, nên dữ liệu vẫn nằm trong image
- Lệnh `rm` cần quyền root mà build không có
- Cache build giữ lại các file đã xoá
E: Layer là bản diff chỉ ghi thêm. Muốn thực sự loại bỏ, phải dọn trong **cùng một `RUN`** với lệnh tạo ra rác (`apt-get install ... && rm -rf /var/lib/apt/lists/*`), hoặc dùng multi-stage để chỉ chép kết quả cần thiết sang giai đoạn cuối.
Q: Mỗi lần sửa một dòng mã nguồn, bước `pip install` lại chạy từ đầu và build rất chậm. Dockerfile có `COPY . .` rồi mới `RUN pip install -r requirements.txt`. Cách sửa hợp lý nhất?
- Thêm `--no-cache` vào `docker build`
+ Chép `requirements.txt` và chạy `pip install` trước, sau đó mới `COPY . .`, để layer cài thư viện chỉ bị vô hiệu khi `requirements.txt` đổi
- Dùng `ADD` thay cho `COPY`
- Đổi image nền sang alpine
E: Một layer bị vô hiệu thì mọi layer sau nó phải build lại. `COPY . .` đặt trước làm layer cài thư viện thay đổi mỗi khi bất kỳ file nào đổi. Đặt thứ ít đổi (manifest phụ thuộc) lên trên, mã nguồn hay đổi xuống dưới.
Q: Một image Go build bằng `FROM golang:1.23` có kích thước hơn 800 MB. Cách nào giảm mạnh kích thước và bề mặt tấn công?
- Thêm `RUN apt-get clean` ở cuối
+ Dùng multi-stage: build ở giai đoạn có compiler, rồi chép file nhị phân sang giai đoạn runtime nhỏ (distroless hoặc `scratch`)
- Nén image bằng `docker save | gzip`
- Đổi `CMD` sang dạng shell
E: Compiler và toàn bộ công cụ build không cần lúc chạy. Multi-stage chỉ giữ lại sản phẩm cuối. Nén khi `save` chỉ ảnh hưởng tệp xuất ra, không đổi image thật.
Q: Chọn TẤT CẢ phát biểu đúng về tag và digest.
+ Một tag như `latest` hoặc `1.4` có thể được đổi để trỏ sang image khác
+ Digest `sha256:...` là mã băm của manifest và bất biến, nên đảm bảo chạy đúng image đã thử
- `latest` luôn là phiên bản mới nhất được phát hành
+ Triển khai bằng digest giúp tránh việc image bị đổi ngầm
E: `latest` chỉ là một tag tên như vậy, không bảo đảm gì về độ mới, và tag nào cũng có thể bị đổi. Digest được tính từ nội dung nên không thể đổi mà không đổi mã băm. Quy tắc: build một lần, gắn tag theo git SHA/semver, triển khai bằng digest.
Q: Bạn truyền token tải thư viện riêng bằng `ARG NPM_TOKEN` rồi `RUN npm ci`. Vì sao đây là cách không an toàn, và cách đúng là gì?
- An toàn, vì `ARG` chỉ tồn tại lúc build
+ Giá trị `ARG` lộ trong `docker history` và metadata của image; dùng secret mount của BuildKit (`RUN --mount=type=secret,id=...`) để không lưu vào layer
- Không an toàn vì `ARG` bị ghi vào registry dưới dạng văn bản rõ ràng trong tên tag
- An toàn nếu xoá biến ở cuối Dockerfile bằng `ENV NPM_TOKEN=`
E: `ARG` không phải nơi chứa bí mật: giá trị còn hiện trong lịch sử build. Xoá ở lệnh sau không xoá khỏi layer cũ. `RUN --mount=type=secret` cung cấp bí mật dưới dạng file tạm chỉ trong lúc lệnh chạy và không đưa vào image.
Q: `docker stop` một container chạy `CMD python app.py` (shell form) luôn mất đúng 10 giây rồi mới dừng. Nguyên nhân hợp lý nhất?
- Docker luôn chờ 10 giây dù ứng dụng thoát nhanh
+ PID 1 là `sh`, không chuyển tiếp `SIGTERM` tới ứng dụng, nên sau 10 giây Docker gửi `SIGKILL`; dùng exec form `CMD ["python","app.py"]` hoặc `--init`
- Ứng dụng đang ở trạng thái zombie
- Cổng của container chưa được đóng
E: Shell form chạy `/bin/sh -c "..."`, và PID 1 không có hành vi signal mặc định nên `SIGTERM` bị bỏ qua. Exec form làm ứng dụng trở thành PID 1 nhận signal trực tiếp (ứng dụng cần có handler); `--init` dùng tini để chuyển tiếp signal.

=== quiz-2 | Luyện tập | Luyện tập 2: Runtime, mạng, bảo mật và sự cố
>> 6 câu tình huống về chạy container, mạng, volume, bảo mật và xử lý sự cố.

## Câu hỏi

@quiz
Q: Container `api` thoát với mã 137 sau vài giờ chạy, `docker inspect` cho `OOMKilled=true`, máy chủ còn nhiều RAM trống. Giải thích đúng nhất?
- Máy chủ hết RAM nên kernel giết container
+ Container vượt giới hạn bộ nhớ của cgroup (`-m`), nên kernel OOM kill process trong cgroup đó bằng SIGKILL (128 + 9)
- Ứng dụng tự gọi `exit(137)`
- Docker daemon bị crash
E: 137 = 128 + 9 (SIGKILL). `OOMKilled=true` cho biết là OOM do giới hạn của cgroup, không phải máy hết RAM. Hướng xử lý: tìm rò rỉ hoặc tăng giới hạn hợp lý; với JVM đặt heap thấp hơn giới hạn container.
Q: Hai container chạy bằng `docker run` thường (không chỉ định mạng) không gọi nhau được bằng tên, nhưng gọi bằng IP thì được. Cách khắc phục đúng?
- Thêm `-p` cho cả hai container
+ Tạo một mạng bridge do người dùng định nghĩa (`docker network create`) và nối cả hai vào, vì bridge mặc định không có phân giải tên
- Dùng `EXPOSE` trong Dockerfile
- Tắt firewall của host
E: Chỉ mạng bridge do người dùng tạo mới có DNS nhúng (127.0.0.11) phân giải tên container. Bridge mặc định chỉ dùng IP. `-p` và `EXPOSE` không liên quan tới việc container gọi container.
Q: Bạn chạy `docker run -p 5432:5432 postgres` trên máy đã bật `ufw` chặn mọi kết nối vào, nhưng từ máy khác vẫn kết nối được database. Vì sao, và cách đúng?
- ufw bị lỗi và cần cài lại
+ Docker tự chèn luật iptables riêng cho cổng được publish nên bỏ qua ufw; chỉ bind `127.0.0.1:5432:5432`, hoặc không publish và dùng mạng Docker, hoặc đặt luật ở chain `DOCKER-USER`
- `-p` chỉ mở cổng trong mạng nội bộ của Docker
- Postgres tự mở cổng bất kể cấu hình
E: Luật DNAT của Docker được xử lý trước các chain mà ufw quản lý. `-p HOST:CONTAINER` không chỉ định địa chỉ nghĩa là mở ra mọi giao diện. Với dịch vụ chỉ dùng nội bộ, không publish hoặc bind vào loopback.
Q: Chọn TẤT CẢ biện pháp làm giảm tác hại nếu một container bị xâm nhập.
+ Chạy bằng user non-root và bỏ capability không cần (`--cap-drop=ALL`)
+ Dùng filesystem chỉ đọc (`--read-only`) kèm `--tmpfs` cho thư mục cần ghi
- Mount `/var/run/docker.sock` để container tự quản lý container khác
+ Đặt `no-new-privileges` và giữ profile seccomp mặc định
E: Mount `docker.sock` cho container quyền điều khiển daemon, gần như bằng root trên host, nên làm tăng rủi ro thay vì giảm. Ba biện pháp còn lại thu hẹp những gì process bị xâm nhập làm được.
Q: Sau một thời gian, ổ đĩa của máy chạy Docker đầy 100%. `docker system df` cho thấy image và volume nhỏ, nhưng `/var/lib/docker/containers` rất lớn. Nguyên nhân khả dĩ nhất và cách xử lý?
- Cache build quá lớn; chạy `docker builder prune`
+ File log `json-file` của các container không được xoay vòng; đặt `log-opts` `max-size` và `max-file` trong `daemon.json` (hoặc cho từng container) rồi tạo lại container
- Volume ẩn danh; chạy `docker volume prune`
- Image dangling; chạy `docker image prune`
E: Log mặc định của `json-file` nằm trong thư mục của từng container và không bị giới hạn nếu không đặt `max-size`. Cách khắc phục là cấu hình xoay vòng log (hoặc đổi driver) và tạo lại container, vì cấu hình log áp dụng lúc tạo container.
Q: Một container đang chạy từ image distroless không có shell, bạn cần kiểm tra kết nối mạng từ bên trong nó. Cách phù hợp nhất?
- Sửa Dockerfile thêm shell rồi triển khai lại
+ Chạy một container debug dùng chung namespace mạng và PID của nó, ví dụ `docker run --rm -it --network container:NAME --pid container:NAME nicolaka/netshoot`
- Dùng `docker exec -it NAME sh`
- Dừng container rồi chạy lại bằng `--privileged`
E: Image không có shell nên `docker exec ... sh` thất bại. Container debug gắn vào namespace của container mục tiêu, nên `ss`, `curl`, `tcpdump` thấy đúng mạng của nó mà không sửa image hay tăng quyền.
