FROM gradle:8.5-jdk17 AS build
WORKDIR /app

COPY build.gradle.kts settings.gradle.kts ./
RUN gradle --no-daemon dependencies

COPY src/ src/
RUN gradle --no-daemon buildFatJar

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /app/build/libs/football-tracker-server.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
