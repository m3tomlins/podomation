#!/bin/bash
upload="true"
for episode in $(ls -1d episodes/* | egrep -v "@ea"); do
	/bin/bash podomate.sh $(basename ${episode}) true
done
