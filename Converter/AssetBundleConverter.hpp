# Upload Guide for GitHub (From iPhone)

Put the files in this folder structure inside your GitHub repository:

- `Bridge/AssetConverterBridge.h`
- `Bridge/AssetConverterBridge.mm`
- `Sources/App-Bridging-Header.h`
- `Sources/NativeAssetConverterService.swift`
- `Sources/ConverterViewModel+Convert.swift`
- `Converter/AssetBundleConverter.hpp` (your completed C++ header)
- `Converter/AssetBundleConverter.cpp` (your completed C++ source)
- `.github/workflows/build-ipa.yml`

## Steps on iPhone
1. Open your GitHub repository in Safari or the GitHub mobile app.
2. Upload each file into the matching folder path above.
3. Make sure your Xcode project / build script includes `Converter/` in header search paths and `Bridge/AssetConverterBridge.mm` + `Converter/AssetBundleConverter.cpp` in sources.
4. Go to the **Actions** tab on GitHub to run the IPA build workflow, download the `.ipa` artifact, and sign/install it with **eSign**.
