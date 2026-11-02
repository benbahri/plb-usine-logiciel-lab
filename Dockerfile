# Image multi-stage de sirh-export-api (atelier A09)
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY . .
RUN mvn -B -q -DskipTests -pl sirh-export-api -am package

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/sirh-export-api/target/sirh-export-api-*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
