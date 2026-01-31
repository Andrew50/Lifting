Option A — “Build & Run” from Xcode (most standard)

You use a normal Apple Account (free) + Xcode to install a dev build directly onto your phone.

What to expect with the free route:

The app’s provisioning profile expires after 7 days, so you’ll need to plug in and “Run” again weekly to keep it launching.

Free accounts also have limits like a small number of test devices / App IDs (Apple documents these limits).

High-level steps:

Have a Mac with Xcode (local Mac, or a Mac cloud if needed).

Plug iPhone in via USB → tap Trust on the phone.

Xcode → sign in with your Apple Account.

In your project: set a unique Bundle Identifier and enable Automatic Signing.