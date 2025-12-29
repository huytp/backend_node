# WireGuard Installation Guide for Backend

Backend cần WireGuard tools để generate key pairs cho client connections. File này hướng dẫn cài đặt WireGuard trên các hệ điều hành khác nhau.

## Yêu cầu

Backend cần có `wg` command để generate WireGuard keys. Chỉ cần **wireguard-tools**, không cần cài đặt full WireGuard server.

## Cài đặt theo hệ điều hành

### Ubuntu / Debian

```bash
sudo apt-get update
sudo apt-get install -y wireguard-tools
```

### macOS

```bash
brew install wireguard-tools
```

### CentOS / RHEL / Fedora

```bash
# CentOS/RHEL 8+
sudo dnf install -y wireguard-tools

# CentOS/RHEL 7
sudo yum install -y epel-release
sudo yum install -y wireguard-tools

# Fedora
sudo dnf install -y wireguard-tools
```

### Alpine Linux (Docker)

Nếu backend chạy trong Docker container với Alpine Linux:

```dockerfile
RUN apk add --no-cache wireguard-tools
```

## Kiểm tra cài đặt

Sau khi cài đặt, kiểm tra xem `wg` command có sẵn không:

```bash
wg --version
```

Hoặc test generate key:

```bash
wg genkey
```

Nếu command chạy thành công và trả về một base64 string, WireGuard đã được cài đặt đúng.

## Docker Setup

Nếu backend chạy trong Docker, thêm vào Dockerfile:

```dockerfile
# For Ubuntu/Debian based images
RUN apt-get update && \
    apt-get install -y wireguard-tools && \
    rm -rf /var/lib/apt/lists/*

# For Alpine based images
RUN apk add --no-cache wireguard-tools
```

## Troubleshooting

### Lỗi: "No such file or directory - wg"

- Đảm bảo WireGuard tools đã được cài đặt
- Kiểm tra PATH: `which wg`
- Nếu dùng Docker, đảm bảo WireGuard tools được cài trong container

### Lỗi: Permission denied

- `wg` command không cần sudo để generate keys
- Nếu gặp permission issues, kiểm tra file permissions

## Lưu ý

- Chỉ cần **wireguard-tools**, không cần cài đặt full WireGuard server
- Backend chỉ dùng `wg genkey` và `wg pubkey` commands
- Không cần cấu hình WireGuard interface trên backend server

