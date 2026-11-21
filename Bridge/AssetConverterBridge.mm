#import "AssetConverterBridge.h"
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

#include <algorithm>
#include <atomic>
#include <exception>
#include <string>

#include "AssetBundleConverter.hpp"

NSErrorDomain const AssetConverterBridgeErrorDomain = @"AssetConverterBridgeErrorDomain";

namespace {

NSError *MakeError(AssetConverterBridgeErrorCode code, NSString *message) {
    return [NSError errorWithDomain:AssetConverterBridgeErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Unknown error"}];
}

bool CopyPath(NSString *path, std::string &out) {
    if (path == nil || path.length == 0) {
        return false;
    }
    const char *fsRep = path.fileSystemRepresentation;
    if (fsRep == nullptr || fsRep[0] == '\0') {
        return false;
    }
    out.assign(fsRep);
    return !out.empty();
}

abc::ConverterOptions MakeOptionsForPreset(AssetConverterPreset preset) {
    abc::ConverterOptions opts;
    switch (preset) {
        case AssetConverterPresetFast:
            opts.astcBlockX = 8;
            opts.astcBlockY = 8;
            opts.astcQuality = 10.0f;
            break;
        case AssetConverterPresetBalanced:
            opts.astcBlockX = 6;
            opts.astcBlockY = 6;
            opts.astcQuality = 60.0f;
            break;
        case AssetConverterPresetQuality:
            opts.astcBlockX = 4;
            opts.astcBlockY = 4;
            opts.astcQuality = 90.0f;
            break;
        default:
            opts.astcBlockX = 6;
            opts.astcBlockY = 6;
            opts.astcQuality = 60.0f;
            break;
    }
    return opts;
}

abc::TextureCodecs MakeDefaultCodecs(float astcQuality) {
    abc::TextureCodecs codecs;
    codecs.encoder = abc::createAstcencEncoder(astcQuality);
    codecs.lz4Decompress = abc::createLz4Decompressor();
    codecs.lz4Compress = abc::createLz4Compressor();
    return codecs;
}

void EmitProgress(AssetConverterProgressBlock handler, double fraction, NSString *stage) {
    if (handler == nil) {
        return;
    }
    const double clamped = std::min(1.0, std::max(0.0, fraction));
    NSString *stageCopy = [stage copy] ?: @"";
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(clamped, stageCopy);
    });
}

} // namespace

@implementation AssetConverterBridge {
    std::atomic<bool> _cancelRequested;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cancelRequested.store(false, std::memory_order_relaxed);
    }
    return self;
}

- (void)cancel {
    _cancelRequested.store(true, std::memory_order_relaxed);
}

- (BOOL)convertWithInputPath:(NSString *)inputPath
                  outputPath:(NSString *)outputPath
                      preset:(AssetConverterPreset)preset
                    progress:(nullable AssetConverterProgressBlock)progress
                       error:(NSError * _Nullable * _Nullable)error {
    std::string input;
    std::string output;

    if (!CopyPath(inputPath, input) || !CopyPath(outputPath, output)) {
        if (error != nullptr) {
            *error = MakeError(AssetConverterBridgeErrorCodeInvalidArgument,
                               @"Invalid input or output file path.");
        }
        return NO;
    }

    _cancelRequested.store(false, std::memory_order_relaxed);
    AssetConverterProgressBlock handler = [progress copy];

    if (_cancelRequested.load(std::memory_order_relaxed)) {
        EmitProgress(handler, 0.0, @"Cancelled");
        if (error != nullptr) {
            *error = MakeError(AssetConverterBridgeErrorCodeCancelled, @"Conversion cancelled.");
        }
        return NO;
    }

    EmitProgress(handler, 0.15, @"Converting bundle...");

    try {
        const abc::ConverterOptions options = MakeOptionsForPreset(preset);
        const abc::TextureCodecs codecs = MakeDefaultCodecs(options.astcQuality);
        const abc::AssetBundleConverter converter(options, codecs);

        const abc::ConversionResult result = converter.convertFile(input, output);

        if (_cancelRequested.load(std::memory_order_relaxed)) {
            if (error != nullptr) {
                *error = MakeError(AssetConverterBridgeErrorCodeCancelled, @"Conversion cancelled.");
            }
            return NO;
        }

        if (!result.success) {
            if (error != nullptr) {
                NSString *msg = [NSString stringWithUTF8String:result.errorMessage.c_str()];
                *error = MakeError(AssetConverterBridgeErrorCodeConversionFailed,
                                   msg.length > 0 ? msg : @"Bundle conversion failed.");
            }
            return NO;
        }

        EmitProgress(handler, 1.0, @"Completed");
        return YES;
    } catch (const std::exception &e) {
        if (error != nullptr) {
            NSString *msg = [NSString stringWithUTF8String:e.what()] ?: @"Unknown C++ exception.";
            *error = MakeError(AssetConverterBridgeErrorCodeInternal, msg);
        }
        return NO;
    } catch (...) {
        if (error != nullptr) {
            *error = MakeError(AssetConverterBridgeErrorCodeInternal, @"Unknown native error.");
        }
        return NO;
    }
}

@end
