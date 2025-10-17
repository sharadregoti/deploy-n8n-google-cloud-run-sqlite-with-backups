# TODO change docker tag to 1.115.3 after testing
FROM n8nio/n8n:latest

# Install node deps for the backup script (small helper)
USER root
RUN wget https://github.com/rclone/rclone/releases/download/v1.71.1/rclone-v1.71.1-linux-amd64.zip \
    && unzip rclone-v1.71.1-linux-amd64.zip \
    && cp rclone-v1.71.1-linux-amd64/rclone /usr/bin/rclone \
    && chmod 755 /usr/bin/rclone \
    && rm -rf rclone-v1.71.1-linux-amd64*

# Copy helper scripts

COPY entrypoint.sh /entrypoint.sh
COPY backup.sh /backup.sh

RUN chmod +x /entrypoint.sh /backup.sh && chown node:node /entrypoint.sh /backup.sh

USER node
WORKDIR /home/node

# explicitly run entrypoint with /bin/sh (works even if script shebang is missing or non-existent interpreter)
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
