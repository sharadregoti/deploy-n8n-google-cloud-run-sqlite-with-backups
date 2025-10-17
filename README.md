# Deploy n8n on Google Cloud Run with SQLite and Automated Backups

This project provides a Docker-based solution for deploying n8n on Google Cloud Run with SQLite database support and automated backups to Google Cloud Storage.

## Features

- 🚀 Deploy n8n on Google Cloud Run
- 💾 SQLite database support for data persistence
- 🔄 Automated backups to Google Cloud Storage
- 🔁 Automatic workflow and credentials restoration on container startup
- 🔒 Support for Google Cloud service account authentication
- 🕒 Configurable backup intervals

## Prerequisites

- Google Cloud Project with Cloud Run and Cloud Storage enabled
- Google Cloud Storage bucket for backups
- (Optional) Google Cloud service account with necessary permissions
- Docker installed locally for testing

## Environment Variables

### Required Variables
- `RCLONE_REMOTE`: Name of the rclone remote configuration (e.g., "n8n-gcs")

### Optional Variables
- `GOOGLE_APPLICATION_CREDENTIALS`: Path to service account key file
- `GOOGLE_CLOUD_PROJECT`: Google Cloud project number
- `BACKUP_BUCKET`: GCS bucket name (default: "my-n8n-backups")
- `BACKUP_PREFIX`: Prefix for backup files in bucket (default: "backups")
- `BACKUP_DIR`: Local directory for temporary backup files (default: "/tmp/n8n-backup")
- `BACKUP_INTERVAL_SEC`: Interval between backups in seconds (default: 3600)

## Setup Instructions

1. Create a Google Cloud Storage bucket for backups
2. Configure environment variables
3. Deploy to Google Cloud Run:
   ```bash
   gcloud run deploy n8n \
     --image n8nio/n8n:1.115.3 \
     --platform managed \
     --region YOUR_REGION \
     --set-env-vars "RCLONE_REMOTE=n8n-gcs,BACKUP_BUCKET=your-bucket-name"
   ```

## Backup System

The backup system automatically:
- Exports all workflows and credentials
- Uploads backups to Google Cloud Storage
- Maintains a "latest" version for quick recovery
- Cleans up local backup files older than 3 days
- Restores workflows and credentials on container startup

### Backup File Structure
```
bucket/
└── backups/
    ├── latest/
    │   ├── workflows.json
    │   └── credentials.json
    └── YYYY-MM-DDThh-mm-ssZ/
        ├── workflows-TIMESTAMP.json
        └── credentials-TIMESTAMP.json
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
