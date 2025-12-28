# Hướng Dẫn Cấu Hình Node API

## Vấn Đề

Backend không thể kết nối đến Node API qua public IP `183.80.151.69:51820` vì:
1. Port forwarding chưa được cấu hình trên router
2. Firewall có thể chặn kết nối
3. Node API có thể chạy trên port khác với WireGuard

## Giải Pháp

### 1. Cấu Hình Port Forwarding trên Router

Node API cần được expose ra ngoài internet qua port forwarding:

#### Bước 1: Xác định Internal IP của Node
```bash
# Trên máy chạy node
ip addr show | grep "inet " | grep -v 127.0.0.1
# Hoặc
hostname -I
```

Ví dụ: `192.168.1.100`

#### Bước 2: Cấu Hình Port Forwarding

Đăng nhập vào router (thường là `192.168.1.1` hoặc `192.168.0.1`):

1. Tìm mục **Port Forwarding** hoặc **Virtual Server**
2. Thêm rule mới:
   - **External Port**: `51820` (hoặc port khác nếu muốn)
   - **Internal IP**: IP của node (ví dụ: `192.168.1.100`)
   - **Internal Port**: `51820`
   - **Protocol**: TCP
   - **Name**: VPN Node API

3. Lưu cấu hình

#### Bước 3: Kiểm Tra Port Forwarding

Từ máy khác (không cùng mạng):
```bash
# Test kết nối
curl http://183.80.151.69:51820/api/health

# Hoặc
telnet 183.80.151.69 51820
```

### 2. Cấu Hình Firewall

#### Trên Node (Ubuntu/Debian)

```bash
# Cho phép port 51820 qua firewall
sudo ufw allow 51820/tcp
sudo ufw reload

# Hoặc nếu dùng iptables
sudo iptables -A INPUT -p tcp --dport 51820 -j ACCEPT
sudo iptables-save
```

#### Kiểm Tra Firewall

```bash
# Kiểm tra UFW status
sudo ufw status

# Kiểm tra iptables
sudo iptables -L -n | grep 51820
```

### 3. Cấu Hình Node API Port

Node API mặc định chạy trên port `51820` (cùng với WireGuard). Nếu muốn dùng port khác:

#### Trên Node

Thêm vào `.env` hoặc environment:
```bash
NODE_API_PORT=8080  # Port khác với WireGuard
```

#### Trên Backend

Cấu hình port mặc định:
```bash
NODE_API_PORT=8080
```

Hoặc trong `docker-compose.yml`:
```yaml
environment:
  - NODE_API_PORT=8080
```

### 4. Cấu Hình Node Public IP

Node tự động detect public IP, nhưng có thể cấu hình thủ công:

#### Trên Node

Thêm vào `.env`:
```bash
NODE_PUBLIC_IP=183.80.151.69
NODE_API_PORT=51820
```

Node sẽ gửi `node_api_url` trong heartbeat:
```
http://183.80.151.69:51820
```

### 5. Kiểm Tra Node API

#### Trên Node

```bash
# Kiểm tra API server có chạy không
curl http://localhost:51820/api/health

# Hoặc từ máy khác trong mạng
curl http://192.168.1.100:51820/api/health
```

#### Từ Backend

```bash
# Test từ backend container
docker exec backend-web-1 curl http://183.80.151.69:51820/api/health
```

### 6. Sử Dụng Internal IP (Nếu Backend và Node Cùng Mạng)

Nếu backend và node cùng mạng local, có thể dùng internal IP:

#### Cập Nhật Node trong Database

```ruby
# Rails console
node = Node.find_by(address: '0x...')
node.update!(
  node_api_url: 'http://192.168.1.100:51820'  # Internal IP
)
```

### 7. Troubleshooting

#### Kiểm Tra Node API Có Chạy Không

```bash
# Trên node
netstat -tlnp | grep 51820
# Hoặc
ss -tlnp | grep 51820

# Kiểm tra process
ps aux | grep node-agent
```

#### Kiểm Tra Kết Nối Từ Bên Ngoài

```bash
# Từ máy khác (không cùng mạng)
curl -v http://183.80.151.69:51820/api/health

# Nếu timeout, có thể:
# 1. Port forwarding chưa đúng
# 2. Firewall đang chặn
# 3. ISP đang block port
```

#### Kiểm Tra Logs

```bash
# Node logs
docker logs vpn-node-1

# Backend logs
docker logs backend-web-1 | grep "WireGuard"
```

#### Test Port Forwarding

Sử dụng tool online:
- https://www.yougetsignal.com/tools/open-ports/
- Nhập IP: `183.80.151.69`
- Nhập Port: `51820`

### 8. Cấu Hình Nâng Cao

#### Sử Dụng Port Khác Cho API

Nếu muốn tách API port khỏi WireGuard port:

1. **Trên Node**: Set `NODE_API_PORT=8080`
2. **Trên Router**: Forward port `8080` → `192.168.1.100:8080`
3. **Trên Backend**: Set `NODE_API_PORT=8080`

#### Sử Dụng Reverse Proxy (Nginx)

Nếu muốn dùng domain name thay vì IP:

```nginx
server {
    listen 80;
    server_name node-api.yourdomain.com;

    location / {
        proxy_pass http://localhost:51820;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Sau đó cấu hình node_api_url:
```ruby
node.update!(node_api_url: 'http://node-api.yourdomain.com')
```

## Checklist

- [ ] Port forwarding đã được cấu hình trên router
- [ ] Firewall đã mở port 51820 (hoặc port API khác)
- [ ] Node API đang chạy và listen trên port đúng
- [ ] Có thể kết nối từ bên ngoài: `curl http://183.80.151.69:51820/api/health`
- [ ] Node gửi `node_api_url` trong heartbeat
- [ ] Backend lưu `node_api_url` vào database
- [ ] Backend có thể kết nối đến node API

## Lưu Ý

1. **Bảo Mật**: Node API không có authentication. Nên thêm firewall rules để chỉ cho phép backend IP.

2. **ISP Blocking**: Một số ISP block port 51820. Có thể cần dùng port khác (như 8080, 8443).

3. **Dynamic IP**: Nếu public IP thay đổi, cần cập nhật `NODE_PUBLIC_IP` hoặc dùng dynamic DNS.

4. **NAT Traversal**: Nếu node ở sau nhiều lớp NAT, có thể cần cấu hình UPnP hoặc STUN.


