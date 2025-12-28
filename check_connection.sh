#!/bin/bash

# Script to check if backend is accessible from network

BACKEND_URL="${1:-http://192.168.2.108:3000}"

echo "Checking backend connection..."
echo "URL: $BACKEND_URL"
echo ""

# Check if backend is running
echo "1. Testing health endpoint..."
if curl -s -f -m 5 "$BACKEND_URL/health" > /dev/null; then
    echo "✅ Backend is accessible!"
    curl -s "$BACKEND_URL/health" | jq . || curl -s "$BACKEND_URL/health"
else
    echo "❌ Cannot connect to backend"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check if backend is running:"
    echo "   cd backend && rails server"
    echo ""
    echo "2. Check if backend is bound to 0.0.0.0 (not just localhost)"
    echo "   Check config/puma.rb has: bind 'tcp://0.0.0.0:3000'"
    echo ""
    echo "3. Check firewall:"
    echo "   sudo ufw status"
    echo "   sudo ufw allow 3000/tcp"
    echo ""
    echo "4. If running in Docker:"
    echo "   docker ps"
    echo "   docker logs backend-web-1"
    echo ""
    echo "5. Test from localhost first:"
    echo "   curl http://localhost:3000/health"
fi

echo ""
echo "2. Testing from network interface..."
LOCAL_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' || ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
if [ -n "$LOCAL_IP" ]; then
    echo "Your local IP: $LOCAL_IP"
    echo "Try accessing from mobile: http://$LOCAL_IP:3000"
else
    echo "Could not detect local IP"
fi


