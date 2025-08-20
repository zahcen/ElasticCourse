rm hello-server.jar HelloServer.class

/opt/IBM/WebSphere/AppServer/java/bin/javac HelloServer.java

/opt/IBM/WebSphere/AppServer/java/bin/jar cfm hello-server.jar manifest.txt HelloServer.class HelloServer\$HelloHandler.class

/opt/IBM/WebSphere/AppServer/java/bin/java \
-javaagent:/opt/IBM/apm/elastic-otel-javaagent-1.5.0.jar \
-Dotel.exporter.otlp.endpoint=https://my-observability-project-b89663.apm.europe-west1.gcp.elastic.cloud:443 \
-Dotel.exporter.otlp.headers="Authorization=ApiKey b2x4dFg1Z0JUTVFibzVwVDhRS3c6VHlVaVVuN3RzQjY5YXRHSXpXRHNSUQ==" \
-Dotel.resource.attributes="service.name=otel-hello-server,service.version=1.0.0,deployment.environment=test2" \
-Dotel.traces.exporter=otlp \
-Dotel.metrics.exporter=otlp \
-Dotel.logs.exporter=otlp \
-Dotel.javaagent.debug=true \
-jar hello-server.jar
