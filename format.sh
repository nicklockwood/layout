!# /usr/bin/env bash

if [[ -z "${TRAVIS}" ]]; then
    swiftformat . --exclude "Pods,Layout/Vendor,LayoutTool/Symbols.swift" --header "//  Copyright © 2017 Schibsted. All rights reserved." --binarygrouping 8,8 --decimalgrouping ignore --disable sortedImports --cache ignore
    LayoutTool/LayoutTool format .
fi
