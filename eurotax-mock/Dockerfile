# ============================================================
# Stage 1: Build
# ============================================================
FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /app

# Copy dependency descriptor first for layer caching
COPY pom.xml .

# Download dependencies (cached unless pom.xml changes)
RUN mvn dependency:go-offline -B

# Copy Maven wrapper config (needed for plugin resolution)
COPY .mvn .mvn

# Copy XSD schemas (needed by jaxb2-maven-plugin during compile)
COPY src/main/resources/xsd src/main/resources/xsd

# Copy the rest of the source code
COPY src src

# Build the application, skip tests (they require Testcontainers + Docker)
RUN mvn package -DskipTests -B \
    && mv target/*.jar target/app.jar

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM eclipse-temurin:21-jre-alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy the built JAR from the build stage
COPY --from=build /app/target/app.jar app.jar

# Create logs directory (Logback writes to /app/logs/)
RUN mkdir -p /app/logs && chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose the application port
EXPOSE 8090

# Health check using Spring Boot Actuator
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8090/actuator/health || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
