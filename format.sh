!# /usr/bin/env bash

if [[ -z "${TRAVIS}" ]]; then
    swiftformat . --exclude "Pods,Layout/Vendor,LayoutTool/Symbols.swift" --header "//  Copyright © {year} Schibsted. All rights reserved." --binarygrouping 8,8 --decimalgrouping ignore
    LayoutTool/LayoutTool format .
fi
