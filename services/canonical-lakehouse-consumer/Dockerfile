# Stage 1: build
FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /workspace
COPY pom.xml ./
# Fetch dependencies as a separate layer so rebuilds skip this step when pom.xml is unchanged
RUN mvn -q dependency:go-offline -DincludeScope=compile
COPY src ./src
RUN mvn -q -DskipTests clean package

# Stage 2: runtime
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /workspace/target/canonical-lakehouse-consumer-*.jar app.jar

# Spark 3.x requires these module opens on Java 17+
ENV JAVA_TOOL_OPTIONS="\
  --add-opens=java.base/java.lang=ALL-UNNAMED \
  --add-opens=java.base/java.lang.invoke=ALL-UNNAMED \
  --add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
  --add-opens=java.base/java.io=ALL-UNNAMED \
  --add-opens=java.base/java.net=ALL-UNNAMED \
  --add-opens=java.base/java.nio=ALL-UNNAMED \
  --add-opens=java.base/java.util=ALL-UNNAMED \
  --add-opens=java.base/java.util.concurrent=ALL-UNNAMED \
  --add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED \
  --add-opens=java.base/sun.nio.ch=ALL-UNNAMED \
  --add-opens=java.base/sun.nio.cs=ALL-UNNAMED \
  --add-opens=java.base/sun.security.action=ALL-UNNAMED \
  --add-opens=java.base/sun.util.calendar=ALL-UNNAMED \
  --add-opens=java.security.jgss/sun.security.krb5=ALL-UNNAMED"

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
