#!/bin/bash

# Mail someone when a job finishes

if [[ -n $1 ]]; then
    user=$1
else
    echo "Usage: mailme.sh user-address"
    exit 1
fi

echo "$(date) job done in $(pwd) with exit status $?" | \
    mail -s "Job done in $(pwd)" $user -- -f $user
