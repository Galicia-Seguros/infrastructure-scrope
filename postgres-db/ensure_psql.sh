#!/bin/bash

CLI=$(which uuidgen)
if [[ "$CLI" == "" ]]; then
    apk add uuidgen
fi