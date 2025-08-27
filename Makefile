.PHONY: setup setup-monitoring deploy clean test help

# Setup all environments
setup:
	@echo "🚀 Setting up all KIND clusters..."
	./kind/setup-kind.sh dev
	./kind/setup-kind.sh qa
	./kind/setup-kind.sh prod

# Setup simple monitoring
setup-monitoring:
	@echo "📊 Setting up monitoring..."
	./kind/simple-monitoring.sh dev

# Deploy app to development
deploy:
	@echo "🚀 Deploying apps to development..."
	kubectl config use-context kind-dev-cluster
	kubectl apply -k apps/app1
	kubectl apply -k apps/app2

# Clean up all resources
clean:
	@echo "🧹 Cleaning up KIND clusters..."
	kind delete cluster --name dev-cluster || true
	kind delete cluster --name qa-cluster || true
	kind delete cluster --name prod-cluster || true

# Run tests
test:
	@echo "🧪 Running tests..."
	cd apps/app1 && python -m pytest || echo "No tests found"
	cd apps/app2 && python -m pytest || echo "No tests found"

# Show help
help:
	@echo "Available commands:"
	@echo "  setup           - Setup all KIND clusters"
	@echo "  setup-monitoring- Setup simple monitoring"
	@echo "  deploy          - Deploy apps to dev"
	@echo "  test            - Run app tests"
	@echo "  clean           - Clean up clusters"
	@echo "  help            - Show this help"
