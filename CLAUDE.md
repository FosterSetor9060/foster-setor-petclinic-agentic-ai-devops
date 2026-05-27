# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Layout

This repo contains two directories:

- `spring-petclinic-microservices/` — the main Maven multi-module application (8 Spring Boot services)
- `spring-petclinic-microservices-config/` — local Spring Cloud Config files (used when running config-server with the `native` profile)

All Java work happens inside `spring-petclinic-microservices/`. The root of the repo itself has no build files.

## Build & Test Commands

Run from inside `spring-petclinic-microservices/`:

```bash
# Build all modules (skip tests)
./mvnw clean install -Dmaven.test.skip

# Build and run all tests
./mvnw clean install

# Run tests for the whole project (CI style)
mvn -B package --file pom.xml

# Run tests for a single module
./mvnw test -pl spring-petclinic-customers-service

# Run a single test class
./mvnw test -pl spring-petclinic-customers-service -Dtest=PetResourceTest

# Build Docker images for all services (linux/amd64)
./mvnw clean install -P buildDocker -Dmaven.test.skip

# Build Docker images on Apple Silicon (M1/M2/M3)
./mvnw clean install -P buildDocker -Dcontainer.platform=linux/arm64
```

## Running Locally

```bash
# Set the OpenAI API key first (use "demo" for rate-limited free access)
export OPENAI_API_KEY=demo

# Start all services
cd spring-petclinic-microservices/
docker compose up -d
```

After 3–5 minutes, services are accessible at:

| URL | Service |
|-----|---------|
| http://localhost:8080 | API Gateway / PetClinic UI |
| http://localhost:8761 | Eureka Discovery |
| http://localhost:8888 | Config Server |
| http://localhost:9090 | Spring Boot Admin |
| http://localhost:9411 | Zipkin tracing |
| http://localhost:3030 | Grafana |
| http://localhost:9091 | Prometheus |

## Architecture

### Services (all in `spring-petclinic-microservices/`)

| Module | Port | Role |
|--------|------|------|
| `spring-petclinic-config-server` | 8888 | Serves config to all services from git or local filesystem |
| `spring-petclinic-discovery-server` | 8761 | Eureka service registry |
| `spring-petclinic-api-gateway` | 8080 | Spring Cloud Gateway — routes all client traffic via Eureka load balancing (`lb://service-name`) |
| `spring-petclinic-customers-service` | random | Owners and pets domain |
| `spring-petclinic-vets-service` | random | Veterinarians domain |
| `spring-petclinic-visits-service` | random | Visit records domain |
| `spring-petclinic-genai-service` | random | AI chatbot via Spring AI + OpenAI |
| `spring-petclinic-admin-server` | 9090 | Spring Boot Admin UI |

### Startup Order

Services must start in this order or they will fail to register:

**config-server → discovery-server → backend services (customers/vets/visits/genai) → api-gateway → admin-server/observability**

Docker Compose enforces this via `depends_on` + `service_healthy` conditions.

### Spring Profiles

Each service's `application.yml` activates a profile to change behaviour:

- **default** — HSQLDB in-memory DB, config pulled from `localhost:8888`
- **`docker`** — config pulled from `config-server:8888` (Docker Compose hostname)
- **`mysql`** — switches DB to MySQL (`jdbc:mysql://localhost:3306/petclinic`), credentials: `root`/`petclinic`
- **`chaos-monkey`** — enables Chaos Monkey endpoints for fault injection testing

In Kubernetes production deployments, both `docker` and `mysql` profiles are activated together.

### Configuration Architecture

- The Config Server by default fetches config from the upstream GitHub repo `spring-petclinic/spring-petclinic-microservices-config`.
- The `spring-petclinic-microservices-config/` directory in this repo holds local config overrides used when the Config Server runs with the `native` profile and `GIT_REPO` env var pointing to this directory.
- The shared `application.yml` in the config repo applies to all services. Per-service files (e.g., `customers-service.yml`) override it.
- All management/actuator endpoints are fully exposed (`management.endpoints.web.exposure.include: "*"`).
- Tracing is 100% sampled by default (`management.tracing.sampling.probability: 1`).

### GenAI Service

- Uses Spring AI 2.0.0-M1 (milestone release, requires the `spring-milestones` Maven repo).
- Defaults to OpenAI (`spring-ai-starter-model-openai`); Azure OpenAI is available as a commented-out alternative in `pom.xml`.
- API key injected via `OPENAI_API_KEY` env var; falls back to `demo` (rate-limited).

### CI/CD

GitHub Actions workflow (`.github/workflows/maven-build.yml`) triggers on push/PR to `main` and runs `mvn -B package`. The project targets a full pipeline that builds Docker images tagged with the Git SHA, pushes to AWS ECR, and deploys to AWS EKS — the production Kubernetes manifests and Terraform infrastructure live outside this repo.

### Chaos Engineering

Scripts in `scripts/chaos/` can inject faults (latency, exceptions, memory pressure, kill-application) into running services via the Chaos Monkey REST API. The `chaos-monkey` Spring profile must be active on the target service first.
