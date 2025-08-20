helm repo add elastic https://helm.elastic.co
helm repo update

kubectl apply -f https://download.elastic.co/downloads/eck/3.1.0/operator.yaml

kubectl create namespace elastic-apm

helm install elasticsearch elastic/elasticsearch --values elasticsearch-values.yaml -n elastic-apm

helm install kibana elastic/kibana -f kibana_values.yaml -n elastic-apm

# Install an eck-managed Elasticsearch and Kibana using the default values, which deploys the quickstart examples.
#helm install es-kb-quickstart elastic/eck-stack -n elastic-stack --create-namespace

# Install an eck-managed Elasticsearch and Kibana using the Elasticsearch node roles example with hot, warm, and cold data tiers, and the Kibana example customizing the http service.
#helm install es-quickstart elastic/eck-stack -n elastic-stack --values masters_es_values.yaml --values kibana_values.yaml