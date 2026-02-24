#!/bin/bash
# Start the database migration
/app/bin/haru eval "HaruCore.Release.migrate"

# Start the Phoenix app
exec /app/bin/haru start
