#! /bin/sh

set -ex

ci_dir="$(cd "$(dirname "$0")" && echo "$(pwd -P)/")"
script_dir="$(dirname "$ci_dir")"
src_dir="$(dirname "$script_dir")"
cd "$src_dir"

. "$script_dir"/version.sh

# build_image and base_image are both built by the CI for the
# repository https://gitlab.com/mineplex/opam-repository
# same prefix, but different tags. The build image is identified
# by the commit reference only, while the base image is
# identified by the prefix "minimal--" followed by the same
# commit reference of the build image.

image_name="${1:-mineplex}"
image_version="${2:-latest}"
build_image="${3:-registry.gitlab.com/mineplex/opam-repository}"
base_image="${4-registry.gitlab.com/mineplex/opam-repository}"
base_version="${5-minimal--${opam_repository_tag}}"
commit_short_sha="${6:-$(git rev-parse --short HEAD)}"

echo
echo "### Building minimal docker images..."
echo

docker build \
  -t "$image_name-debug:$image_version" \
  --build-arg "BASE_IMAGE=$base_image" \
  --build-arg "BASE_IMAGE_VERSION=$base_version" \
  --build-arg "BASE_IMAGE_VERSION_NON_MIN=$opam_repository_tag" \
  --build-arg "BUILD_IMAGE=${build_image}" \
  --build-arg "BUILD_IMAGE_VERSION=${image_version}" \
  --build-arg "COMMIT_SHORT_SHA=${commit_short_sha}" \
  --target=debug \
  "$src_dir"

echo
echo "### Successfully build docker image: $image_name-debug:$image_version"
echo

docker build \
  -t "$image_name-bare:$image_version" \
  --build-arg "BASE_IMAGE=$base_image" \
  --build-arg "BASE_IMAGE_VERSION=$base_version" \
  --build-arg "BUILD_IMAGE=${build_image}" \
  --build-arg "BUILD_IMAGE_VERSION=${image_version}" \
  --build-arg "BASE_IMAGE_VERSION_NON_MIN=$opam_repository_tag" \
  --build-arg "COMMIT_SHORT_SHA=${commit_short_sha}" \
  --target=bare \
  "$src_dir"


echo
echo "### Successfully build docker image: $image_name-bare:$image_version"
echo

docker build \
  -t "$image_name:$image_version" \
  --build-arg "BASE_IMAGE=$base_image" \
  --build-arg "BASE_IMAGE_VERSION=$base_version" \
  --build-arg "BUILD_IMAGE=${build_image}" \
  --build-arg "BUILD_IMAGE_VERSION=${image_version}" \
  --build-arg "BASE_IMAGE_VERSION_NON_MIN=$opam_repository_tag" \
  --build-arg "COMMIT_SHORT_SHA=${commit_short_sha}" \
  "$src_dir"

echo
echo "### Successfully build docker image: $image_name:$image_version"
echo
