# ZeroTier Static Docker

Statically-linked ZeroTier One binaries and Docker images that work on any Linux system, including Alpine Linux and minimal containers.

## Why This Exists

### The Problem

- **Official Docker Image**: The [official ZeroTier Docker image](https://hub.docker.com/r/zerotier/zerotier) uses Debian and installs ZeroTier via `apt`, resulting in a large image with dynamic dependencies.
- **Alpine Linux**: If you're using Alpine Linux, running ZeroTier is challenging because:
  - There's no official Alpine support
  - The version in Alpine's `apk` repository is outdated
  - Copying ZeroTier binaries from Debian won't work due to dynamic linking against glibc

### The Solution

This project provides:
1. **Statically-linked binaries** that work on any Linux distribution (including Alpine, BusyBox, etc.)
2. **Small Docker images** built on Alpine Linux
3. **Easy builds** - anyone can build the binaries using Docker, ensuring reproducibility

## Quick Start

### Using Pre-built Binaries

Download the latest release for your architecture:

```bash
# For x86_64 / amd64
VERSION=1.16.0
wget https://github.com/charlie0129/zerotier-static-docker/releases/latest/download/zerotier-static-$VERSION-amd64.tar.gz
tar -xzf zerotier-static-$VERSION-amd64.tar.gz
sudo cp -d zerotier-* /usr/local/bin/

# For ARM64
wget https://github.com/charlie0129/zerotier-static-docker/releases/latest/download/zerotier-static-$VERSION-arm64.tar.gz
tar -xzf zerotier-static-$VERSION-arm64.tar.gz
sudo cp -d zerotier-* /usr/local/bin/
```

### Using Docker

> Same as the official ZeroTier image, but with smaller image size. https://hub.docker.com/r/zerotier/zerotier

Run ZeroTier in a container:

```bash
docker run -d \
  --name zerotier \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -v /var/lib/zerotier-one:/var/lib/zerotier-one \
  ghcr.io/charlie0129/zerotier-static-docker:latest \
  <network-id>
```

Or with Docker Compose:

```yaml
version: '3'
services:
  zerotier:
    image: ghcr.io/charlie0129/zerotier-static-docker:latest
    container_name: zerotier
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    volumes:
      - /var/lib/zerotier-one:/var/lib/zerotier-one
    command: <network-id>
    restart: unless-stopped
```

### Building Locally

Build for your current architecture:

```bash
docker build -t zerotier-static .
```

Build for a specific ZeroTier version:

```bash
docker build --build-arg ZEROTIER_VERSION=1.16.0 -t zerotier-static .
```

Extract the binaries:

```bash
docker create --name temp zerotier-static
docker cp temp:/usr/sbin/zerotier-one ./
docker rm temp

ln -sf zerotier-one zerotier-cli
ln -sf zerotier-one zerotier-idtool
```

## What's Included

The build produces three statically-linked binaries:

- **`zerotier-one`** - The main ZeroTier service daemon
- **`zerotier-cli`** - Command-line interface for managing ZeroTier (symlink to `zerotier-one`)
- **`zerotier-idtool`** - Tool for generating and managing ZeroTier identities (symlink to `zerotier-one`)

All binaries are statically linked against musl libc and have no external dependencies.

## Usage

### Joining a Network

```bash
# Using Docker
docker exec zerotier zerotier-cli join <network-id>

# Using standalone binaries
sudo zerotier-one -d  # Start daemon
zerotier-cli join <network-id>
```

### Acting as Moon

The following example uses standalone binaries. Adjust commands accordingly for Docker.

```bash
zerotier-idtool initmoon /var/lib/zerotier-one/identity.public >>/var/lib/zerotier-one/moon.json
zerotier-idtool genmoon /var/lib/zerotier-one/moon.json
mkdir -p /var/lib/zerotier-one/moons.d/
mv *.moon /var/lib/zerotier-one/moons.d/
# Restart ZeroTier to load the moon configuration
```

### Common Commands

```bash
# Check status
zerotier-cli status

# List networks
zerotier-cli listnetworks

# Leave a network
zerotier-cli leave <network-id>

# Show node info
zerotier-cli info
```

### Environment Variables

The Docker entrypoint supports several environment variables:

- `ZEROTIER_API_SECRET` - Set a custom API secret
- `ZEROTIER_IDENTITY_PUBLIC` - Use an existing identity (public key)
- `ZEROTIER_IDENTITY_SECRET` - Use an existing identity (secret key)
- `ZEROTIER_LOCAL_CONF` - Custom local.conf content

Example:

```bash
docker run -d \
  --name zerotier \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -e ZEROTIER_API_SECRET=mysecret \
  -v /var/lib/zerotier-one:/var/lib/zerotier-one \
  ghcr.io/charlie0129/zerotier-static-docker:latest \
  <network-id>
```

## Advanced Build Options

### Build Arguments

- `ZEROTIER_VERSION` - ZeroTier version to build (default: 1.16.0)
- `BUILD_IMAGE` - Base image for building (default: alpine:3.23)
- `BASE_IMAGE` - Base image for final container (default: alpine:3.23)
- `APK_MIRROR` - Alpine package mirror (for faster builds in China, etc.)
- `RUSTUP_DIST_SERVER` - Rust toolchain mirror
- `HTTPS_PROXY` - Proxy for downloading sources

Example with mirrors:

```bash
docker build \
  --build-arg APK_MIRROR=mirrors.ustc.edu.cn \
  --build-arg RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static \
  --build-arg HTTPS_PROXY=http://proxy.example.com:8080 \
  -t zerotier-static .
```

### Multi-architecture Builds

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t zerotier-static:latest \
  --push .
```

## GitHub Actions

This repository includes automated workflows:

### Docker Image Publishing

The `docker-build-push.yml` workflow automatically builds and pushes Docker images to:
- GitHub Container Registry (ghcr.io)
- Docker Hub

**To change the ZeroTier version**, edit the `ZEROTIER_VERSION` environment variable in `.github/workflows/docker-build-push.yml`:

```yaml
env:
  # Edit this to change the ZeroTier version
  ZEROTIER_VERSION: "1.16.0"
```

Or trigger a manual build with a custom version via the Actions tab.

### Static Binary Releases

The `release-static-binaries.yml` workflow builds static binaries and creates GitHub releases.

**To create a new release:**

1. Push a tag (e.g., `v1.16.0`)
2. Go to Actions → "Build and Release Static Binaries" → "Run workflow". Make sure to select the tag in `Use workflow from`.
3. Enter the ZeroTier version and release tag
4. The workflow will build binaries for all architectures and create a release

Or push a tag:

```bash
git tag v1.16.0
git push origin v1.16.0
```

## Configuration for Your Repository

### Docker Hub Setup

To push to Docker Hub, add these secrets to your repository:

- `DOCKERHUB_USERNAME` - Your Docker Hub username
- `DOCKERHUB_TOKEN` - Docker Hub access token

Then update the image name in `.github/workflows/docker-build-push.yml`:

```yaml
images: |
  ghcr.io/${{ github.repository }}
  YOUR-DOCKERHUB-USERNAME/zerotier-static
```

## Verification

Verify that binaries are statically linked:

```bash
# Should show "statically linked"
file zerotier-one

# Should fail with "not a dynamic executable"
ldd zerotier-one
```

## Use Cases

Perfect for:
- **Alpine Linux** containers and systems
- **Minimal containers** (distroless, scratch-based)
- **Embedded systems** with limited space
- **Air-gapped environments** where you can't install dependencies
- **Kubernetes sidecars** for pod networking
- **Any Linux system** where you want zero dependencies

## License

This project builds and packages [ZeroTier One](https://github.com/zerotier/ZeroTierOne), which is licensed under the https://github.com/zerotier/ZeroTierOne/blob/main/LICENSE.txt.

The Docker configuration and build scripts in this repository are provided as-is for convenience.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Related Projects

- [ZeroTier One](https://github.com/zerotier/ZeroTierOne) - Official ZeroTier client
- [Official Docker Image](https://hub.docker.com/r/zerotier/zerotier) - Debian-based official image

## Support

For ZeroTier-specific issues, please refer to the [official documentation](https://docs.zerotier.com/) and [ZeroTier repository](https://github.com/zerotier/ZeroTierOne).

For issues with this build setup, please open an issue in this repository.
