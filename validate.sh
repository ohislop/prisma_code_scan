export INSTALLED_TF_VERSION="$(terraform --version | awk -F' ' '{print $2; exit}')"
export MINIMUM_TF_VERSION="v0.15.0"
export TF_DATA_DIR="./.terraform"
mkdir -p "$HOME/.terraform.d/plugin-cache"
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
export TF_VERSION_LIST=$(printf $INSTALLED_TF_VERSION"\n"$MINIMUM_TF_VERSION | sort -V)
export LOWEST_TF_VERSION=$(echo $TF_VERSION_LIST | head -1)
export AWS_DEFAULT_REGION="ap-southeast-2"
export TF_IN_AUTOMATION=true
ret=0


for cloud in ../*; do
    if [ -d "$cloud" ] && [ ! -L "$cloud" ] && [[ ${cloud} != *"__"* ]]; then
        for service in ${cloud}/*; do
            if [ -d "$service" ] && [ ! -L "$service" ] && [[ ${service} != *"__"* ]]; then
                for resource in ${service}/*; do
                    if [ -d "$resource" ] && [ ! -L "$resource" ] && [[ ${resource} != *"__"* ]]; then
                        echo "###########"
                        echo "# Validating ${resource}"
                        echo "###########"
                        if [[ $LOWEST_TF_VERSION == $MINIMUM_TF_VERSION ]]; then
                            terraform -chdir=$resource init
                            terraform -chdir=$resource validate
                        elif [[ $LOWEST_TF_VERSION != $MINIMUM_TF_VERSION ]]; then
                            terraform init $resource
                            terraform validate $resource
                        fi
                        validate_response=$(echo $?)
                        if [[ $validate_response -ne 0 ]]; then
                            failures="$failures$resource\n"
                            ret=1
                        fi
                    fi
                done
            fi
        done
    fi
done


if [ $ret -ne 0 ]; then
    echo -e "\n###########\n$num_of_failures\xE2\x9D\x8C failed tests:\n$failures\n###########"
    exit 1
else
    echo -e "All passed! \xE2\x9C\x85"
    exit 0
fi
