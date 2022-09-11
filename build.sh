#! /usr/bin/env bash
set -e

MoveIntoFolder() {
  cd /home/draper/RiderProjects/Sonarr
}
MoveIntoFolder
buildVersion=$(jq -r '.version' ./root/VERSION.json)
BUILD_NUMBER=$(echo "$buildVersion" | cut -d. -f4)

outputFolder='_output'
testPackageFolder='_tests'
artifactsFolder="_artifacts";

ProgressStart()
{
    echo "##teamcity[blockOpened name='$1']"
    echo "##teamcity[progressStart '$1']"
    echo "Start '$1'"
}

ProgressEnd()
{
    echo "Finish '$1'"
    echo "##teamcity[progressFinish '$1']"
    echo "##teamcity[blockClosed name='$1']"
}

FetchLatestVersion()
{
  MoveIntoFolder
  echo "Updating Version from API"
  cd ./root || return
  ./update.sh
  MoveIntoFolder || return
}

UpdateVersionNumber()
{
    if [ "$BUILD_NUMBER" != "" ]; then
        echo "Updating Version Info"
        verMajorMinorRevision=`echo "$buildVersion" | cut -d. -f1,2,3`
        verBuild=`echo "${buildVersion}" | cut -d. -f4`
        BUILD_NUMBER=$verMajorMinorRevision.$verBuild
        echo "##teamcity[buildNumber '$BUILD_NUMBER']"
        sed -i "s/<AssemblyVersion>[0-9.*]\+<\/AssemblyVersion>/<AssemblyVersion>$BUILD_NUMBER<\/AssemblyVersion>/g" ./src/Directory.Build.props
        sed -i "s/<AssemblyConfiguration>[\$()A-Za-z-]\+<\/AssemblyConfiguration>/<AssemblyConfiguration>${BRANCH:-dev}<\/AssemblyConfiguration>/g" ./src/Directory.Build.props
    fi
}

CreateReleaseInfo()
{
    if [ "$BUILD_NUMBER" != "" ]; then
        echo "Create Release Info"
        echo -e "# Do Not Edit\nReleaseVersion=$BUILD_NUMBER\nBranch=${BRANCH:-dev}" > $outputFolder/release_info
    fi
}

EnableBsdSupport()
{
    #todo enable sdk with
    #SDK_PATH=$(dotnet --list-sdks | grep -P '5\.\d\.\d+' | head -1 | sed 's/\(5\.[0-9]*\.[0-9]*\).*\[\(.*\)\]/\2\/\1/g')
    # BUNDLED_VERSIONS="${SDK_PATH}/Microsoft.NETCoreSdk.BundledVersions.props"

    if grep -qv freebsd-x64 src/Directory.Build.props; then
        sed -i'' -e "s^<RuntimeIdentifiers>\(.*\)</RuntimeIdentifiers>^<RuntimeIdentifiers>\1;freebsd-x64</RuntimeIdentifiers>^g" src/Directory.Build.props
    fi
}

SetExecutableBits()
{
    find . -name "ffprobe" -exec chmod a+x {} \;
    find . -name "Sonarr" -exec chmod a+x {} \;
    find . -name "Sonarr.Update" -exec chmod a+x {} \;
}

LintUI()
{
    ProgressStart 'ESLint'
    yarn lint
    ProgressEnd 'ESLint'

    ProgressStart 'Stylelint'
    yarn stylelint
    ProgressEnd 'Stylelint'
}

Build()
{
    ProgressStart 'Build'

    rm -rf $outputFolder
    rm -rf $testPackageFolder

    slnFile=src/Sonarr.sln

    if [ $os = "windows" ]; then
        platform=Windows
    else
        platform=Posix
    fi

    dotnet clean $slnFile -c Debug
    dotnet clean $slnFile -c Release

    if [[ -z "$RID" || -z "$FRAMEWORK" ]];
    then
        dotnet msbuild -restore $slnFile -p:Configuration=Release -p:Platform=$platform -t:PublishAllRids
    else
        dotnet msbuild -restore $slnFile -p:Configuration=Release -p:Platform=$platform -p:RuntimeIdentifiers=$RID -t:PublishAllRids
    fi

    ProgressEnd 'Build'
}

YarnInstall()
{
    ProgressStart 'yarn install'
    yarn install --frozen-lockfile --network-timeout 120000
    ProgressEnd 'yarn install'
}

RunWebpack()
{
    ProgressStart 'Running webpack'
    yarn run build --env production
    ProgressEnd 'Running webpack'
}

PackageFiles()
{
    local folder="$1"
    local framework="$2"
    local runtime="$3"

    rm -rf $folder
    mkdir -p $folder
    cp -r $outputFolder/$framework/$runtime/publish/* $folder
    cp -r $outputFolder/Sonarr.Update/$framework/$runtime/publish $folder/Sonarr.Update
    cp -r $outputFolder/UI $folder

    echo "Adding LICENSE"
    cp LICENSE.md $folder
}

PackageLinux()
{
    local framework="$1"
    local runtime="$2"

    ProgressStart "Creating $runtime Package for $framework"

    local folder=$artifactsFolder/$runtime/$framework/Sonarr

    PackageFiles "$folder" "$framework" "$runtime"

    echo "Removing Service helpers"
    rm -f $folder/ServiceUninstall.*
    rm -f $folder/ServiceInstall.*

    echo "Removing Sonarr.Windows"
    rm $folder/Sonarr.Windows.*

    echo "Adding Sonarr.Mono to UpdatePackage"
    cp $folder/Sonarr.Mono.* $folder/Sonarr.Update
    if [ "$framework" = "net6.0" ]; then
        cp $folder/Mono.Posix.NETStandard.* $folder/Sonarr.Update
        cp $folder/libMonoPosixHelper.* $folder/Sonarr.Update
    fi

    ProgressEnd "Creating $runtime Package for $framework"
}

PackageMacOS()
{
    local framework="$1"
    local runtime="$2"

    ProgressStart "Creating $runtime Package for $framework"

    local folder=$artifactsFolder/$runtime/$framework/Sonarr

    PackageFiles "$folder" "$framework" "$runtime"

    echo "Removing Service helpers"
    rm -f $folder/ServiceUninstall.*
    rm -f $folder/ServiceInstall.*

    echo "Removing Sonarr.Windows"
    rm $folder/Sonarr.Windows.*

    echo "Adding Sonarr.Mono to UpdatePackage"
    cp $folder/Sonarr.Mono.* $folder/Sonarr.Update
    if [ "$framework" = "net6.0" ]; then
        cp $folder/Mono.Posix.NETStandard.* $folder/Sonarr.Update
        cp $folder/libMonoPosixHelper.* $folder/Sonarr.Update
    fi

    ProgressEnd "Creating $runtime Package for $framework"
}

PackageMacOSApp()
{
    local framework="$1"
    local runtime="$2"

    ProgressStart "Creating $runtime App Package for $framework"

    local folder=$artifactsFolder/$runtime-app/$framework

    rm -rf $folder
    mkdir -p $folder
    cp -r distribution/macOS/Sonarr.app $folder
    mkdir -p $folder/Sonarr.app/Contents/MacOS

    echo "Copying Binaries"
    cp -r $artifactsFolder/$runtime/$framework/Sonarr/* $folder/Sonarr.app/Contents/MacOS

    echo "Removing Update Folder"
    rm -r $folder/Sonarr.app/Contents/MacOS/Sonarr.Update

    ProgressEnd "Creating $runtime App Package for $framework"
}

PackageWindows()
{
    local framework="$1"
    local runtime="$2"

    ProgressStart "Creating Windows Package for $framework"

    local folder=$artifactsFolder/$runtime/$framework/Sonarr

    PackageFiles "$folder" "$framework" "$runtime"
    cp -r $outputFolder/$framework-windows/$runtime/publish/* $folder

    echo "Removing Sonarr.Mono"
    rm -f $folder/Sonarr.Mono.*
    rm -f $folder/Mono.Posix.NETStandard.*
    rm -f $folder/libMonoPosixHelper.*

    echo "Adding Sonarr.Windows to UpdatePackage"
    cp $folder/Sonarr.Windows.* $folder/Sonarr.Update

    ProgressEnd "Creating Windows Package for $framework"
}

Package()
{
    local framework="$1"
    local runtime="$2"
    local SPLIT

    IFS='-' read -ra SPLIT <<< "$runtime"

    case "${SPLIT[0]}" in
        linux|freebsd*)
            PackageLinux "$framework" "$runtime"
            ;;
        win)
            PackageWindows "$framework" "$runtime"
            ;;
        osx)
            PackageMacOS "$framework" "$runtime"
            PackageMacOSApp "$framework" "$runtime"
            ;;
    esac
}

PackageTests()
{
    local framework="$1"
    local runtime="$2"

    ProgressStart "Creating $runtime Test Package for $framework"

    cp test.sh "$testPackageFolder/$framework/$runtime/publish"

    rm -f $testPackageFolder/$framework/$runtime/*.log.config

    ProgressEnd "Creating $runtime Test Package for $framework"
}

UploadTestArtifacts()
{
    local framework="$1"

    ProgressStart 'Publishing Test Artifacts'

    # Tests
    for dir in $testPackageFolder/$framework/*
    do
        local runtime=$(basename "$dir")
        echo "##teamcity[publishArtifacts '$testPackageFolder/$framework/$runtime/publish/** => tests.$runtime.zip']"
    done

    ProgressEnd 'Publishing Test Artifacts'
}

UploadArtifacts()
{
    local framework="$1"

    ProgressStart 'Publishing Artifacts'

    # Releases
    for dir in $artifactsFolder/*
    do
        local runtime=$(basename "$dir")
        local extension="tar.gz"

        if [[ "$runtime" =~ win-|-app ]]; then
            extension="zip"
        fi

        echo "##teamcity[publishArtifacts '$artifactsFolder/$runtime/$framework/** => Sonarr.$BRANCH.$BUILD_NUMBER.$runtime.$extension']"
    done

    # Debian Package
    echo "##teamcity[publishArtifacts 'distribution/** => distribution.zip']"

    ProgressEnd 'Publishing Artifacts'
}

BuildDocker()
{
    ProgressStart 'Building Docker Image'
    VERSION=$(jq -r '.version' ./root/VERSION.json)
    docker build . -t "drapersniper/sonarr:latest" -t "drapersniper/sonarr:v$VERSION"
    
    ProgressEnd 'Building Docker Image'
}

PushDocker()
{
    ProgressStart 'Publishing Docker Images'

    docker push drapersniper/sonarr -a
    
    ProgressEnd 'Publishing Docker Images'
}

UpdateHotioVersion()
{
  DISCORD=$(jq -r '.arr_discord_notifier_version' ./root/VERSION.json)
  BRANCH=$(jq -r '.sbranch' ./root/VERSION.json)
  sed -i -e "s/ENV VERSION=.*/ENV VERSION=$buildVersion/g" ./Dockerfile
  sed -i -e "s/ENV ARR_DISCORD_NOTIFIER_VERSION=.*/ENV ARR_DISCORD_NOTIFIER_VERSION=$DISCORD/g" ./Dockerfile
  sed -i -e "s/ENV SBRANCH=.*/ENV SBRANCH=$BRANCH/g" ./Dockerfile
}

GitUpdate()
{
  MoveIntoFolder
  git commit -a -m "Updating post build - VERSION=$buildVersion BRANCH=$BRANCH"
  git push
  git restore .

}
UpdateProject()
{
    MoveIntoFolder
    git fetch
    git pull --rebase
}


# Use mono or .net depending on OS
case "$(uname -s)" in
    CYGWIN*|MINGW32*|MINGW64*|MSYS*)
        # on windows, use dotnet
        os="windows"
        ;;
    *)
        # otherwise use mono
        os="posix"
        ;;
esac

POSITIONAL=()

if [ $# -eq 0 ]; then
    echo "No arguments provided, building everything"
    BACKEND=YES
    FRONTEND=YES
    PACKAGES=YES
    LINT=YES
    ENABLE_BSD=NO
fi

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --backend)
        BACKEND=YES
        shift # past argument
        ;;
    --enable-bsd)
        ENABLE_BSD=YES
        shift # past argument
        ;;
    -r|--runtime)
        RID="$2"
        shift # past argument
        shift # past value
        ;;
    -f|--framework)
        FRAMEWORK="$2"
        shift # past argument
        shift # past value
        ;;
    --frontend)
        FRONTEND=YES
        shift # past argument
        ;;
    --packages)
        PACKAGES=YES
        shift # past argument
        ;;
    --lint)
        LINT=YES
        shift # past argument
        ;;
    --all)
        BACKEND=YES
        FRONTEND=YES
        PACKAGES=YES
        LINT=YES
        shift # past argument
        ;;
    *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters
UpdateProject
FetchLatestVersion
if [ "$BACKEND" = "YES" ];
then
    UpdateVersionNumber

    if [ "$ENABLE_BSD" = "YES" ];
    then
        EnableBsdSupport
    fi

    Build

    UploadTestArtifacts "net6.0"
fi

if [ "$FRONTEND" = "YES" ];
then
    YarnInstall
    RunWebpack
fi

if [ "$LINT" = "YES" ];
then
    if [ -z "$FRONTEND" ];
    then
        YarnInstall
    fi

    LintUI
fi

if [ "$PACKAGES" = "YES" ];
then
    UpdateVersionNumber
    SetExecutableBits

    if [[ -z "$RID" || -z "$FRAMEWORK" ]];
    then
        Package "net6.0" "linux-x64"
        if [ "$ENABLE_BSD" = "YES" ];
        then
            Package "net6.0" "freebsd-x64"
        fi
    else
        Package "$FRAMEWORK" "$RID"
    fi

    UploadArtifacts "net6.0"
fi

UpdateHotioVersion
BuildDocker
PushDocker
GitUpdate