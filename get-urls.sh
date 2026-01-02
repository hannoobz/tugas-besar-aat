#!/bin/bash

echo "======================================"
echo "  Access URLs for Laporan System"
echo "======================================"
echo ""

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

if [ -z "$MINIKUBE_IP" ]; then
    echo "❌ Error: Could not get Minikube IP"
    echo "Make sure Minikube is running: minikube status"
    exit 1
fi

echo "✅ Minikube IP: $MINIKUBE_IP"
echo ""
echo "📱 Access your applications:"
echo "-----------------------------------"
echo "👤 User Interface:  http://$MINIKUBE_IP:30080"
echo "🔧 Admin Interface: http://$MINIKUBE_IP:30081"
echo ""
echo "� Backend APIs (for testing):"
echo "-----------------------------------"
echo "📝 Create Report API: http://$MINIKUBE_IP:30082"
echo "📊 Admin API:         http://$MINIKUBE_IP:30083"
echo ""
echo "�💡 Or use minikube service commands:"
echo "-----------------------------------"
echo "minikube service client-user --url"
echo "minikube service client-admin --url"
echo ""
