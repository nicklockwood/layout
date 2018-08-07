if [[ -z "${TRAVIS}" ]]; then
    swiftformat . --cache ignore
    LayoutTool/LayoutTool format .
fi
