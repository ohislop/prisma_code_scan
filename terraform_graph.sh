export INSTALLED_TF_VERSION="$(terraform --version | awk -F' ' '{print $2; exit}')"
export MINIMUM_TF_VERSION="v0.15.0"
export TF_DATA_DIR="./.terraform"
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
export TF_VERSION_LIST=$(printf $INSTALLED_TF_VERSION"\n"$MINIMUM_TF_VERSION | sort -V)
export LOWEST_TF_VERSION=$(echo $TF_VERSION_LIST | head -1)
export AWS_DEFAULT_REGION="ap-southeast-2"

for cloud in ../*; do
    if [ -d "$cloud" ] && [ ! -L "$cloud" ] && [[ ${cloud} != *"__"* ]]; then
        for service in ${cloud}/*; do
            if [ -d "$service" ] && [ ! -L "$service" ] && [[ ${service} != *"__"* ]]; then
                for resource in ${service}/*; do
                    if [ -d "$resource" ] && [ ! -L "$resource" ] && [[ ${resource} != *"__"* ]]; then
                        echo "###########"
                        echo "# Generating Terraform Graph ${resource}"
                        echo "###########"
                        if [[ $LOWEST_TF_VERSION == *$MINIMUM_TF_VERSION* ]]; then
                            terraform -chdir=$resource graph | terraform-graph-beautifier \
                                --exclude="module.root.data" \
                                --exclude="module.root.provider" \
                                --exclude="module.root.local" \
                                --exclude="module.root.output" \
                                --embed-modules=true \
                                --output-type=graphviz | dot -Tsvg >$resource/diagram.svg
                        elif [[ $LOWEST_TF_VERSION != *$MINIMUM_TF_VERSION* ]]; then
                            terraform graph $resource | terraform-graph-beautifier \
                                --exclude="module.root.data" \
                                --exclude="module.root.provider" \
                                --exclude="module.root.local" \
                                --exclude="module.root.output" \
                                --embed-modules=true \
                                --output-type=graphviz | dot -Tsvg >$resource/diagram.svg
                        fi
                    fi
                done
            fi
        done
    fi
done
