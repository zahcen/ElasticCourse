set -e

echo "=== Add Elastic Helm repository ==="
helm repo add elastic https://helm.elastic.co

echo "===  Add OpenTelemetry Helm repository ==="
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts

echo "=== Update repositories ==="
helm repo update

NAMESPACE="elastic-system"
RELEASE_NAME="kibana"
CHART_VERSION="9.1.2"


kubectl create namespace $NAMESPACE
kubectl create namespace opentelemetry-system
kubectl create namespace kibana

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.18.2 --set crds.enabled=true
kubectl -n cert-manager apply -f ca-issuer.yaml

kubectl -n $NAMESPACE apply -f elasticsearch-tls.yaml 

kubectl create secret generic kibana-credentials --namespace $NAMESPACE \
--from-literal=password=$(openssl rand -base64 32) \
--from-literal=encryption-key=$(openssl rand -base64 32) 

k apply -f elasticsearch-master-certs.yaml

echo "=== Install Elasticsearch ==="
helm install elasticsearch elastic/elasticsearch -f elasticsearch-values.yaml -n elastic-apm

echo "=== Verify Elasticsearch installation ==="
echo "=== Wait for pods to be ready ==="
kubectl wait --for=condition=ready pod -l app=elasticsearch-master -n elastic-apm --timeout=300s

echo "=== Check status ==="
kubectl get pods -n elastic-apm

#echo "=== Test connection (optional) ==="
#kubectl port-forward svc/elasticsearch-master 9200:9200 -n elastic-apm & curl http://localhost:9200/_cluster/health

#helm uninstall kibana
#k delete all,cm,secret,sa,role,RoleBinding,ClusterRoleBinding -l "release=kibana"
#k delete secret kibana-kibana-es-token

KIBANA_PASSWORD=$(kubectl get secret kibana-credentials -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d)
ELASTIC_PASSWORD=$(kubectl get secret elasticsearch-master-credentials -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d)

kubectl exec -n $NAMESPACE elasticsearch-master-0 -- curl -k -u elastic:$ELASTIC_PASSWORD \
    -X POST "https://localhost:9200/_security/user/kibana_system/_password" \
    -H "Content-Type: application/json" \
    -d "{\"password\":\"$KIBANA_PASSWORD\"}" || {
    echo "Avertissement: Impossible de configurer le mot de passe kibana_system"
}

# Ajout/mise à jour du repo Helm
echo "Mise à jour du repository Helm Elastic..."
helm repo add elastic https://helm.elastic.co
helm repo update

echo "=== Install Kibana ==="
helm install kibana elastic/kibana -f kibana-values.yaml -n elastic-apm

echo "=== Verify Kibana installation ==="
echo "=== Wait for pods to be ready ==="
kubectl wait --for=condition=ready pod -l app=kibana -n elastic-apm --timeout=300s

echo "=== Check status ==="
kubectl get pods -n elastic-apm

echo "=== Get Kibana service URL ==="
kubectl get svc kibana-kibana -n elastic-apm

echo "=== Install APM Server ==="
helm install apm-server elastic/apm-server -f apm-server-values.yaml -n elastic-system --version 8.4.2
  
echo "=== Install OpenTelemetry Collector ==="
helm install otel-collector open-telemetry/opentelemetry-collector -f otel-collector-values.yaml -n elastic-apm

echo "=== Verify OpenTelemetry Collector installation ==="
echo "=== Wait for pods to be ready ==="
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=opentelemetry-collector -n elastic-apm --timeout=300s

echo "=== Check status ==="
kubectl get pods -n elastic-apm
kubectl logs -l app.kubernetes.io/name=opentelemetry-collector -n elastic-apm

echo "=== Configure Index Templates in Elasticsearch ==="
echo "=== Port forward to Elasticsearch ==="

kubectl port-forward svc/elasticsearch-master 9200:9200 -n elastic-apm &

echo "=== Create traces index template ==="
curl -X PUT "localhost:9200/_index_template/otel-traces" \
  -H "Content-Type: application/json" \
  -d '{
    "index_patterns": ["otel-traces*"],
    "template": {
      "mappings": {
        "properties": {
          "@timestamp": { "type": "date" },
          "traceId": { "type": "keyword" },
          "spanId": { "type": "keyword" },
          "parentSpanId": { "type": "keyword" },
          "operationName": { "type": "keyword" },
          "serviceName": { "type": "keyword" },
          "duration": { "type": "long" },
          "tags": { "type": "object" },
          "logs": { "type": "object" }
        }
      }
    }
  }'

echo "=== Create metrics index template ==="
curl -X PUT "localhost:9200/_index_template/otel-metrics" \
  -H "Content-Type: application/json" \
  -d '{
    "index_patterns": ["otel-metrics*"],
    "template": {
      "mappings": {
        "properties": {
          "@timestamp": { "type": "date" },
          "metric_name": { "type": "keyword" },
          "service_name": { "type": "keyword" },
          "value": { "type": "double" },
          "labels": { "type": "object" }
        }
      }
    }
  }'

echo "=== Create logs index template ==="
curl -X PUT "localhost:9200/_index_template/otel-logs" \
  -H "Content-Type: application/json" \
  -d '{
    "index_patterns": ["otel-logs*"],
    "template": {
      "mappings": {
        "properties": {
          "@timestamp": { "type": "date" },
          "level": { "type": "keyword" },
          "message": { "type": "text" },
          "service_name": { "type": "keyword" },
          "trace_id": { "type": "keyword" },
          "span_id": { "type": "keyword" }
        }
      }
    }
  }'
  
echo "=== Get Kibana service details ==="
kubectl get svc kibana-kibana -n elastic-apm

kubectl port-forward svc/kibana-kibana 5601:5601 -n elastic-apm

