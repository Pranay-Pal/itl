# iOS setup for share_handler

These steps enable receiving shares (text/files/images) on iOS using the `share_handler` plugin. They require Xcode because an iOS Share Extension is a separate target.

Prerequisites:
- Xcode installed on macOS
- An Apple developer team to enable App Groups (for passing data between the extension and the app)

Steps:

1) Add an App Group
- In Xcode, open `ios/Runner.xcworkspace`.
- Select the Runner project > Runner target > Signing & Capabilities.
- Click "+ Capability" and add "App Groups".
- Create a new App Group, e.g., `group.com.yourcompany.itl`.
- Note this identifier; you'll use the same for the Share Extension.

2) Create a Share Extension target
- File > New > Target… > "Share Extension" (under iOS > Application Extension).
- Name it something like "ShareExtension".
- Set the Bundle Identifier (e.g., `com.yourcompany.itl.shareextension`).
- Finish and ensure it’s added to the same project.

3) Configure the Share Extension
- Select the new ShareExtension target > Signing & Capabilities.
- Add the same "App Groups" capability.
- Select the same group created earlier (e.g., `group.com.yourcompany.itl`).
- In the extension's `Info.plist`, ensure NSExtension is present with types you want to receive (public.image, public.movie, public.data, public.url, public.plain-text).

4) Configure the main app (Runner)
- Ensure the Runner target has the same App Group in Signing & Capabilities.
- In `ios/Runner/Info.plist`, usually no changes are required beyond default. If your app needs additional permissions for file access, add them as required.

5) Link share_handler to the app group
- In Dart, ensure you pass the correct app group if needed (most recent versions auto-detect with the plugin's iOS code, but if you forked, verify the group identifier matches what `share_handler` expects).

6) Build & run
- Run `pod install` by building via Xcode or running `flutter build ios` (which runs CocoaPods).
- Launch the app on a device. Use the iOS Share Sheet in another app and pick your Share Extension. The extension will hand off to the main app via the shared app group store when the app is opened.

Troubleshooting
- If the extension appears but nothing arrives in the app, confirm both targets use the exact same App Group.
- If the extension does not show in the Share Sheet, ensure its Info.plist NSExtensionActivationRule allows your content types (images/files/text/URLs).
- Clean build folder in Xcode if changes don’t apply (Product > Clean Build Folder).

References
- https://pub.dev/packages/share_handler
- Apple Docs: App Extensions, App Groups
