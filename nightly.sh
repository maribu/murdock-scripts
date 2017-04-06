#!/bin/sh -e

REPO=https://github.com/RIOT-OS/RIOT
BRANCHES="master"
HTTPROOT="/srv/http/ci.riot-labs.de-devel/devel"

BASEDIR="$(dirname $(realpath $0))"

. "${BASEDIR}/common.sh"

[ -f "${BASEDIR}/local.sh" ] && . "${BASEDIR}/local.sh"

get_jobs() {
    dwqc -E NIGHTLY -E STATIC_TESTS -E APPS -E BOARDS './.murdock get_jobs'
}

build() {
    local repo="$1"
    local branch="$2"
    local commit="$3"
    local output_dir="$4"

    export DWQ_REPO="$repo"
    export DWQ_COMMIT="$commit"

    echo "--- Building branch \"$branch\" from repo \"$repo\""
    echo "-- HEAD commit is \"$DWQ_COMMIT\""

    echo "-- using output directory \"$output_dir\""

    mkdir -p "$output_dir"
    cd "$output_dir"

    echo "-- sanity checking build cluster ..."
    dwqc "test -x .murdock" || {
        echo "-- failed! aborting..."
        rm -f result.json
        return 2
    } && echo "-- ok."


    echo "-- starting build..."

    export NIGHTLY=1 STATIC_TESTS=0

    set +e

    get_jobs | dwqc \
        --quiet --outfile result.json

    RES=$?

    set -e

    if [ $RES -eq 0 ]; then
        echo "-- done. Build succeeded."
    else
        echo "-- done. Build failed."
    fi

    export repo branch commit output_dir
    post_build

    return
}

main() {
    for branch in $BRANCHES; do
        local commit="$(gethead $REPO $branch)"
        local output_dir="${HTTPROOT}/$(repo_path $REPO)/$branch/${commit}"

        [ -d "$output_dir" ] && {
            echo "--- $REPO $branch $commit:"
            echo "    $output_dir exists. skipping."
            continue
        }

        mkdir -p "$output_dir"

        build $REPO $branch $commit $output_dir | tee $output_dir/output.txt && \
        {
            cd $output_dir
            cat output.txt
            echo ""
            [ -s result.json ] && HTML=1 ${BASEDIR}/parse_result.py result.json
        } | ansi2html -s solarized -u > ${output_dir}/output.html

        local latest_link="$(dirname "$output_dir")/latest"
        rm -f "$latest_link"
        ln -s "$output_dir" "$latest_link"
    done
}

main
