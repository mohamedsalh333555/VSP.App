# Owner stadium photo upload failure — 20.05

The stadium wizard creates a temporary uploading image row, sends the image to storage, then either replaces the row with its URL or removes it and shows feedback. The coordinator now handles both a `null` storage result and an unexpected thrown error through the same recovery path. The widget test injects each failure with a signed-in owner ID, verifies the uploading placeholder was present while the request started, then checks that it is removed, the screen state is refreshed and a retryable error appears.

[Flutter CI 43644752625](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43644752625) runs the widget test and the full suite. This is the owner UI failure path with synthetic storage outcomes. Actual Supabase Storage outage, owner data persistence, server file inspection and malicious-file scanning remain separate checks; task 20.07 remains open.
