# Stadium location and image input checks — 21.01; 20.07 remains open

The owner's selected map location now awaits all four independent draft writes (latitude, longitude, address and governorate) before returning to the wizard. Invalid or nonfinite coordinates are rejected without replacing the draft. The same rules apply to the manual address path. A widget test injects an Aswan selection, verifies the restored draft and the stadium update payload, then rejects a nonfinite manual result and checks the earlier address remains intact. The production picker remains the existing map/manual sheet. The test does not exercise GPS, map tiles or a live stadium write.

The photo upload path now requires a supported extension, a matching declared MIME type when provided, a size from 12 bytes to 10 MB, and a matching JPEG/PNG/WebP header before calling Storage. Direct tests cover all three accepted headers, spoofed signatures, mismatched MIME and extension, empty files and an oversized file. Header checks cannot prove the entire file is a safe decodable image, and server-side content scanning or a live bucket rejection is not established. **20.07 remains open** pending those checks.

[Flutter CI 43668494949](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43668494949) runs the two tests and the full suite.
