#!/bin/sh

gh repo list sevencooks-gmbh-co-kg -L 1000 --json sshUrl --jq '.[].sshUrl' | xargs -L1 git clone