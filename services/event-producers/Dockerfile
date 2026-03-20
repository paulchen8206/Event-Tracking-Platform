FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /workspace

COPY pom.xml ./
COPY src ./src

RUN mvn -q -DskipTests clean package

FROM eclipse-temurin:17-jre
WORKDIR /app

COPY --from=build /workspace/target/event-producers-0.1.0-SNAPSHOT.jar /app/event-producers.jar

ENTRYPOINT ["java", "-jar", "/app/event-producers.jar"]
