build_settings := 'build.yaml'

zmk_src := '/workspaces/zmk'
zmk_config := '/workspaces/zmk-config'
zmk_modules := '/workspaces/zmk-modules'

build-matrix:
    #!/usr/bin/env bash
    readarray build_boards < <(yq --output-format=json --indent=0 '.include[]' {{build_settings}} )
    for build_board in "${build_boards[@]}"; do
        echo $build_board | yq --output-format=json
    done

build target='all': clean
    #!/usr/bin/env bash
    readarray build_matrix < <(yq --output-format=json --indent=0 '.include[]' {{build_settings}} )
    for build_item in "${build_matrix[@]}"; do
        echo $build_item | yq --output-format=json

        board=$(echo "$build_item" | yq '.board' -)
        shield=$(echo "$build_item" | yq '.shield' -)
        snippet=$(echo "$build_item" | yq '.snippet // ""' -)
        modules=$(echo "$build_item" | yq '.modules | map("{{zmk_modules}}/" + .) | join(";")')
        name=$(echo "$build_item" | yq '.name // .shield' -)

        name=${name//[[:space:]]/_}

        if [[ "{{target}}" != "all" ]] && [[ "$name" != "{{target}}" ]]; then
            echo 'skip'
            continue
        fi

        just _build-board "${name}" "${board}" "${shield}" "${snippet}" "${modules}"
        just _export-build "${name}"
    done

clean:
    rm -rf build/*
    docker exec --workdir={{zmk_src}}/app zmk-builder rm -rf build

_build-board name board shield snippet modules:
    #!/usr/bin/env bash

    name='{{name}}'
    board='{{board}}'
    shield='{{shield}}'
    snippet='{{snippet}}'
    modules='{{modules}}'

    docker exec --workdir={{zmk_src}}/app zmk-builder west build \
        --build-dir="build/${name}" \
        --board="${board}" \
        ${snippet:+--snippet="${snippet}"} \
        -- \
            -DSHIELD="${shield}" \
            -DZMK_CONFIG="{{zmk_config}}/config" \
            -DZMK_EXTRA_MODULES="{{zmk_config}}${modules:+;${modules}}"

_export-build name:
    docker cp \
        zmk-builder:{{zmk_src}}/app/build/{{name}}/zephyr/zmk.uf2 \
        build/{{name}}.uf2
