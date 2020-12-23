#!/usr/bin/env python

import os
import sys

# Dirty hack for netlify that don't ship the realpath command
print(os.path.realpath(sys.argv[1]))
