# Lessons

- **Answer a direct question at the end of the turn.** I answered "how do I launch the app" at the start of a long turn, then did 20 tool calls. The user asked the same question again. When a turn has a question and work, put the answer in the final message too.
- **Size estimates: count the rules, not only the feature.** I estimated the settings window at 70 lines. It took 200, because the agreed rules added validation, a layout-aware label and the hot key pause. Estimate after the rules are known, and give a range.
- **No second source file without a build system.** Without an Xcode project or a Package, SourceKit analyses each file alone and shows false "cannot find in scope" errors. Check the editor diagnostics before a file split.
- **zsh does not split an unquoted variable.** `swiftc $FLAGS` passes one argument. Write the flags inline, or use `${=FLAGS}`.
- **Stacked pull requests do not move to `main` by themselves.** I told the user that GitHub moves the next pull request to `main` after each merge. It does that only when the merged branch is deleted. The user merged #1, #2 and #3: only #1 got to `main`, the others merged into their base branches. With a solo repo, open each pull request against `main`, one at a time, or say "delete the branch after the merge". After the user says "merged", check `origin/main` before the next step.
