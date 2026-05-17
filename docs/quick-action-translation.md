# Translate selection via Quick Action

This Quick Action uses native macOS Services to extract selected text without requiring accessibility permissions. It copies the text to the clipboard and launches the tpopup app.

### Create the Quick Action

- Open Automator and create a new Quick Action.
- Set "Workflow receives current" to "text" in "any application".

### Add shell script

- Drag a "Run Shell Script" action into the workflow.
- Set "Pass input" to "to stdin".
- Paste the following script:

```sh
cat | pbcopy
open -a /Applications/tpopup.app --args -translate
```

### Save and bind shortcut

- Save the workflow as `Translation Popup`.
- Open System Settings, go to Keyboard, Keyboard Shortcuts, and then Services.
- Find `Translation Popup` under the Text section and assign your keyboard shortcut `Option+Command+T`.