for cloud in ../*; do
    if [ -d "$cloud" ] && [ ! -L "$cloud" ] && [[ ${cloud} != *"__"* ]]; then
        for service in ${cloud}/*; do
            if [ -d "$service" ] && [ ! -L "$service" ] && [[ ${service} != *"__"* ]]; then
                for resource in ${service}/*; do
                    if [ -d "$resource" ] && [ ! -L "$resource" ] && [[ ${resource} != *"__"* ]]; then
                        cd $resource
                        tflint --disable-rule=terraform_module_pinned_source
                    fi
                done
            fi
        done
    fi
done
cd ../../../__scripts
