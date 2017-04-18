#!/bin/bash

CURRENT_VERSION=
SUGGESTED_VERSION=
NEW_VERSION=
VERSION_FILE=

function askForNewVersion {
    read -p "Enter a version number [$SUGGESTED_VERSION]: " INPUT_VERSION
    if [ "$INPUT_VERSION" = "" ]; then
        NEW_VERSION=$SUGGESTED_VERSION
    else
        NEW_VERSION=$INPUT_VERSION
    fi
    echo "Will set new version to be $NEW_VERSION"
}

function suggestVersion {
    local BASE_LIST=(`echo $CURRENT_VERSION | tr '.' ' '`)
    local V_MAJOR=${BASE_LIST[0]}
    local V_MINOR=${BASE_LIST[1]}
    local V_PATCH=${BASE_LIST[2]}
    local V_MINOR=$((V_MINOR + 1))
    local V_PATCH=0
    SUGGESTED_VERSION="$V_MAJOR.$V_MINOR.$V_PATCH"
}

function suggestAndAskForNewVersion {
    suggestVersion
    askForNewVersion
}

function updateChangelog {
    echo "## Version $NEW_VERSION:" > .change.tmp
    git log --pretty=format:" - %s" "v$CURRENT_VERSION"...HEAD >> .change.tmp
    echo "" >> .change.tmp
    echo "" >> .change.tmp
    cat CHANGELOG.md >> .change.tmp
    mv .change.tmp CHANGELOG.md
}

function generateChangelog {
    echo "## Version $NEW_VERSION:" > CHANGELOG.md
    git log --pretty=format:" - %s" >> CHANGELOG.md
    echo "" >> CHANGELOG.md
    echo "" >> CHANGELOG.md
}


function updatePackageJSON {
    local search='("version":[[:space:]]*").+(")'
	local replace="\1${NEW_VERSION}\2"

	sed -i "" -E "s/${search}/${replace}/g" "package.json"
}

function retrieveVersionFromPackageJSON {
    CURRENT_VERSION=$(cat package.json | grep version | head -1 | awk -F= "{ print $2 }" | sed 's/[version:,\",]//g' | tr -d '[[:space:]]')
    echo "Current version : $CURRENT_VERSION"
}

function updateDotVersion {
    echo $NEW_VERSION > .version
}

function retrieveVersionFromDotVersion {
    CURRENT_VERSION=$(cat .version)
    echo "Current version : $CURRENT_VERSION"
}

function prompt {
    read -p "$1 [y]: " response
    if [ "$response" = "" ]; then response="y"; fi
    if [ "$response" = "Y" ]; then response="y"; fi
    if [ "$response" = "Yes" ]; then response="y"; fi
    if [ "$response" = "yes" ]; then response="y"; fi
    if [ "$response" = "YES" ]; then response="y"; fi
    if [ "$response" = "y" ]; then
        return 0
    else
        return 1
    fi
}

if [ -f package.json ]; then
    VERSION_FILE="package.json"
    retrieveVersionFromPackageJSON
    suggestAndAskForNewVersion
    updatePackageJSON
elif [ -f .version ]; then
    VERSION_FILE=".version"
    retrieveVersionFromDotVersion
    suggestAndAskForNewVersion
    updateDotVersion
else
    VERSION_FILE=".version"
    if prompt "Could not retrieve version, do you want to create a version file and start from scratch?"; then
        NEW_VERSION="0.1.0"
        updateDotVersion
    fi
fi

if prompt "Do you want to generate a CHANGELOG? "; then
    if [ "$CURRENT_VERSION" = "" ]; then
        generateChangelog
    elif [ ! -f CHANGELOG.md ]; then
        generateChangelog
    else
        updateChangelog
    fi
fi

if prompt "Do you want to commit and tag changes?"; then
    git add CHANGELOG.md "$VERSION_FILE"
    git commit -m "chore(bump): version $NEW_VERSION"
    git tag -a "v$NEW_VERSION" -m "Version $NEW_VERSION"
    git push && git push origin --tags
fi

if [ -f Dockerfile ]; then
    if prompt "Do you want to build a docker image?"; then
        read -p "Please enter the image name, including the tag: " image_name
        docker build -t $image_name .
        if prompt "Do you want to push the image to the registry?"; then
            docker push $image_name
        fi
    fi
fi
