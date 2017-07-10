!# /usr/bin/env bash

if [[ -z "${TRAVIS}" ]]; then
    swiftformat . --exclude "Pods,Layout/Expression.swift,Layout/AnyExpression.swift" --header "//  Copyright © {year} Schibsted. All rights reserved."
fi
