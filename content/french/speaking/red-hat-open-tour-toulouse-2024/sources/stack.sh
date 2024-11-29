#!/bin/bash

set -Eeuo pipefail

magick DSCF0991.jpeg DSCF0994.jpeg DSCF0992.jpeg +append ../participants.jpeg
magick DSCF0980.jpeg DSCF0962.jpeg DSCF0976.jpeg +append ../mas-tolosa.jpeg
