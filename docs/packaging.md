# How to release gittree

A release is four things: the version bump on `master`, an annotated tag, the files on the GitHub releases page, and a source upload to the PPA for each Ubuntu release.

Everything up to the upload runs from a checkout. The upload needs a key and an account that only you have.

## Current state

- `debian/` is complete. Lintian shows one tag at `--pedantic --info`, `binary-nmu-debian-revision-in-source`, which the `~ubuntuNN.NN.1` suffix causes.
- The `.deb` builds in the `build` stage of the container, which holds only the packaging tools and the build dependencies that `debian/control` declares. A Launchpad builder makes the same check.
- Install, run, remove and purge are verified in unmodified `ubuntu:24.04` and `ubuntu:26.04` containers.
- The package is `gittree`. The commands are `gittree` and `git-tree`. It is built for **noble** (24.04) and **resolute** (26.04).

## Preliminary steps

You must do these steps yourself. The first four are necessary one time only, and they are done if you publish other PPAs already.

1. **A Launchpad account.** <https://launchpad.net/+login>
2. **A GPG key, registered with Launchpad.** If you do not have one:

   ```bash
   gpg --full-generate-key
   gpg --list-secret-keys --keyid-format=long
   gpg --send-keys --keyserver keyserver.ubuntu.com <KEYID>
   ```

   Then add its fingerprint at <https://launchpad.net/~/+editpgpkeys>, and confirm the encrypted email that Launchpad sends.
3. **An SSH key registered** at <https://launchpad.net/~/+editsshkeys>.
4. **The Ubuntu Code of Conduct, signed** at <https://launchpad.net/codeofconduct>. Launchpad refuses PPA uploads without it.
5. **The PPA** `ppa:li9i/gittree`, made at <https://launchpad.net/~li9i/+activate-ppa>. The PPA has no setting for the releases of Ubuntu. It builds for the release that each upload names.

The maintainer address in `debian/control` and `debian/changelog` is `alexandros filotheou <alexandros.filotheou@gmail.com>`. `debsign` selects a signing key by that address. If your key does not have it, `debsign` refuses after the source package is built. Examine your keys with `gpg --list-secret-keys --keyid-format=long`, then add the address as a UID (`gpg --edit-key <ID>`, then `adduid`), or give `-k <KEYID>`.

## Cut the release

Work on a clean tree.

1. Run the tests:

   ```bash
   ./scripts/dev.sh test
   ```

2. Bump `version` in `meson.build`, and the date in the first line of `data/gittree.1.in`.
3. Add a `<release>` entry at the top of the `<releases>` block in `data/io.github.li9i.gittree.metainfo.xml.in`. `meson test --suite data` validates it.
4. Add an entry at the top of `debian/changelog`. Keep `noble` as the distribution and `-1` as the revision. `docker/build-deb.sh` and `docker/build-source.sh` write both for each release at build time.
5. Commit the four files as `Release X.Y.Z`, tag the commit, and push both:

   ```bash
   git tag -a vX.Y.Z
   git push origin master
   git push origin vX.Y.Z
   ```

   The tag annotation is the text of the release.

## Build the files

Empty `_build/deb/` first, so that the checks and the release cannot take a file of an earlier version.

```bash
rm -rf _build/deb
./scripts/build-deb.sh 24.04
./scripts/build-deb.sh 26.04
./scripts/build-appimage.sh
```

A `.deb` links the libraries of the release it was built on, so each release has its own container.

## Check the files

```bash
./tests/packaging/test-orig.sh
./tests/packaging/test-lintian.sh _build/deb/gittree_X.Y.Z-1~ubuntu24.04.1_amd64.changes
./tests/packaging/test-lintian.sh _build/deb/gittree_X.Y.Z-1~ubuntu26.04.1_amd64.changes
./tests/packaging/test-install.sh _build/deb/gittree_X.Y.Z-1~ubuntu24.04.1_amd64.deb
./tests/packaging/test-install.sh _build/deb/gittree_X.Y.Z-1~ubuntu26.04.1_amd64.deb
./tests/packaging/test-appimage.sh
./tests/packaging/test-appimage.sh gittree-X.Y.Z-x86_64.AppImage ubuntu:26.04
```

`test-orig.sh` compares the source tarball with the files that git tracks. It must show no difference: a file in the tarball that git does not track is published on Launchpad for anyone to download.

## Publish on GitHub

```bash
git tag -l vX.Y.Z --format='%(contents:body)' > notes.md

gh release create vX.Y.Z --title "gittree X.Y.Z" --verify-tag \
    --notes-file notes.md --generate-notes \
    gittree-X.Y.Z-x86_64.AppImage \
    _build/deb/gittree_X.Y.Z-1~ubuntu24.04.1_amd64.deb \
    _build/deb/gittree_X.Y.Z-1~ubuntu26.04.1_amd64.deb
```

GitHub writes `~` as `.` in the names of the files it stores. The instructions in `README.md` name no version, so a release does not change them.

## Build and sign the source package

A PPA takes a source upload and builds the binary package itself. The `.deb` files that you build locally are for the checks and the GitHub release only. You do not upload them.

`docker/build-source.sh` makes a source `.changes` for one release. A source package links no library, so the two runs use the same container:

```bash
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
    -v "$PWD:/src" -w /src gittree-build:24.04 \
    ./docker/build-source.sh noble '~ubuntu24.04.1'

docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
    -v "$PWD:/src" -w /src gittree-build:24.04 \
    ./docker/build-source.sh resolute '~ubuntu26.04.1'
```

The first run writes `gittree_X.Y.Z.orig.tar.gz` to `_build/ppa/` and keeps it there. The second run uses it again, so the two releases upload the same tarball. Check it, and each source package:

```bash
./tests/packaging/test-orig.sh _build/ppa/gittree_X.Y.Z.orig.tar.gz
./tests/packaging/test-lintian.sh _build/ppa/gittree_X.Y.Z-1~ubuntu24.04.1_source.changes
./tests/packaging/test-lintian.sh _build/ppa/gittree_X.Y.Z-1~ubuntu26.04.1_source.changes
```

Then sign, on the host, where your GPG key is:

```bash
debsign -k <KEYID> _build/ppa/gittree_X.Y.Z-1~ubuntu*_source.changes
```

`docker/build-source.sh` builds unsigned. The container has no access to your key, and it must not have access.

## Upload

```bash
dput ppa:li9i/gittree _build/ppa/gittree_X.Y.Z-1~ubuntu*_source.changes
```

This uploads both releases. Give the version in the name, because `_build/ppa` also keeps the files of earlier releases. Run it on the host: it needs your key and your account.

## After the upload

1. Watch the builds at <https://launchpad.net/~li9i/+archive/ubuntu/gittree/+packages>. A build starts after some minutes.
2. Read the build log, also when the build succeeds. The builder is a cleaner place than the container, and a warning there matters.
3. Install from the real PPA on a clean machine one time:

   ```bash
   sudo add-apt-repository ppa:li9i/gittree
   sudo apt-get update
   sudo apt-get install gittree
   gittree --version
   ```

## Known problems

- **Launchpad never accepts a version twice**, also after a failed build. Raise the revision to `-2` and upload again.
- **The `orig.tar.gz` is uploaded one time only.** Later Debian revisions of the same upstream version must not include it, or Launchpad refuses the upload for a file conflict. Keep `_build/ppa` between revisions: `docker/build-source.sh` then uses the kept tarball and does not pass `-sa`.
- **`Distribution` in `debian/changelog` must agree with the PPA's release.** An upload for a release that the PPA does not build is discarded with no message. `docker/build-deb.sh` and `docker/build-source.sh` write that line from their first argument, so pass them the codename (`noble`, `resolute`). `scripts/build-deb.sh` takes the version (`24.04`, `26.04`) and passes the codename itself.
- **The source package holds only the tracked files**, with their contents from the working tree. A new file goes into it only after `git add`.

## Releases of Ubuntu

The vendored source agrees with gitg 44 (`vendor/PROVENANCE`). Noble carries `44-1build2`. Before you add a release of Ubuntu, make sure it carries gitg 44 too. `Dockerfile.visual` asserts noble's exact version, so the pixel suite runs on the noble image only.

To add a release, add its version and codename to `scripts/build-deb.sh`, build with `./scripts/build-deb.sh <version>`, and upload the `.changes` that names it.
