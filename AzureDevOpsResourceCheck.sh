declare -r USAGE_HELP="Usage: ./AzureDevOpsResourceCheck.sh -l <AZURE_LOCATION>"
declare location=""

_error() {
    _color="\e[31m" # red
    echo -e "${_color}##[error] $@\n\e[0m" 2>&1
}

_success() {
    _color="\e[32m" # green
    echo -e "${_color}## $@\n\e[0m" 2>&1
}

# Verify the type of input and number of values
# Display an error message if the input is not correct
# Exit the shell script with a status of 1 using exit 1 command.
if [ $# -eq 0 ]; then
    _error "${USAGE_HELP}"
    exit 1
fi

# Initialize parameters specified from command line
while getopts ":l:" arg; do
    case "${arg}" in
    l) # Process -l (Location)
        location="${OPTARG}"
        ;;
    \?)
        _error "Invalid options found: -${OPTARG}."
        _error "${USAGE_HELP}"
        exit 1
        ;;
    esac
done
shift $((OPTIND - 1))

if [ ${#location} -eq 0 ]; then
    _error "Required AZURE_LOCATION parameter is not set!"
    _error "${USAGE_HELP}"
    exit 1
fi

rand=$((100 + $RANDOM % 1000))

resourceGroup="TestRG$rand"

_success "ResourceGroup: $resourceGroup"

az config set extension.use_dynamic_install=yes_without_prompt

# Resource Group
az group create -n $resourceGroup -l $location
if [ $(az group exists --name $resourceGroup) = true ]; then
    _success "ResourceGroup successful!"
else
    _error ResourceGroup failed...
fi

# Log Analytics
az monitor log-analytics workspace create -g $resourceGroup -n TestWorkspace$rand
if [ $(az monitor log-analytics workspace list -g $resourceGroup  --query "[?name=='TestWorkspace$rand'] | length(@)") = 1 ]; then
    _success "Log Analytics successful!"
else
    _error Log Analytics failed...
fi

# AppService Plan
az appservice plan create --resource-group $resourceGroup -n TestAppPlan$rand --is-linux --number-of-workers 4 --sku S1
if [ $(az appservice plan list --resource-group $resourceGroup --query "[?name=='TestAppPlan$rand'] | length(@)") = 1 ]; then
    _success "AppServicePlan successful!"
else
    _error AppServicePlan failed...
fi

# Web App
az webapp create --resource-group $resourceGroup -p TestAppPlan$rand -n WebApp$rand --runtime DOTNETCORE:7.0
if [ $(az webapp list --resource-group $resourceGroup --query "[?name=='WebApp$rand'] | length(@)") = 1 ]; then
    echo Web App test successful!
else
    _error Web App test failed...
fi

# AppInsights
az monitor app-insights component create --app TestInsights$rand -g $resourceGroup -l $location
if [ $(az monitor app-insights component show -g $resourceGroup --app TestInsights$rand | grep "name" | wc -l) > 0 ]; then
    _success "App Insights test successful!"
else
    _error App Insights test failed...
fi

# Managed Identity
az identity create --resource-group $resourceGroup --name TestIdentity$rand
if [ $(az identity list --resource-group $resourceGroup --query "[?name=='TestIdentity$rand'] | length(@)") = 1 ]; then
    _success "Managed Identity successful!"
else
    _error Managed Identity failed...
fi

#container registry
az acr create -n testregistry$rand -g $resourceGroup --sku Standard
if [ $(az acr list --resource-group $resourceGroup --query "[?name=='testregistry$rand'] | length(@)") = 1 ]; then
    _success "Container Registry successful!"
else
    _error Container Registry failed...
fi

#azure sql
az sql server create -g $resourceGroup -n testsql$rand -u sqladmin -p P@ssword123!
if [ $(az sql server list --resource-group $resourceGroup --query "[?name=='testsql$rand'] | length(@)") = 1 ]; then
    _success "Azure SQL successful!"
else
    _error Azure SQL failed...
fi

# Key Vault
az keyvault create --resource-group $resourceGroup --name TestVault$rand
if [ $(az keyvault list --resource-group $resourceGroup --query "[?name=='TestVault$rand'] | length(@)") = 1 ]; then
    _success "KeyVault successful!"
else
    _error KeyVault failed...
fi

if [ $(az group exists --name $resourceGroup) = true ]; then 
   _success "Deleting resources..."
   az group delete --name $resourceGroup -y  --no-wait
fi