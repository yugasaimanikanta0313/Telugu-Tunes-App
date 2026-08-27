# Oracle backend deployment

The GitHub Actions workflow builds and tests the backend on GitHub-hosted infrastructure, publishes
an amd64 image to GitHub Container Registry, and deploys it to the small Oracle VM. The VM never
runs Maven or a Docker build.

## One-time server configuration

Create `/opt/telugu-tunes/backend.env` from `backend.env.example` and fill it directly on the VM.
The production file must never be copied into this repository. The container is limited to 700 MB
of memory and Java is limited to a 384 MB heap.

## Required GitHub environment secrets

Create an environment named `oracle-production`, then add:

- `ORACLE_HOST`: the Oracle VM public IP address.
- `ORACLE_SSH_PRIVATE_KEY`: the entire private SSH key generated for the VM.

After the environment and server file exist, run **Deploy backend to Oracle** from the repository's
Actions page or push a backend change to `main`.
