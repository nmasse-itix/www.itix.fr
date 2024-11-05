#!/bin/bash

set -Eeuo pipefail

magick grafana-leaderboard-instant-snapshot-{query,transform}.png -append ../grafana-opencodequest-leaderboard-instant-snapshot.png

