#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const AssetConverterBridgeErrorDomain;

typedef NS_ENUM(NSInteger, AssetConverterBridgeErrorCode) {
    AssetConverterBridgeErrorCodeConversionFailed = 1,
    AssetConverterBridgeErrorCodeInvalidArgument = 2,
    AssetConverterBridgeErrorCodeCancelled = 3,
    AssetConverterBridgeErrorCodeInternal = 4,
};

typedef NS_ENUM(NSInteger, AssetConverterPreset) {
    AssetConverterPresetFast = 0,
    AssetConverterPresetBalanced = 1,
    AssetConverterPresetQuality = 2,
};

typedef void (^AssetConverterProgressBlock)(double fraction, NSString *stage);

@interface AssetConverterBridge : NSObject

- (BOOL)convertWithInputPath:(NSString *)inputPath
                  outputPath:(NSString *)outputPath
                      preset:(AssetConverterPreset)preset
                    progress:(nullable AssetConverterProgressBlock)progress
                       error:(NSError * _Nullable * _Nullable)error
NS_SWIFT_NAME(convert(inputPath:outputPath:preset:progress:));

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
