# Multi-stage build for Spring Pet Clinic application
FROM eclipse-temurin:17-jdk AS builder

# Set working directory
WORKDIR /app

# Copy Maven wrapper and pom.xml
COPY mvnw ./
COPY mvnw.cmd ./
COPY .mvn .mvn
COPY pom.xml ./

# Make mvnw executable
RUN chmod +x ./mvnw

# Download dependencies (this layer will be cached if pom.xml doesn't change)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN ./mvnw clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:17-jre

# Create non-root user
RUN groupadd -r petclinic && useradd -r -g petclinic petclinic

# Set working directory
WORKDIR /app

# Install necessary packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the JAR file from builder stage
COPY --from=builder /app/target/*.jar app.jar

# Create cache directory
RUN mkdir -p /app/cache && chown -R petclinic:petclinic /app

# Switch to non-root user
USER petclinic

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# JVM tuning for containers
ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:+UseG1GC \
               -XX:+UseStringDeduplication \
               -XX:+OptimizeStringConcat \
               -Djava.security.egd=file:/dev/./urandom"

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]