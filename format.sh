!# /usr/bin/env bash

if [[ -z "${TRAVIS}" ]]; then
    swiftformat . --exclude "Pods,Layout/Expression.swift,LayoutTool/Symbols.swift" --header "//  Copyright © {year} Schibsted. All rights reserved." --binarygrouping 8,8
fi
