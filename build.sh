export README_ADDITIONAL_PATH="__README"
export README_EXAMPLES_PATH="__examples"
export README_TEMPLATE_PATH="__documentation_template"
export TERRAFORM_TEMPLATE_PATH="__terraform_template"
export BLUEPRINTS_BUILDING_BLOCKS_REPO_NAME="bp-building-blocks"
export BLUEPRINTS_PATTERNS_REPO_NAME="bp-patterns"
export BLUEPRINTS_CA_REPO_NAME="bp-assurance-policies"
export BLUEPRINTS_SECURITY_CERTIFICATION_REPO_NAME="bp-security-certifications"
export BLUEPRINTS_REPO_PROJECT="terraform-modules"
export BLUEPRINTS_REPO_HOST="github.service.anz"
export AWS_DEFAULT_REGION="ap-southeast-2"
export CONTROL_ID_IMPLEMENTED_OUTPUT_FILE="__controls_implemented.json"
export CONTROL_ID_DISCOVERY_PATTERN="// "
export AWS_VERSION_BLUEPRINTS="1.0.0"
export AWS_VERSION_CERTIFICATION="1.0.0"
export GOOGLE_VERSION_BLUEPRINTS="1-0-0"
export GOOGLE_VERSION_CERTIFICATION="1-0-0"

echo "Generating documentation for blueprints - bb"

# make an alias for gsed if running on WSL
if uname -a | grep -q Microsoft; then
    alias gsed="sed"
fi

echo "# ANZ Building Blocks" >"../README.md"
echo "## Cloud Services & Controls" >>"../README.md"
echo "[Subscribe to changes in this project](https://raw.$BLUEPRINTS_REPO_HOST/$BLUEPRINTS_REPO_PROJECT/$BLUEPRINTS_BUILDING_BLOCKS_REPO_NAME/master/rss.xml) (RSS)" >>"../README.md"
echo "\nBelow is a breakdown per cloud / services / resource / security controls implemented in this project\n" >> "../README.md"
echo "| cloud | service | resource | securitycontrols |" >>"../README.md"
echo "|----|----|----|----|" >>"../README.md"

for cloud in ../*; do
    if [ -d "$cloud" ] && [ ! -L "$cloud" ] && [[ ${cloud} != *"__"* ]]; then

        echo "## ANZ Building Blocks" >"$cloud/README.md"
        echo "\nBelow is a breakdown per cloud / services / resource / security controls implemented in this project\n" >> "$cloud/README.md"
        echo "| cloud | service | resource | securitycontrols |" >>"$cloud/README.md"
        echo "|----|----|----|----|" >>"$cloud/README.md"

        # iterate services within the cloud
        for service in ${cloud}/*; do
            if [ -d "$service" ] && [ ! -L "$service" ] && [[ ${service} != *"__"* ]]; then

                echo "| cloud | service | resource | securitycontrols| " >"$service/README.md"
                echo "|----|----|----|----|" >>"$service/README.md"

                # iterate resources within the service
                for resource in ${service}/*; do
                    if [ -d "$resource" ] && [ ! -L "$resource" ] && [[ ${resource} != *"__"* ]]; then

                        echo "| cloud | service | resource | securitycontrols |" >"$resource/README.md"
                        echo "|----|----|----|----|" >>"$resource/README.md"

                        # create variables from the url
                        cloud_name=$(echo $resource | cut -d/ -f2)
                        service_name=$(echo $resource | cut -d/ -f3)
                        resource_name=$(echo $resource | cut -d/ -f4)

                        # copy terraform artefacts to bb
                        cp "../${TERRAFORM_TEMPLATE_PATH}/${cloud_name}/data_shared.tf" $resource
                        cp "../${TERRAFORM_TEMPLATE_PATH}/${cloud_name}/variables_shared.tf" $resource
                        cp "../${TERRAFORM_TEMPLATE_PATH}/${cloud_name}/locals_shared.tf" $resource
                        cp "../${TERRAFORM_TEMPLATE_PATH}/${cloud_name}/outputs_shared.tf" $resource

                        # generate name and version for each building block
                        if [[ $cloud_name == *"google"* ]]; then
                            echo "{\"name\": \"anz-$cloud_name-$service_name-$resource_name\"," >$resource/__meta.json
                            echo "\"version_blueprint\": \"$GOOGLE_VERSION_BLUEPRINTS\", \"version_certification\": \"$GOOGLE_VERSION_CERTIFICATION\"}" >>$resource/__meta.json
                        elif [[ $cloud_name == *"aws"* ]]; then
                            echo "{\"name\": \"anz-$cloud_name-$service_name-$resource_name\"," >$resource/__meta.json
                            echo "\"version_blueprint\": \"$AWS_VERSION_BLUEPRINTS\", \"version_certification\": \"$AWS_VERSION_CERTIFICATION\"}" >>$resource/__meta.json
                        fi

                        # generate control id file for each building block
                        file=("$resource/$CONTROL_ID_IMPLEMENTED_OUTPUT_FILE")

                        # create combined terraform file to search through comments
                        (cat $resource/*.tf) >$resource/__securitycontrols.tmp
                        main=($resource/__securitycontrols.tmp)

                        # clean existing file
                        rm -rf $file

                        # Create a new JSON file ready to go for Control IDs.
                        echo "{\"control_id_list\": [" >$file

                        # Read each line and determine if there are comments. If so create an entry in a new JSON file for each comment.
                        while IFS="" read -r p; do
                            if [[ "$p" == *$CONTROL_ID_DISCOVERY_PATTERN* ]]; then
                                echo -n "\"" >>$file
                                # All whitespace is removed as part of this.
                                echo -n "${p/\/\//}" | gsed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/\ //g' -e 's/ *$//' | tr -d '[[:space:]]' >>$file
                                echo "\"""," >>$file
                            fi
                        done <$main

                        # If no control ids present in the file then remove the created JSON.
                        if grep -q $CONTROL_ID_DISCOVERY_PATTERN $main; then
                            gsed -i '$ s/.$//' $file
                        fi

                        echo "]}" >>$file

                        # prettify json file & remove duplicates
                        jq -r '. | {control_id_list: .[]|unique}' $file >"${resource}/tmp_${CONTROL_ID_IMPLEMENTED_OUTPUT_FILE}"
                        mv "${resource}/tmp_${CONTROL_ID_IMPLEMENTED_OUTPUT_FILE}" $file

                        # somehow black magic
                        jq -r -s '.[0] * .[1]' "$resource/__meta.json" $file >>"$resource/__meta_tmp.json"
                        mv "$resource/__meta_tmp.json" "$resource/__meta.json"

                        # copy readme artefacts to bb
                        cp ../${README_TEMPLATE_PATH}/header.md $resource
                        cp ../${README_TEMPLATE_PATH}/footer.md $resource
                        cp ../${README_TEMPLATE_PATH}/.terraform-docs.yml $resource

                        # if summary content present, add to template, else remove placeholder
                        if test -f "$resource/$README_ADDITIONAL_PATH/summary.md"; then
                            gsed -i "s/<< .Summary >>/{{ include \"$README_ADDITIONAL_PATH\/summary.md\" }}/g" "$resource/.terraform-docs.yml"
                        else
                            gsed -i "s/<< .Summary >>/TBC/g" "$resource/.terraform-docs.yml"
                        fi

                        # if meta content present, add to template, else remove placeholder
                        if test -f "$resource/__meta.json"; then
                            gsed -i "s/<< .Meta >>/\{{ include \"__meta.json\" }}/g" "$resource/.terraform-docs.yml"
                        else
                            gsed -i "s/<< .Meta >>/TBC/g" "$resource/.terraform-docs.yml"
                        fi

                        # if examples content present, add to template, else remove placeholder
                        examples=""
                        if [ -d "$resource/$README_EXAMPLES_PATH" ] && [ ! -L "$resource/$README_EXAMPLES_PATH" ]; then
                            for file in $resource/$README_EXAMPLES_PATH/*.tf; do
                                filename="$(basename $file)"
                                examples="${examples} {{ include \"$README_EXAMPLES_PATH\/$filename\" }} \n"
                            done
                        fi
                        gsed -i "s/<< .Examples >>/$examples/g" "$resource/.terraform-docs.yml"

                        # run terraform docs on the resource
                        terraform-docs markdown "$resource" >"$resource/README.md"

                        for file in $resource/*; do
                            if [ -f "$file" ] && [[ ${file} != *"__"* ]]; then

                                # replace any placeholders (from new resources)
                                gsed -i "s/<<Cloud>>/$cloud_name/g" "$file"
                                gsed -i "s/<<Service>>/$service_name/g" "$file"
                                gsed -i "s/<<Resource>>/$resource_name/g" "$file"
                                gsed -i "s/<<RepoHost>>/$BLUEPRINTS_REPO_HOST/g" "$file"
                                gsed -i "s/<<RepoProject>>/$BLUEPRINTS_REPO_PROJECT/g" "$file"
                                gsed -i "s/<<RepoNamePatterns>>/$BLUEPRINTS_PATTERNS_REPO_NAME/g" "$file"
                                gsed -i "s/<<RepoNameCA>>/$BLUEPRINTS_CA_REPO_NAME/g" "$file"
                                gsed -i "s/<<RepoNameBuildingBlocks>>/$BLUEPRINTS_BUILDING_BLOCKS_REPO_NAME/g" "$file"
                                gsed -i "s/<<RepoNameCertification>>/$BLUEPRINTS_SECURITY_CERTIFICATION_REPO_NAME/g" "$file"
                            fi
                        done

                        # format all terraform files in bb
                        terraform fmt --recursive $resource

                        # delete template artefacts
                        rm "$resource/header.md"
                        rm "$resource/footer.md"
                        rm "$resource/.terraform-docs.yml"
                        rm "$resource/__securitycontrols.tmp"

                        # iterate controls
                        line_prefix="| [$cloud_name](https://$BLUEPRINTS_REPO_HOST/$BLUEPRINTS_REPO_PROJECT/$BLUEPRINTS_BUILDING_BLOCKS_REPO_NAME/tree/master/$cloud_name) | [$service_name](https://$BLUEPRINTS_REPO_HOST/$BLUEPRINTS_REPO_PROJECT/$BLUEPRINTS_BUILDING_BLOCKS_REPO_NAME/tree/master/$cloud_name/$service_name) | [$resource_name](https://$BLUEPRINTS_REPO_HOST/$BLUEPRINTS_REPO_PROJECT/$BLUEPRINTS_BUILDING_BLOCKS_REPO_NAME/tree/master/$cloud_name/$service_name/$resource_name) |"
                        for c in $(jq -r ".control_id_list | .[]" ${resource}/${CONTROL_ID_IMPLEMENTED_OUTPUT_FILE}); do

                            echo "$line_prefix $c |" >> "../README.md"
                            echo "$line_prefix $c" >> "$cloud/README.md"
                            echo "$line_prefix $c" >> "$service/README.md"

                            line_prefix="| | | |"

                        done | column -t -s$'\t'
                    fi
                done
            fi
        done
    fi
done
