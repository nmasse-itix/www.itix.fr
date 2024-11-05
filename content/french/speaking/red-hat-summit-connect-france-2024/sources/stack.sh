#!/bin/bash

set -Eeuo pipefail

magick open-code-quest-winners-{1,2,3}.jpeg +append ../open-code-quest-winners.jpeg

