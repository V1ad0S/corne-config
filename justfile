build_settings := 'build.yaml'

build-matrix:
    #!/usr/bin/env bash
    readarray build_boards < <(yq --output-format=json --indent=0 '.include[]' {{build_settings}} )
    for build_board in "${build_boards[@]}"; do
        echo $build_board | yq --output-format=json
    done

build:
    #!/usr/bin/env bash
    readarray build_matrix < <(yq --output-format=json --indent=0 '.include[]' {{build_settings}} )
    for build_item in "${build_matrix[@]}"; do
        echo $build_item | yq --output-format=json

        board=$(echo "$build_item" | yq '.board' -)
        shield=$(echo "$build_item" | yq '.shield' -)
        snippet=$(echo "$build_item" | yq '.snippet // ""' -)
        name=$(echo "$build_item" | yq '.name // .shield' -)

        name=${name//[[:space:]]/_}

        just _build-board "${name}" "${board}" "${shield}" "${snippet}"
        just _export-build "${name}"
    done

_build-board name board shield snippet:
    #!/usr/bin/env bash

    name='{{name}}'
    board='{{board}}'
    shield='{{shield}}'
    snippet='{{snippet}}'

    docker exec --workdir=/workspaces/zmk/app zmk-builder west build \
        --build-dir="build/${name}" \
        --board="${board}" \
        ${snippet:+--snippet="${snippet}"} \
        -- \
            -DSHIELD="${shield}" \
            -DZMK_CONFIG="/workspaces/zmk-config/config"

_export-build name:
    docker cp \
        zmk-builder:/workspaces/zmk/app/build/{{name}}/zephyr/zmk.uf2 \
        build/{{name}}.uf2
