build:
    fork-assembler build

status:
    fork-assembler status

continue:
    fork-assembler continue

# Push the assembled tree to the [publish] branch and tag it.
publish:
    scripts/publish-assembly.sh
