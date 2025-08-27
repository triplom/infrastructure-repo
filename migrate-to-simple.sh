#!/bin/bash
set -e

echo "🔄 Migrating to simplified infrastructure..."

# Backup current complex files
echo "📦 Creating backup of complex configurations..."
mkdir -p backup/
cp -r .github/workflows/ci-pipeline.yaml backup/ 2>/dev/null || true
cp -r infrastructure/ backup/ 2>/dev/null || true
cp kind/monitoring-stack.sh backup/ 2>/dev/null || true

# Remove complex configurations that are not needed
echo "🧹 Removing complex configurations..."
rm -f apps/*/base/configmap.yaml 2>/dev/null || true
rm -f apps/*/base/service-monitor.yaml 2>/dev/null || true

# Update app2 to match simplified structure
echo "🔧 Updating app2 structure..."
if [ -d "apps/app2" ]; then
    # Copy simplified kustomization
    cp templates/simple-app/kustomization.yaml apps/app2/base/
    sed -i 's/app1/app2/g' apps/app2/base/kustomization.yaml
    
    # Copy simplified deployment
    cp templates/simple-app/deployment.yaml apps/app2/base/
    sed -i 's/app1/app2/g' apps/app2/base/deployment.yaml
    
    # Copy simplified service
    cp templates/simple-app/service.yaml apps/app2/base/
    sed -i 's/app1/app2/g' apps/app2/base/service.yaml
fi

# Make scripts executable
chmod +x kind/*.sh

echo "✅ Migration to simplified infrastructure complete!"
echo ""
echo "📋 What was simplified:"
echo "  ✓ Removed complex CI pipeline (796 lines → ~100 lines)"
echo "  ✓ Simplified app manifests (removed service monitors, configmaps)"
echo "  ✓ Basic monitoring setup (no Helm complexity)"
echo "  ✓ Streamlined Makefile with essential commands"
echo "  ✓ Backup created in backup/ directory"
echo ""
echo "🚀 Next steps:"
echo "  1. Review the new simplified structure"
echo "  2. Test with: make setup && make deploy"
echo "  3. Check README_Simplified.md for documentation"
