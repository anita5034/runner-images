#!/usr/bin/env bash
set -euo pipefail

# build-local.sh
# Helper to validate or build images from this repository using PowerShell helper
# Usage:
#   MODE=validate ./build-local.sh        # only run packer validate
#   MODE=build ./build-local.sh           # run GenerateResourcesAndImage (may create Azure resources)
# Environment variables (alternative to passing as args):
#   IMAGE_TYPE (Ubuntu2204|Ubuntu2404|Windows2019|Windows2022|Windows2025)
#   SUBSCRIPTION_ID
#   RESOURCE_GROUP
#   LOCATION
#   CLIENT_ID
#   CLIENT_SECRET
#   TENANT_ID
#   MANAGED_IMAGE_NAME
#   RESTRICT_TO_AGENT_IP (true/false)
#   PLUGIN_VERSION (default 2.2.1)
#   REPO_ROOT (defaults to current directory)

MODE=${MODE:-build}
IMAGE_TYPE=${IMAGE_TYPE:-Ubuntu2404}
REPO_ROOT=${REPO_ROOT:-$(pwd)}
SUBSCRIPTION_ID=${SUBSCRIPTION_ID:-}
RESOURCE_GROUP=${RESOURCE_GROUP:-}
LOCATION=${LOCATION:-"East US"}
CLIENT_ID=${CLIENT_ID:-}
CLIENT_SECRET=${CLIENT_SECRET:-}
TENANT_ID=${TENANT_ID:-}
MANAGED_IMAGE_NAME=${MANAGED_IMAGE_NAME:-}
RESTRICT_TO_AGENT_IP=${RESTRICT_TO_AGENT_IP:-false}
PLUGIN_VERSION=${PLUGIN_VERSION:-2.2.1}

if [[ "$MODE" != "build" && "$MODE" != "validate" ]]; then
  echo "MODE must be 'build' or 'validate'" >&2
  exit 1
fi

command -v pwsh >/dev/null 2>&1 || { echo "pwsh (PowerShell) not found in PATH. Install PowerShell (pwsh) and retry." >&2; exit 2; }
if [[ "$MODE" == "validate" ]]; then
  command -v packer >/dev/null 2>&1 || { echo "packer not found in PATH. Install Packer and retry." >&2; exit 3; }
fi

TMP_PS1=$(mktemp --suffix .ps1)
cat > "$TMP_PS1" <<'PS1'
param(
  [string]$RepoRoot,
  [string]$ImageType,
  [string]$Mode,
  [string]$SubscriptionId,
  [string]$ResourceGroup,
  [string]$Location,
  [string]$ClientId,
  [string]$ClientSecret,
  [string]$TenantId,
  [string]$ManagedImageName,
  [switch]$RestrictToAgentIpAddress,
  [string]$PluginVersion
)

# Import helper
$modulePath = Join-Path $RepoRoot 'helpers/GenerateResourcesAndImage.ps1'
if (-not (Test-Path $modulePath)) {
  Write-Error "Cannot find GenerateResourcesAndImage.ps1 at $modulePath"
  exit 2
}
Import-Module $modulePath -Force

if ($Mode -eq 'validate') {
  $pt = Get-PackerTemplate -RepositoryRoot $RepoRoot -ImageType ([ImageType]::$ImageType)
  Write-Host "Validating template path: $($pt.Path), BuildName: $($pt.BuildName)"
  & packer validate -syntax-only -only "${($pt.BuildName)}*" $pt.Path
  exit $LASTEXITCODE
}
elseif ($Mode -eq 'build') {
  $args = @{
    SubscriptionId = $SubscriptionId
    ResourceGroupName = $ResourceGroup
    ImageType = [ImageType]::$ImageType
    AzureLocation = $Location
    ImageGenerationRepositoryRoot = $RepoRoot
    PluginVersion = $PluginVersion
  }
  if ($ClientId) { $args['AzureClientId'] = $ClientId }
  if ($ClientSecret) { $args['AzureClientSecret'] = $ClientSecret }
  if ($TenantId) { $args['AzureTenantId'] = $TenantId }
  if ($ManagedImageName) { $args['ManagedImageName'] = $ManagedImageName }
  if ($RestrictToAgentIpAddress) { $args['RestrictToAgentIpAddress'] = $true }

  Write-Host "Invoking GenerateResourcesAndImage with args: $($args.Keys -join ', ')"
  GenerateResourcesAndImage @args
  exit $LASTEXITCODE
}
else {
  Write-Error "Unknown Mode $Mode"
  exit 3
}
PS1

# Build pwsh invocation
PW_SH_ARGS=( -NoProfile -ExecutionPolicy Bypass -File "$TMP_PS1" -RepoRoot "$REPO_ROOT" -ImageType "$IMAGE_TYPE" -Mode "$MODE" -SubscriptionId "$SUBSCRIPTION_ID" -ResourceGroup "$RESOURCE_GROUP" -Location "$LOCATION" -ClientId "$CLIENT_ID" -ClientSecret "$CLIENT_SECRET" -TenantId "$TENANT_ID" -ManagedImageName "$MANAGED_IMAGE_NAME" -PluginVersion "$PLUGIN_VERSION" )

if [[ "$RESTRICT_TO_AGENT_IP" == "true" ]]; then
  PW_SH_ARGS+=( -RestrictToAgentIpAddress )
fi

pwsh "${PW_SH_ARGS[@]}"
RC=$?
rm -f "$TMP_PS1"
exit $RC
