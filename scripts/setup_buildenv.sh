set -o errexit

prepare_for_src_from_github () {
  # $1: a path to a local directory where the required source should be stored
  # $2: a git link to a remote repository hosting the required source
  # $3: a branch/tag name

  echo "Preparing \"$1\"..."

  if [[ ! -d "$1" ]]; then
    git clone "$2" --single-branch --branch "$3" "$1"

    PATCH_PATH="/workdir/patches/$(basename "$1").gitpatch"
    if [[ -f "${PATCH_PATH}" ]]; then
      echo "Patching \"$1\"..."
      pushd "$1" > /dev/null
      git apply "${PATCH_PATH}"
      popd > /dev/null
    fi
  fi

}


prepare_for_src_from_tarball () {
  # $1: a path to a local directory where the required source should be stored
  # $2: a link to the tgz version of the required source at a remote repository

  echo "Preparing \"$1\"..."

  if [[ ! -d "$1" ]]; then
    curl -LO "$2" --output-dir "/tmp"
    tar -zxf "/tmp/$(basename "$2")" --one-top-level="$1" --strip-components=1
    rm "/tmp/$(basename "$2")"

    PATCH_PATH="/workdir/patches/$(basename "$1").diffpatch"
    if [[ -f "${PATCH_PATH}" ]]; then
      echo "Patching \"$1\"..."
      patch -d "$1" -p1 < "${PATCH_PATH}"
    fi
  fi

}

if [[ ! -d "/workdir" ]]; then
  echo "The directory \"/workdir\" does not exist!"
  exit -1
fi
mkdir -p "/workdir/src"


