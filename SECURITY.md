# Security policy

The unified development container mounts the host Docker socket and therefore
has control of the host Docker daemon. Run it only with trusted source and
review changes to Dockerfiles, entrypoints, update installers, download URLs,
hashes, and release scripts carefully.

Do not publish credentials, signing material, private appdata, recordings, or
working exploits in an issue. Use GitHub private vulnerability reporting when
available. If it is unavailable, request private maintainer contact in an issue
without including vulnerability details.
